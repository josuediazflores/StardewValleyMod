import Foundation
import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case modpacks = "Modpacks"
    case installedMods = "Mods"
    case browseNexus = "Browse Nexus"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .modpacks: return "archivebox.fill"
        case .installedMods: return "hammer.fill"
        case .browseNexus: return "globe"
        }
    }
}

@Observable
@MainActor
final class AppState {
    static let junimoNames = [
        "Junimo_Green", "Junimo_Blue", "Junimo_Red",
        "Junimo_Orange", "Junimo_Yellow", "Junimo_White",
        "Junimo_Cyan", "Junimo_Purple", "Junimo_Pink"
    ]

    let selectedJunimoName = junimoNames.randomElement()!

    var settings = AppSettings()
    var mods: [Mod] = []
    var sidebarSelection: SidebarItem? = .modpacks
    var selectedModID: String?
    var searchText = ""
    var filterMode: ModFilter = .all
    var isLoading = false
    var showImportPicker = false
    var showInspector = true
    var errorMessage: String?

    // Toast notification state
    var toasts: [ToastMessage] = []

    // Update checking state
    var modUpdates: [String: ModUpdateInfo] = [:]
    var isCheckingUpdates = false

    // App update state
    var availableUpdate: AppUpdate?

    // NXM protocol state
    var nxmDownloadStatus: String?
    var showModpackPicker = false
    var pendingNXMMods: [Mod] = []
    var pendingNXMZipURL: URL?
    var pendingNXMModNames: [String] = []

    // Nexus state
    var nexusEssentialMods: [NexusModInfo] = []
    var nexusTrendingMods: [NexusModInfo] = []
    var nexusLatestMods: [NexusModInfo] = []
    var nexusSearchResults: [NexusModInfo] = []
    var nexusSearchText = ""
    var isNexusLoading = false
    var isNexusLoadingMore = false
    var nexusError: String?
    var nexusHasMore = true

    let nexusAPI = NexusAPIService()
    let externalDownloader = ExternalDownloadService()

    // Modpack state
    var modpacks: [Modpack] = []
    var activeModpackID: UUID?
    var selectedModpackID: UUID?
    var isModpackLoading = false
    var modpackError: String?
    var expandedModpackID: UUID? = nil

    var activeModpack: Modpack? {
        guard let id = activeModpackID else { return nil }
        return modpacks.first { $0.id == id }
    }

    var selectedModpack: Modpack? {
        guard let id = selectedModpackID else { return nil }
        return modpacks.first { $0.id == id }
    }

    var filteredModpacks: [Modpack] {
        var result = modpacks

        if !searchText.isEmpty && expandedModpackID == nil {
            let query = searchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(query) ||
                $0.description.lowercased().contains(query)
            }
        }

        return result
    }

    func filteredEntriesForModpack(_ modpack: Modpack) -> [ModpackEntry] {
        // Start with explicit modpack entries
        let existingIDs = Set(modpack.entries.map(\.uniqueID))
        var result = modpack.entries

        // Merge in all installed mods not already in the modpack (as disabled)
        for mod in mods {
            if !existingIDs.contains(mod.id) {
                result.append(ModpackEntry(
                    uniqueID: mod.id,
                    name: mod.manifest.name,
                    version: mod.manifest.version,
                    nexusModID: mod.nexusModID,
                    nexusFileID: nil,
                    isEnabled: false
                ))
            }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { $0.name.lowercased().contains(query) }
        }

        switch filterMode {
        case .all: break
        case .enabled: result = result.filter { $0.isEnabled }
        case .disabled: result = result.filter { !$0.isEnabled }
        case .codeMods:
            let codeModIDs = Set(mods.filter { $0.modType == .codeMod }.map(\.id))
            result = result.filter { codeModIDs.contains($0.uniqueID) }
        case .contentPacks:
            let cpIDs = Set(mods.filter { $0.modType == .contentPack }.map(\.id))
            result = result.filter { cpIDs.contains($0.uniqueID) }
        }

        return result
    }

    var filteredMods: [Mod] {
        var result = mods

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.manifest.name.lowercased().contains(query) ||
                $0.manifest.author.lowercased().contains(query) ||
                ($0.manifest.description?.lowercased().contains(query) ?? false)
            }
        }

        switch filterMode {
        case .all: break
        case .enabled: result = result.filter { $0.isEnabled }
        case .disabled: result = result.filter { !$0.isEnabled }
        case .codeMods: result = result.filter { $0.modType == .codeMod }
        case .contentPacks: result = result.filter { $0.modType == .contentPack }
        }

        return result
    }

    var selectedMod: Mod? {
        guard let id = selectedModID else { return nil }
        return mods.first { $0.id == id }
    }

    var enabledCount: Int { mods.filter { $0.isEnabled }.count }
    var disabledCount: Int { mods.filter { !$0.isEnabled }.count }
    var userModCount: Int { mods.filter { !$0.isBuiltIn }.count }

    // MARK: - Sorting

    func sortMods(using comparators: [KeyPathComparator<Mod>]) {
        mods.sort { lhs, rhs in
            for comparator in comparators {
                switch comparator.compare(lhs, rhs) {
                case .orderedAscending: return true
                case .orderedDescending: return false
                case .orderedSame: continue
                }
            }
            return false
        }
    }

    // MARK: - Mod Operations

    func loadMods() {
        isLoading = true
        errorMessage = nil

        mods = ModDiscoveryService.discoverMods(settings: settings)
        DependencyResolver.resolveAll(mods: mods)
        loadModpacks()

        isLoading = false
    }

    func toggleMod(_ mod: Mod) -> DependencyWarning? {
        if mod.isEnabled {
            return checkAndDisableMod(mod)
        } else {
            return checkAndEnableMod(mod)
        }
    }

    func checkAndDisableMod(_ mod: Mod) -> DependencyWarning? {
        return DependencyResolver.checkDisableImpact(mod: mod, allMods: mods)
    }

    func checkAndEnableMod(_ mod: Mod) -> DependencyWarning? {
        return DependencyResolver.checkEnableRequirements(mod: mod, allMods: mods)
    }

    func performEnableMod(_ mod: Mod) {
        do {
            try ModManagementService.enableMod(mod, settings: settings)
            DependencyResolver.resolveAll(mods: mods)
            syncActiveModpackEntry(mod: mod, isEnabled: true)
            showToast("\(mod.manifest.name) enabled", type: .success)
            SoundService.play(.click)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func performDisableMod(_ mod: Mod) {
        do {
            try ModManagementService.disableMod(mod, settings: settings)
            DependencyResolver.resolveAll(mods: mods)
            syncActiveModpackEntry(mod: mod, isEnabled: false)
            showToast("\(mod.manifest.name) disabled", type: .info)
            SoundService.play(.click)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Keeps the active modpack in sync when a mod is toggled from the Mods tab
    private func syncActiveModpackEntry(mod: Mod, isEnabled: Bool) {
        guard let activeID = activeModpackID,
              let idx = modpacks.firstIndex(where: { $0.id == activeID }) else { return }

        if let entryIdx = modpacks[idx].entries.firstIndex(where: { $0.uniqueID == mod.id }) {
            modpacks[idx].entries[entryIdx].isEnabled = isEnabled
        } else {
            modpacks[idx].entries.append(ModpackEntry(
                uniqueID: mod.id,
                name: mod.manifest.name,
                version: mod.manifest.version,
                nexusModID: mod.nexusModID,
                nexusFileID: nil,
                isEnabled: isEnabled
            ))
        }
        modpacks[idx].updatedAt = Date()
        try? ModpackService.saveModpacks(modpacks, settings: settings)
    }

    func deleteMod(_ mod: Mod) {
        do {
            try ModManagementService.deleteMod(mod)
            mods.removeAll { $0.id == mod.id }
            if selectedModID == mod.id { selectedModID = nil }
            DependencyResolver.resolveAll(mods: mods)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importMods(from urls: [URL]) {
        var allImported: [Mod] = []
        for url in urls {
            do {
                let securityScoped = url.startAccessingSecurityScopedResource()
                defer { if securityScoped { url.stopAccessingSecurityScopedResource() } }

                let imported = try ModManagementService.importMod(from: url, settings: settings)
                for newMod in imported {
                    mods.removeAll { $0.id == newMod.id }
                    mods.append(newMod)
                    allImported.append(newMod)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        mods.sort { $0.manifest.name.localizedCaseInsensitiveCompare($1.manifest.name) == .orderedAscending }
        DependencyResolver.resolveAll(mods: mods)
        addNewModsToActiveModpack(allImported)
        if !allImported.isEmpty {
            showToast("Imported \(allImported.count) mod\(allImported.count == 1 ? "" : "s")", type: .success)
            SoundService.play(.bigSelect)
        }
    }

    /// Auto-adds newly installed mods to the active modpack as disabled entries
    private func addNewModsToActiveModpack(_ newMods: [Mod]) {
        guard !newMods.isEmpty, let activeID = activeModpackID,
              let idx = modpacks.firstIndex(where: { $0.id == activeID }) else { return }
        for mod in newMods {
            guard !modpacks[idx].entries.contains(where: { $0.uniqueID == mod.id }) else { continue }
            let entry = ModpackEntry(
                uniqueID: mod.id,
                name: mod.manifest.name,
                version: mod.manifest.version,
                nexusModID: mod.nexusModID,
                nexusFileID: nil,
                isEnabled: false
            )
            modpacks[idx].entries.append(entry)
        }
        modpacks[idx].updatedAt = Date()
        try? ModpackService.saveModpacks(modpacks, settings: settings)
    }

    // MARK: - Update Checking

    func checkForUpdates() {
        isCheckingUpdates = true
        Task {
            do {
                let updates = try await nexusAPI.checkForUpdates(mods: mods)
                modUpdates = Dictionary(updates.map { ($0.modID, $0) }, uniquingKeysWith: { first, _ in first })
            } catch {
                print("Update check failed: \(error.localizedDescription)")
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
        nxmDownloadStatus = "Downloading mod..."

        Task {
            do {
                if let key = settings.nexusAPIKey {
                    await nexusAPI.setAPIKey(key)
                }

                let links: [NexusDownloadLink]
                if let nxmKey = nxmLink.key, let nxmExpires = nxmLink.expires {
                    links = try await nexusAPI.downloadLinks(modId: nxmLink.modId, fileId: nxmLink.fileId, nxmKey: nxmKey, nxmExpires: nxmExpires)
                } else {
                    links = try await nexusAPI.downloadLinks(modId: nxmLink.modId, fileId: nxmLink.fileId)
                }

                guard let link = links.first else {
                    nxmDownloadStatus = nil
                    errorMessage = "No download links available."
                    return
                }

                let tempDir = FileManager.default.temporaryDirectory
                let zipURL = try await nexusAPI.downloadFile(url: link.uri, to: tempDir)

                // Parse mod names from the zip without installing
                let names = ModManagementService.peekModNames(from: zipURL)

                nxmDownloadStatus = nil
                pendingNXMZipURL = zipURL
                pendingNXMModNames = names.isEmpty ? ["Downloaded mod"] : names
                showModpackPicker = true
            } catch {
                nxmDownloadStatus = nil
                errorMessage = "NXM download failed: \(error.localizedDescription)"
            }
        }
    }

    func installPendingNXMToCurrentProfile() {
        guard let zipURL = pendingNXMZipURL else { return }
        do {
            let imported = try ModManagementService.importMod(from: zipURL, settings: settings)
            try? FileManager.default.removeItem(at: zipURL)
            for newMod in imported {
                mods.removeAll { $0.id == newMod.id }
                mods.append(newMod)
            }
            mods.sort { $0.manifest.name.localizedCaseInsensitiveCompare($1.manifest.name) == .orderedAscending }
            DependencyResolver.resolveAll(mods: mods)
            pendingNXMMods = imported
            addNewModsToActiveModpack(imported)
        } catch {
            errorMessage = "Failed to install mod: \(error.localizedDescription)"
        }
        pendingNXMZipURL = nil
        pendingNXMModNames = []
    }

    func installPendingNXMToModpack(_ modpackID: UUID) {
        // Install to current profile first, then add to modpack
        installPendingNXMToCurrentProfile()
        if !pendingNXMMods.isEmpty {
            addModsToModpack(modpackID, mods: pendingNXMMods)
        }
        pendingNXMMods = []
    }

    func installPendingNXMToNewModpack(name: String) {
        installPendingNXMToCurrentProfile()
        if !pendingNXMMods.isEmpty {
            createModpackFromCurrentState(name: name, description: "Created from NXM download")
            if let newPack = modpacks.last {
                // Clear entries and only add the downloaded mods
                if let idx = modpacks.firstIndex(where: { $0.id == newPack.id }) {
                    modpacks[idx].entries = pendingNXMMods.map { mod in
                        ModpackEntry(
                            uniqueID: mod.id,
                            name: mod.manifest.name,
                            version: mod.manifest.version,
                            nexusModID: mod.nexusModID,
                            nexusFileID: nil,
                            isEnabled: true
                        )
                    }
                    try? ModpackService.saveModpacks(modpacks, settings: settings)
                }
            }
        }
        pendingNXMMods = []
    }

    func cancelPendingNXM() {
        if let zipURL = pendingNXMZipURL {
            try? FileManager.default.removeItem(at: zipURL)
        }
        pendingNXMZipURL = nil
        pendingNXMModNames = []
    }

    func addModsToModpack(_ modpackID: UUID, mods modsToAdd: [Mod]) {
        guard let index = modpacks.firstIndex(where: { $0.id == modpackID }) else { return }
        for mod in modsToAdd {
            let entry = ModpackEntry(
                uniqueID: mod.id,
                name: mod.manifest.name,
                version: mod.manifest.version,
                nexusModID: mod.nexusModID,
                nexusFileID: nil,
                isEnabled: true
            )
            if !modpacks[index].entries.contains(where: { $0.uniqueID == entry.uniqueID }) {
                modpacks[index].entries.append(entry)
            }
        }
        try? ModpackService.saveModpacks(modpacks, settings: settings)
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

    func importFromNexusURL(_ urlString: String) {
        guard let modId = Self.parseNexusModURL(urlString) else {
            errorMessage = "Invalid Nexus Mods URL. Expected format: nexusmods.com/stardewvalley/mods/1234"
            return
        }

        guard settings.nexusAPIKey != nil, settings.isAPIKeyValidated else {
            errorMessage = "Nexus API key required. Set it up in Settings."
            return
        }

        nxmDownloadStatus = "Fetching mod info..."

        Task {
            do {
                if let key = settings.nexusAPIKey {
                    await nexusAPI.setAPIKey(key)
                }

                let files = try await nexusAPI.modFiles(modId: modId)
                guard let file = files.first(where: { $0.isPrimary == true })
                    ?? files.first(where: { $0.categoryName == "MAIN" })
                    ?? files.first else {
                    nxmDownloadStatus = nil
                    errorMessage = "No downloadable files found for this mod."
                    return
                }

                if settings.isNexusPremium {
                    nxmDownloadStatus = "Downloading..."
                    let links = try await nexusAPI.downloadLinks(modId: modId, fileId: file.fileId)
                    guard let link = links.first else {
                        nxmDownloadStatus = nil
                        errorMessage = "No download links available."
                        return
                    }

                    let tempDir = FileManager.default.temporaryDirectory
                    let zipURL = try await nexusAPI.downloadFile(url: link.uri, to: tempDir)
                    let names = ModManagementService.peekModNames(from: zipURL)

                    nxmDownloadStatus = nil
                    pendingNXMZipURL = zipURL
                    pendingNXMModNames = names.isEmpty ? ["Downloaded mod"] : names
                    showModpackPicker = true
                } else {
                    nxmDownloadStatus = nil
                    errorMessage = "Direct download requires Nexus Premium. Opening mod page — click \"Mod Manager Download\" to install via the app."
                    if let url = URL(string: "https://www.nexusmods.com/stardewvalley/mods/\(modId)?tab=files") {
                        NSWorkspace.shared.open(url)
                    }
                }
            } catch {
                nxmDownloadStatus = nil
                errorMessage = "Failed to download mod: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - App Update Check

    var isUpdating = false
    var updateError: String?

    func checkForAppUpdate() {
        Task {
            availableUpdate = await UpdateService.checkForUpdate()
        }
    }

    func performAppUpdate() {
        guard let update = availableUpdate else { return }
        isUpdating = true
        updateError = nil
        Task {
            do {
                try await UpdateService.downloadAndInstall(update: update)
            } catch {
                isUpdating = false
                updateError = error.localizedDescription
            }
        }
    }

    // MARK: - Game Launch

    func launchGame() {
        SoundService.play(.bigSelect)
        do {
            try GameLauncherService.launch(settings: settings)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Soft Delete (with Undo)

    struct PendingDeletion: Identifiable {
        let id: UUID
        let mods: [Mod]
        let originalURLs: [URL]
        let wasEnabled: [Bool]
        let stagingURLs: [URL]
    }

    var pendingDeletions: [PendingDeletion] = []

    func softDeleteMod(_ mod: Mod) {
        softDeleteMods([mod])
    }

    func softDeleteMods(_ modsToDelete: [Mod]) {
        let deletionID = UUID()
        var originalURLs: [URL] = []
        var wasEnabled: [Bool] = []
        var stagingURLs: [URL] = []
        var deletedMods: [Mod] = []

        for mod in modsToDelete {
            do {
                let stagingURL = try ModManagementService.trashMod(mod)
                originalURLs.append(mod.folderURL)
                wasEnabled.append(mod.isEnabled)
                stagingURLs.append(stagingURL)
                deletedMods.append(mod)

                mods.removeAll { $0.id == mod.id }
                if selectedModID == mod.id { selectedModID = nil }
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        guard !deletedMods.isEmpty else { return }

        DependencyResolver.resolveAll(mods: mods)

        let pending = PendingDeletion(
            id: deletionID,
            mods: deletedMods,
            originalURLs: originalURLs,
            wasEnabled: wasEnabled,
            stagingURLs: stagingURLs
        )
        pendingDeletions.append(pending)

        let modNames = deletedMods.count == 1
            ? deletedMods[0].manifest.name
            : "\(deletedMods.count) mods"

        showToast("\(modNames) deleted", type: .warning) { [weak self] in
            self?.undoDelete(id: deletionID)
        }
        SoundService.play(.warning)

        // Finalize when toast expires
        Task {
            try? await Task.sleep(for: .seconds(6.0))
            finalizeDeletion(id: deletionID)
        }
    }

    func undoDelete(id: UUID) {
        guard let pendingIndex = pendingDeletions.firstIndex(where: { $0.id == id }) else { return }
        let pending = pendingDeletions[pendingIndex]

        for i in pending.mods.indices {
            let mod = pending.mods[i]
            let targetURL: URL
            if pending.wasEnabled[i] {
                targetURL = settings.modsDirectoryURL.appending(path: mod.folderName)
            } else {
                targetURL = settings.disabledModsDirectoryURL.appending(path: mod.folderName)
            }

            do {
                try ModManagementService.restoreFromTrash(stagingURL: pending.stagingURLs[i], to: targetURL)
                mod.folderURL = targetURL
                mod.isEnabled = pending.wasEnabled[i]
                mods.append(mod)
            } catch {
                errorMessage = "Failed to restore \(mod.manifest.name): \(error.localizedDescription)"
            }
        }

        mods.sort { $0.manifest.name.localizedCaseInsensitiveCompare($1.manifest.name) == .orderedAscending }
        DependencyResolver.resolveAll(mods: mods)
        pendingDeletions.remove(at: pendingIndex)

        let restoredName = pending.mods.count == 1
            ? pending.mods[0].manifest.name
            : "\(pending.mods.count) mods"
        showToast("Restored \(restoredName)", type: .success)
        SoundService.play(.click)
    }

    func finalizeDeletion(id: UUID) {
        guard let pendingIndex = pendingDeletions.firstIndex(where: { $0.id == id }) else { return }
        let pending = pendingDeletions[pendingIndex]
        ModManagementService.emptyTrash(stagingURLs: pending.stagingURLs)
        pendingDeletions.remove(at: pendingIndex)
    }

    // MARK: - Batch Operations

    func batchEnableMods(_ ids: Set<String>) {
        var enabledCount = 0
        for id in ids {
            guard let mod = mods.first(where: { $0.id == id }), !mod.isEnabled, !mod.isBuiltIn else { continue }
            do {
                try ModManagementService.enableMod(mod, settings: settings)
                syncActiveModpackEntry(mod: mod, isEnabled: true)
                enabledCount += 1
            } catch {}
        }
        DependencyResolver.resolveAll(mods: mods)
        if enabledCount > 0 {
            showToast("\(enabledCount) mod\(enabledCount == 1 ? "" : "s") enabled", type: .success)
            SoundService.play(.bigSelect)
        }
    }

    func batchDisableMods(_ ids: Set<String>) {
        var disabledCount = 0
        for id in ids {
            guard let mod = mods.first(where: { $0.id == id }), mod.isEnabled, !mod.isBuiltIn else { continue }
            do {
                syncActiveModpackEntry(mod: mod, isEnabled: false)
                try ModManagementService.disableMod(mod, settings: settings)
                disabledCount += 1
            } catch {}
        }
        DependencyResolver.resolveAll(mods: mods)
        if disabledCount > 0 {
            showToast("\(disabledCount) mod\(disabledCount == 1 ? "" : "s") disabled", type: .info)
            SoundService.play(.bigSelect)
        }
    }

    // MARK: - Toasts

    func showToast(_ message: String, type: ToastType = .info, undoAction: (() -> Void)? = nil) {
        let toast = ToastMessage(message: message, type: type, undoAction: undoAction)
        toasts.append(toast)

        let toastID = toast.id
        let duration = toast.displayDuration
        Task {
            try? await Task.sleep(for: .seconds(duration))
            dismissToast(id: toastID)
        }
    }

    func dismissToast(id: UUID) {
        withAnimation {
            toasts.removeAll { $0.id == id }
        }
    }

    // MARK: - Nexus Operations

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

    static let essentialModIDs = [1915, 5098, 1063, 541, 4, 239, 12747, 3753, 11115, 518]

    func loadEssentialMods() async {
        isNexusLoading = true
        nexusError = nil
        do {
            if let key = settings.nexusAPIKey {
                await nexusAPI.setAPIKey(key)
            }
            var mods: [NexusModInfo] = []
            for modId in Self.essentialModIDs {
                if let mod = try? await nexusAPI.modDetails(modId: modId) {
                    mods.append(mod)
                }
            }
            nexusEssentialMods = mods
        } catch {
            nexusError = error.localizedDescription
        }
        isNexusLoading = false
    }

    func loadTrendingMods() async {
        isNexusLoading = true
        nexusError = nil
        nexusHasMore = true
        do {
            if let key = settings.nexusAPIKey {
                await nexusAPI.setAPIKey(key)
            }
            nexusTrendingMods = try await nexusAPI.browseMods(sortBy: .endorsements, offset: 0)
        } catch {
            nexusError = error.localizedDescription
        }
        isNexusLoading = false
    }

    func loadLatestMods() async {
        isNexusLoading = true
        nexusError = nil
        nexusHasMore = true
        do {
            if let key = settings.nexusAPIKey {
                await nexusAPI.setAPIKey(key)
            }
            nexusLatestMods = try await nexusAPI.browseMods(sortBy: .createdAt, offset: 0)
        } catch {
            nexusError = error.localizedDescription
        }
        isNexusLoading = false
    }

    func searchNexusMods(query: String) async {
        isNexusLoading = true
        nexusError = nil
        nexusHasMore = true
        do {
            if let key = settings.nexusAPIKey {
                await nexusAPI.setAPIKey(key)
            }
            nexusSearchResults = try await nexusAPI.browseMods(sortBy: .downloads, searchText: query)
        } catch {
            nexusError = error.localizedDescription
        }
        isNexusLoading = false
    }

    enum NexusTab { case trending, latest, search }

    func loadMoreMods(tab: NexusTab) async {
        guard !isNexusLoadingMore, nexusHasMore else { return }
        isNexusLoadingMore = true
        do {
            if let key = settings.nexusAPIKey {
                await nexusAPI.setAPIKey(key)
            }
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
            if let key = settings.nexusAPIKey {
                await nexusAPI.setAPIKey(key)
            }
            let links = try await nexusAPI.downloadLinks(modId: modId, fileId: fileId)
            guard let link = links.first else {
                nexusError = "No download links available."
                isNexusLoading = false
                return
            }

            let tempDir = FileManager.default.temporaryDirectory
            let zipURL = try await nexusAPI.downloadFile(url: link.uri, to: tempDir)
            let imported = try ModManagementService.importMod(from: zipURL, settings: settings)
            try? FileManager.default.removeItem(at: zipURL)

            for newMod in imported {
                mods.removeAll { $0.id == newMod.id }
                mods.append(newMod)
            }
            mods.sort { $0.manifest.name.localizedCaseInsensitiveCompare($1.manifest.name) == .orderedAscending }
            DependencyResolver.resolveAll(mods: mods)
        } catch let error as NexusAPIError where error.localizedDescription == NexusAPIError.premiumRequired.localizedDescription {
            nexusError = "Direct downloads require Nexus Premium. Opening mod page in browser instead."
            if let url = URL(string: "https://www.nexusmods.com/stardewvalley/mods/\(modId)?tab=files") {
                NSWorkspace.shared.open(url)
            }
        } catch {
            nexusError = error.localizedDescription
        }
        isNexusLoading = false
    }

    func openNexusModPage(modId: Int) {
        if let url = URL(string: "https://www.nexusmods.com/stardewvalley/mods/\(modId)") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Modpack Operations

    func loadModpacks() {
        modpacks = ModpackService.loadModpacks(settings: settings)
    }

    /// Creates a default modpack from pre-existing mods on first launch
    func createInitialModpackIfNeeded() {
        guard modpacks.isEmpty else { return }
        let userMods = mods.filter { !$0.isBuiltIn }
        guard !userMods.isEmpty else { return }

        let modpack = ModpackService.createModpack(
            name: "My Mods",
            description: "Auto-created from your existing mods",
            from: userMods
        )
        modpacks.append(modpack)
        activeModpackID = modpack.id
        do {
            try ModpackService.saveModpacks(modpacks, settings: settings)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createModpackFromCurrentState(name: String, description: String) {
        let modpack = ModpackService.createModpack(name: name, description: description, from: mods)
        modpacks.append(modpack)
        do {
            try ModpackService.saveModpacks(modpacks, settings: settings)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func applyModpack(_ modpack: Modpack) {
        isModpackLoading = true
        modpackError = nil
        do {
            let result = try ModpackService.applyModpack(modpack, mods: mods, settings: settings)
            activeModpackID = modpack.id
            loadMods()

            if !result.missing.isEmpty {
                let names = result.missing.map(\.name).joined(separator: ", ")
                showToast("Profile applied. Missing: \(names)", type: .warning)
            } else {
                showToast("Profile \"\(modpack.name)\" applied", type: .success)
            }
            SoundService.play(.bigSelect)
        } catch {
            modpackError = error.localizedDescription
        }
        isModpackLoading = false
    }

    func deleteModpack(_ modpack: Modpack) {
        do {
            try ModpackService.deleteModpack(modpack, settings: settings)
            modpacks.removeAll { $0.id == modpack.id }
            if activeModpackID == modpack.id { activeModpackID = nil }
            if selectedModpackID == modpack.id { selectedModpackID = nil }
            try ModpackService.saveModpacks(modpacks, settings: settings)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func renameModpack(_ modpack: Modpack, to newName: String) {
        guard let index = modpacks.firstIndex(where: { $0.id == modpack.id }) else { return }
        modpacks[index].name = newName
        modpacks[index].updatedAt = Date()
        do {
            try ModpackService.saveModpacks(modpacks, settings: settings)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func exportModpack(_ modpack: Modpack, asZIP: Bool, to url: URL) {
        do {
            if asZIP {
                try ModpackService.exportAsZIP(modpack, mods: mods, settings: settings, to: url)
            } else {
                try ModpackService.exportAsJSON(modpack, to: url)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func shareModpackAsSMM(_ modpack: Modpack, to url: URL) {
        do {
            let shareable = ShareableModpack.from(modpack)
            let data = try shareable.toJSON()
            try data.write(to: url, options: .atomic)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func copyModpackToClipboard(_ modpack: Modpack) {
        do {
            let shareable = ShareableModpack.from(modpack)
            let data = try shareable.toJSON()
            guard let json = String(data: data, encoding: .utf8) else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(json, forType: .string)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importModpackFromClipboard() {
        guard let string = NSPasteboard.general.string(forType: .string),
              let data = string.data(using: .utf8),
              let shareable = try? ShareableModpack.fromJSON(data) else {
            errorMessage = "No valid modpack data found in clipboard."
            return
        }
        let modpack = shareable.toModpack()
        modpacks.append(modpack)
        do {
            try ModpackService.saveModpacks(modpacks, settings: settings)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importSMMFile(url: URL) {
        do {
            let securityScoped = url.startAccessingSecurityScopedResource()
            defer { if securityScoped { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            let shareable = try ShareableModpack.fromJSON(data)
            let modpack = shareable.toModpack()
            modpacks.append(modpack)
            try ModpackService.saveModpacks(modpacks, settings: settings)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importModpackFromFile(url: URL) {
        do {
            let securityScoped = url.startAccessingSecurityScopedResource()
            defer { if securityScoped { url.stopAccessingSecurityScopedResource() } }

            if url.pathExtension.lowercased() == "smm" {
                let data = try Data(contentsOf: url)
                let shareable = try ShareableModpack.fromJSON(data)
                modpacks.append(shareable.toModpack())
            } else if url.pathExtension.lowercased() == "json" {
                let modpack = try ModpackService.importFromJSON(at: url)
                modpacks.append(modpack)
            } else {
                let (modpack, imported) = try ModpackService.importFromZIP(at: url, settings: settings)
                modpacks.append(modpack)
                for newMod in imported {
                    mods.removeAll { $0.id == newMod.id }
                    mods.append(newMod)
                }
                mods.sort { $0.manifest.name.localizedCaseInsensitiveCompare($1.manifest.name) == .orderedAscending }
                DependencyResolver.resolveAll(mods: mods)
            }
            try ModpackService.saveModpacks(modpacks, settings: settings)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importModpackFromURL(urlString: String) async {
        isModpackLoading = true
        modpackError = nil
        do {
            let tempDir = FileManager.default.temporaryDirectory
            let localURL = try await externalDownloader.downloadFile(from: urlString, to: tempDir)
            let (modpack, imported) = try ModpackService.importFromZIP(at: localURL, settings: settings)
            try? FileManager.default.removeItem(at: localURL)

            modpacks.append(modpack)
            for newMod in imported {
                mods.removeAll { $0.id == newMod.id }
                mods.append(newMod)
            }
            mods.sort { $0.manifest.name.localizedCaseInsensitiveCompare($1.manifest.name) == .orderedAscending }
            DependencyResolver.resolveAll(mods: mods)
            try ModpackService.saveModpacks(modpacks, settings: settings)
        } catch {
            modpackError = error.localizedDescription
        }
        isModpackLoading = false
    }

    func importNexusCollection(slug: String) async {
        isModpackLoading = true
        modpackError = nil
        do {
            if let key = settings.nexusAPIKey {
                await nexusAPI.setAPIKey(key)
            }
            let info = try await nexusAPI.collectionDetails(slug: slug)
            let collectionMods = try await nexusAPI.collectionMods(slug: slug)

            let entries = collectionMods.map { cm in
                ModpackEntry(
                    uniqueID: "",
                    name: cm.name,
                    version: cm.version,
                    nexusModID: cm.modId,
                    nexusFileID: cm.fileId,
                    isEnabled: !(cm.optional ?? false)
                )
            }

            var modpack = Modpack(
                id: UUID(),
                name: info.name,
                description: info.summary ?? "",
                entries: entries,
                source: .nexusCollection(collectionId: info.id),
                includesFiles: false,
                bundleFolderName: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
            _ = modpack // suppress warning
            modpacks.append(modpack)
            try ModpackService.saveModpacks(modpacks, settings: settings)
        } catch {
            modpackError = error.localizedDescription
        }
        isModpackLoading = false
    }

    // MARK: - Modpack Entry Mutations

    func toggleModpackEntry(modpackID: UUID, entryID: String) {
        guard let idx = modpacks.firstIndex(where: { $0.id == modpackID }) else { return }

        if let entryIdx = modpacks[idx].entries.firstIndex(where: { $0.uniqueID == entryID }) {
            modpacks[idx].entries[entryIdx].isEnabled.toggle()
        } else if let mod = mods.first(where: { $0.id == entryID }) {
            // Entry was auto-merged from installed mods — persist it as enabled
            modpacks[idx].entries.append(ModpackEntry(
                uniqueID: mod.id,
                name: mod.manifest.name,
                version: mod.manifest.version,
                nexusModID: mod.nexusModID,
                nexusFileID: nil,
                isEnabled: true
            ))
        }

        modpacks[idx].updatedAt = Date()
        try? ModpackService.saveModpacks(modpacks, settings: settings)
    }

    func removeModpackEntry(modpackID: UUID, entryID: String) {
        guard let idx = modpacks.firstIndex(where: { $0.id == modpackID }) else { return }
        modpacks[idx].entries.removeAll { $0.uniqueID == entryID }
        modpacks[idx].updatedAt = Date()
        try? ModpackService.saveModpacks(modpacks, settings: settings)
    }

    func addModToModpack(modpackID: UUID, mod: Mod) {
        guard let idx = modpacks.firstIndex(where: { $0.id == modpackID }) else { return }
        guard !modpacks[idx].entries.contains(where: { $0.uniqueID == mod.id }) else { return }
        let entry = ModpackEntry(
            uniqueID: mod.id, name: mod.manifest.name, version: mod.manifest.version,
            nexusModID: mod.nexusModID, nexusFileID: nil, isEnabled: true
        )
        modpacks[idx].entries.append(entry)
        modpacks[idx].updatedAt = Date()
        try? ModpackService.saveModpacks(modpacks, settings: settings)
    }
}
