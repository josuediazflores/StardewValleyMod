import Foundation
import SwiftUI

extension AppState {

    // MARK: - Mod Update Checking

    func checkForUpdates() {
        isCheckingUpdates = true
        Task {
            do {
                let updates = try await nexusAPI.checkForUpdates(mods: mods)
                modUpdates = Dictionary(updates.map { ($0.modID, $0) }, uniquingKeysWith: { first, _ in first })
            } catch {
                // Silently ignore — callers handle stale data gracefully
            }
            isCheckingUpdates = false
        }
    }

    // MARK: - NXM Protocol Handler

    func handleNXMLink(_ url: URL) {
        guard let nxmLink = NXMLink(url: url) else {
            errorMessage = "Invalid NXM link."
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        Task {
            do {
                let links: [NexusDownloadLink]
                if let nxmKey = nxmLink.key, let nxmExpires = nxmLink.expires {
                    links = try await nexusAPI.downloadLinks(modId: nxmLink.modId, fileId: nxmLink.fileId, nxmKey: nxmKey, nxmExpires: nxmExpires)
                } else {
                    links = try await nexusAPI.downloadLinks(modId: nxmLink.modId, fileId: nxmLink.fileId)
                }

                guard let link = links.first else {
                    errorMessage = "No download links available."
                    return
                }

                let tempDir = FileManager.default.temporaryDirectory
                let zipURL = try await nexusAPI.downloadFile(url: link.uri, to: tempDir)

                // Parse mod names from the zip without installing (ditto runs off-main)
                let names = await Task.detached(priority: .userInitiated) {
                    ModManagementService.peekModNames(from: zipURL)
                }.value

                pendingNXMZipURL = zipURL
                pendingNXMModNames = names.isEmpty ? ["Downloaded mod"] : names
                pendingNXMSuggestedName = names.count > 1 ? names.first : nil
                showModpackPicker = true
            } catch {
                errorMessage = "NXM download failed: \(error.localizedDescription)"
            }
        }
    }

    /// Installs the staged NXM zip off the main thread, applying the resulting `mods`
    /// mutations back on the MainActor. Leaves `pendingNXMMods` set to the installed
    /// mods so the modpack-targeting callers can act on them after awaiting.
    private func performPendingNXMInstall() async {
        guard let zipURL = pendingNXMZipURL else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let currentSettings = settings
            let existing = mods
            let result = try await Task.detached(priority: .userInitiated) {
                try ModManagementService.importMod(from: zipURL, settings: currentSettings, existingMods: existing)
            }.value
            try? FileManager.default.removeItem(at: zipURL)
            for newMod in result.mods {
                mods.removeAll { $0.id == newMod.id }
                mods.append(newMod)
            }
            mods.sort { $0.manifest.name.localizedCaseInsensitiveCompare($1.manifest.name) == .orderedAscending }
            DependencyResolver.resolveAll(mods: mods)
            pendingNXMMods = result.mods
            addNewModsToActiveModpack(result.mods)
            if !result.failures.isEmpty {
                let names = result.failures.prefix(3).map(\.name).joined(separator: ", ")
                let suffix = result.failures.count > 3 ? ", …" : ""
                showToast("\(result.failures.count) mod\(result.failures.count == 1 ? "" : "s") failed to install: \(names)\(suffix)", type: .warning)
            }
        } catch {
            errorMessage = "Failed to install mod: \(error.localizedDescription)"
        }
        pendingNXMZipURL = nil
        pendingNXMModNames = []
    }

    func installPendingNXMToCurrentProfile() {
        Task { await performPendingNXMInstall() }
    }

    func installPendingNXMToModpack(_ modpackID: UUID) {
        // Install to current profile first, then add to modpack
        Task {
            await performPendingNXMInstall()
            if !pendingNXMMods.isEmpty {
                addModsToModpack(modpackID, mods: pendingNXMMods)
            }
            pendingNXMMods = []
        }
    }

    func installPendingNXMToNewModpack(name: String) {
        Task {
            await performPendingNXMInstall()
            if !pendingNXMMods.isEmpty {
                createModpackFromCurrentState(name: name, description: "Created from NXM download")
                if let newPack = modpacks.last {
                    // Clear entries and only add the downloaded mods
                    if let idx = modpacks.firstIndex(where: { $0.id == newPack.id }) {
                        modpacks[idx].entries = pendingNXMMods.map { ModpackEntry(mod: $0, isEnabled: true) }
                        persistModpacks()
                    }
                }
            }
            pendingNXMMods = []
        }
    }

    func cancelPendingNXM() {
        if let zipURL = pendingNXMZipURL {
            try? FileManager.default.removeItem(at: zipURL)
        }
        pendingNXMZipURL = nil
        pendingNXMModNames = []
        pendingNXMSuggestedName = nil
    }

    // MARK: - Import from Nexus URL

    static func parseNexusModURL(_ urlString: String) -> Int? {
        guard let url = URL(string: urlString),
              let host = url.host,
              host.contains("nexusmods.com") else { return nil }
        let components = url.pathComponents
        guard let modsIndex = components.firstIndex(of: "mods"),
              modsIndex + 1 < components.count,
              let modId = Int(components[modsIndex + 1]) else { return nil }
        return modId
    }

    static let excludedNexusFileCategories: Set<String> = ["OLD_VERSION", "ARCHIVED", "DELETED"]

    /// Picks the file to auto-install, or returns nil when the choice is ambiguous
    /// (e.g. a mod with only optional files) so the UI can ask the user instead.
    static func chooseNexusFile(from files: [NexusModFileInfo]) -> (auto: NexusModFileInfo?, candidates: [NexusModFileInfo]) {
        let candidates = files
            .filter { !excludedNexusFileCategories.contains($0.categoryName ?? "") }
            .sorted { ($0.uploadedTimestamp ?? 0) > ($1.uploadedTimestamp ?? 0) }
        if let primary = candidates.first(where: { $0.isPrimary == true }) { return (primary, candidates) }
        if let main = candidates.first(where: { $0.categoryName == "MAIN" }) { return (main, candidates) }
        if let update = candidates.first(where: { $0.categoryName == "UPDATE" }) { return (update, candidates) }
        if candidates.count == 1 { return (candidates[0], candidates) }
        return (nil, candidates)
    }

    func importFromNexusURL(_ urlString: String) {
        guard let modId = Self.parseNexusModURL(urlString) else {
            errorMessage = "Invalid Nexus Mods URL. Expected format: nexusmods.com/stardewvalley/mods/1234"
            return
        }

        guard settings.nexusAPIKey != nil, settings.isAPIKeyValidated else {
            errorMessage = "Nexus API key required. Set it up in Settings."
            return
        }

        guard settings.isNexusPremium else {
            // Free accounts can only download via nxm:// links from the website
            openWebDownloadSheet(modId: modId, modName: "Mod #\(modId)")
            return
        }

        Task {
            do {
                let files = try await nexusAPI.modFiles(modId: modId)
                let (auto, candidates) = Self.chooseNexusFile(from: files)

                guard !candidates.isEmpty else {
                    errorMessage = "No downloadable files found for this mod."
                    return
                }

                if let file = auto {
                    await downloadNexusFile(modId: modId, fileId: file.fileId)
                } else {
                    nexusFilePickerFiles = candidates
                    nexusFilePickerModId = modId
                    showNexusFilePicker = true
                }
            } catch {
                errorMessage = "Failed to download mod: \(error.localizedDescription)"
            }
        }
    }

    /// Downloads a specific Nexus file and stages it for the modpack picker.
    func downloadNexusFile(modId: Int, fileId: Int) async {
        do {
            let links = try await nexusAPI.downloadLinks(modId: modId, fileId: fileId)
            guard let link = links.first else {
                errorMessage = "No download links available."
                return
            }

            let tempDir = FileManager.default.temporaryDirectory
            let zipURL = try await nexusAPI.downloadFile(url: link.uri, to: tempDir)
            let names = await Task.detached(priority: .userInitiated) {
                ModManagementService.peekModNames(from: zipURL)
            }.value

            pendingNXMZipURL = zipURL
            pendingNXMModNames = names.isEmpty ? ["Downloaded mod"] : names
            pendingNXMSuggestedName = names.count > 1 ? names.first : nil
            showModpackPicker = true
        } catch NexusAPIError.premiumRequired {
            openWebDownloadSheet(modId: modId, modName: "Mod #\(modId)")
        } catch {
            errorMessage = "Failed to download mod: \(error.localizedDescription)"
        }
    }

    // MARK: - Nexus Key Validation & Browse

    func revalidateAPIKeyIfNeeded() {
        guard let key = settings.nexusAPIKey, !key.isEmpty, !settings.isAPIKeyValidated else { return }
        Task {
            await validateNexusAPIKey(key)
        }
    }

    func validateNexusAPIKey(_ key: String) async {
        do {
            await nexusAPI.setAPIKey(key)
            let user = try await nexusAPI.validateKey(key)
            settings.nexusAPIKey = key
            settings.isAPIKeyValidated = true
            settings.nexusUserName = user.name
            settings.isNexusPremium = user.isPremium ?? false
        } catch {
            settings.isAPIKeyValidated = false
            nexusError = error.localizedDescription
        }
    }

    func loadEssentialMods() async {
        isNexusLoading = true
        nexusError = nil
        var mods: [NexusModInfo] = []
        for modId in AppConfig.essentialModIDs {
            if let mod = try? await nexusAPI.modDetails(modId: modId) {
                mods.append(mod)
            }
        }
        // A tab switch cancels this load; bail without stomping the new tab's flags.
        if Task.isCancelled { return }
        nexusEssentialMods = mods
        isNexusLoading = false
    }

    func loadTrendingMods() async {
        isNexusLoading = true
        nexusError = nil
        nexusHasMore = true
        do {
            let result = try await nexusAPI.browseMods(sortBy: .endorsements, offset: 0)
            if Task.isCancelled { return }
            nexusTrendingMods = result
        } catch {
            // A tab switch cancels the in-flight request; don't let the stale failure
            // stomp the flags the new tab's load has already set.
            if Task.isCancelled || error is CancellationError { return }
            nexusError = error.localizedDescription
        }
        if Task.isCancelled { return }
        isNexusLoading = false
    }

    func loadLatestMods() async {
        isNexusLoading = true
        nexusError = nil
        nexusHasMore = true
        do {
            let result = try await nexusAPI.browseMods(sortBy: .createdAt, offset: 0)
            if Task.isCancelled { return }
            nexusLatestMods = result
        } catch {
            if Task.isCancelled || error is CancellationError { return }
            nexusError = error.localizedDescription
        }
        if Task.isCancelled { return }
        isNexusLoading = false
    }

    func searchNexusMods(query: String) async {
        isNexusLoading = true
        nexusError = nil
        nexusHasMore = true
        do {
            let result = try await nexusAPI.browseMods(sortBy: .downloads, searchText: query)
            if Task.isCancelled { return }
            nexusSearchResults = result
        } catch {
            if Task.isCancelled || error is CancellationError { return }
            nexusError = error.localizedDescription
        }
        if Task.isCancelled { return }
        isNexusLoading = false
    }

    enum NexusTab { case trending, latest, search }

    func loadMoreMods(tab: NexusTab) async {
        guard !isNexusLoadingMore, nexusHasMore else { return }
        isNexusLoadingMore = true
        do {
            let newMods: [NexusModInfo]
            switch tab {
            case .trending:
                newMods = try await nexusAPI.browseMods(sortBy: .endorsements, offset: nexusTrendingMods.count)
                if newMods.isEmpty { nexusHasMore = false } else { nexusTrendingMods.append(contentsOf: newMods) }
            case .latest:
                newMods = try await nexusAPI.browseMods(sortBy: .createdAt, offset: nexusLatestMods.count)
                if newMods.isEmpty { nexusHasMore = false } else { nexusLatestMods.append(contentsOf: newMods) }
            case .search:
                newMods = try await nexusAPI.browseMods(sortBy: .downloads, offset: nexusSearchResults.count, searchText: nexusSearchText)
                if newMods.isEmpty { nexusHasMore = false } else { nexusSearchResults.append(contentsOf: newMods) }
            }
        } catch {
            // Silently fail on load-more
        }
        isNexusLoadingMore = false
    }

    func downloadAndInstallMod(modId: Int, fileId: Int) async {
        isNexusLoading = true
        nexusError = nil
        do {
            let links = try await nexusAPI.downloadLinks(modId: modId, fileId: fileId)
            guard let link = links.first else {
                nexusError = "No download links available."
                isNexusLoading = false
                return
            }

            let tempDir = FileManager.default.temporaryDirectory
            let zipURL = try await nexusAPI.downloadFile(url: link.uri, to: tempDir)

            // Check if multi-mod before installing (ditto runs off-main)
            let names = await Task.detached(priority: .userInitiated) {
                ModManagementService.peekModNames(from: zipURL)
            }.value
            if names.count > 1 {
                // Multi-mod: show modpack picker instead of silently installing
                isNexusLoading = false
                pendingNXMZipURL = zipURL
                pendingNXMModNames = names
                pendingNXMSuggestedName = names.first
                showModpackPicker = true
                return
            }

            let currentSettings = settings
            let existing = mods
            let result = try await Task.detached(priority: .userInitiated) {
                try ModManagementService.importMod(from: zipURL, settings: currentSettings, existingMods: existing)
            }.value
            try? FileManager.default.removeItem(at: zipURL)

            for newMod in result.mods {
                mods.removeAll { $0.id == newMod.id }
                mods.append(newMod)
            }
            mods.sort { $0.manifest.name.localizedCaseInsensitiveCompare($1.manifest.name) == .orderedAscending }
            DependencyResolver.resolveAll(mods: mods)
            if !result.failures.isEmpty {
                let names = result.failures.prefix(3).map(\.name).joined(separator: ", ")
                let suffix = result.failures.count > 3 ? ", …" : ""
                showToast("\(result.failures.count) mod\(result.failures.count == 1 ? "" : "s") failed to install: \(names)\(suffix)", type: .warning)
            }
        } catch NexusAPIError.premiumRequired {
            isNexusLoading = false
            openWebDownloadSheet(modId: modId, modName: "Mod #\(modId)")
            return
        } catch {
            // nexusError is only rendered by the browse view; use the global alert
            // so failures inside the detail sheet are visible too
            errorMessage = "Download failed: \(error.localizedDescription)"
        }
        isNexusLoading = false
    }

    func openNexusModPage(modId: Int) {
        if let url = URL(string: "https://www.nexusmods.com/stardewvalley/mods/\(modId)") {
            NSWorkspace.shared.open(url)
        }
    }

    func openWebDownloadSheet(modId: Int, modName: String) {
        let url = URL(string: "https://www.nexusmods.com/stardewvalley/mods/\(modId)?tab=files")!
        webDownloadModName = modName
        webDownloadURL = url
        showWebDownloadSheet = true
    }

}
