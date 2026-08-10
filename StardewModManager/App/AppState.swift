import Foundation
import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case modpacks = "Modpacks"
    case installedMods = "Mods"
    case browseNexus = "Browse Nexus"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .modpacks: L.s("sidebar_modpacks")
        case .installedMods: L.s("sidebar_mods")
        case .browseNexus: L.s("sidebar_browse")
        }
    }

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
    var sortOption: ModSortOption = .name
    var isLoading = false
    var isImporting = false
    var showImportPicker = false
    var errorMessage: String?

    // Toast notification state
    var toasts: [ToastMessage] = []

    // Update checking state
    var modUpdates: [String: ModUpdateInfo] = [:]
    var isCheckingUpdates = false

    // App update state
    var availableUpdate: AppUpdate?
    var showAppUpdatePrompt = false

    // SMAPI install state
    var isSMAPIInstalling = false
    var smapiInstallError: String?

    // NXM protocol state
    var showModpackPicker = false
    var pendingNXMMods: [Mod] = []
    var pendingNXMZipURL: URL?
    var pendingNXMModNames: [String] = []
    var pendingNXMSuggestedName: String?

    // Web download sheet state
    var showWebDownloadSheet = false
    var webDownloadModName: String?
    var webDownloadURL: URL?

    // Nexus file picker state (shown when a mod has no unambiguous main file)
    var showNexusFilePicker = false
    var nexusFilePickerFiles: [NexusModFileInfo] = []
    var nexusFilePickerModId: Int?

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

    func filteredEntriesForModpack(_ modpack: Modpack) -> [ModpackEntry] {
        // Start with explicit modpack entries
        var existingIDs = Set(modpack.entries.map(\.uniqueID))
        var result = modpack.entries

        // Merge in all installed mods not already in the modpack (as disabled);
        // duplicate on-disk copies of one mod merge to a single entry
        for mod in mods {
            if !existingIDs.contains(mod.id) {
                existingIDs.insert(mod.id)
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
        case .updates:
            result = result.filter { modUpdates[$0.uniqueID] != nil }
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
        case .updates: result = result.filter { modUpdates[$0.id] != nil }
        }

        switch sortOption {
        case .name:
            result.sort { $0.manifest.name.localizedCaseInsensitiveCompare($1.manifest.name) == .orderedAscending }
        case .dateAdded:
            result.sort { $0.dateAdded > $1.dateAdded }
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
            pruneStaleDuplicates(of: mod)
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
            pruneStaleDuplicates(of: mod)
            DependencyResolver.resolveAll(mods: mods)
            syncActiveModpackEntry(mod: mod, isEnabled: false)
            showToast("\(mod.manifest.name) disabled", type: .info)
            SoundService.play(.click)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// A move can replace a stale same-ID copy on disk; drop any in-memory Mod
    /// whose backing folder no longer exists so the list can't show phantoms.
    private func pruneStaleDuplicates(of mod: Mod) {
        let fm = FileManager.default
        mods.removeAll {
            $0 !== mod
                && $0.id.caseInsensitiveCompare(mod.id) == .orderedSame
                && !fm.fileExists(atPath: $0.folderURL.path(percentEncoded: false))
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
        persistModpacks()
    }

    /// Imports mods off the main thread so a large (hundreds-of-MB) archive can't
    /// beachball the UI: the heavy extraction + recursive copy run on a detached
    /// executor and `mods` is only mutated back on the MainActor after each await.
    func importMods(from urls: [URL]) {
        guard !isImporting else { return }

        // A source that lives in our own temp dir (e.g. a peer-transfer zip) can be
        // deleted by the caller the instant this method returns, which would race the
        // background read. Take ownership of those synchronously with an O(1) move so
        // the detached import reads a copy the caller can't pull out from under it.
        // User-picked files are left in place and read under a held security scope;
        // their callers never delete them.
        let fm = FileManager.default
        let tempBase = fm.temporaryDirectory.resolvingSymlinksInPath().path(percentEncoded: false)
        var sources: [(url: URL, isOwnedCopy: Bool)] = []
        for url in urls {
            let resolved = url.resolvingSymlinksInPath().path(percentEncoded: false)
            if resolved.hasPrefix(tempBase) {
                let staged = fm.temporaryDirectory.appending(path: "import_\(UUID().uuidString)_\(url.lastPathComponent)")
                if (try? fm.moveItem(at: url, to: staged)) != nil {
                    sources.append((staged, true))
                    continue
                }
            }
            sources.append((url, false))
        }

        isImporting = true
        isLoading = true
        let currentSettings = settings
        Task {
            defer {
                isImporting = false
                isLoading = false
            }
            var allImported: [Mod] = []
            var allFailures: [ImportFailure] = []
            for source in sources {
                let url = source.url
                let securityScoped = url.startAccessingSecurityScopedResource()
                do {
                    let existing = mods
                    let result = try await Task.detached(priority: .userInitiated) {
                        try ModManagementService.importMod(from: url, settings: currentSettings, existingMods: existing)
                    }.value
                    for newMod in result.mods {
                        mods.removeAll { $0.id == newMod.id }
                        mods.append(newMod)
                        allImported.append(newMod)
                    }
                    allFailures.append(contentsOf: result.failures)
                } catch {
                    errorMessage = error.localizedDescription
                }
                if securityScoped { url.stopAccessingSecurityScopedResource() }
                if source.isOwnedCopy { try? fm.removeItem(at: source.url) }
            }
            mods.sort { $0.manifest.name.localizedCaseInsensitiveCompare($1.manifest.name) == .orderedAscending }
            DependencyResolver.resolveAll(mods: mods)
            addNewModsToActiveModpack(allImported)
            if !allImported.isEmpty {
                showToast("Imported \(allImported.count) mod\(allImported.count == 1 ? "" : "s")", type: .success)
                SoundService.play(.bigSelect)
            }
            if !allFailures.isEmpty {
                let names = allFailures.prefix(3).map(\.name).joined(separator: ", ")
                let suffix = allFailures.count > 3 ? ", …" : ""
                showToast("\(allFailures.count) mod\(allFailures.count == 1 ? "" : "s") failed to import: \(names)\(suffix)", type: .warning)
            }
        }
    }

    /// Auto-adds newly installed mods to the active modpack, recording each mod's
    /// actual on-disk enabled state (imported mods install enabled).
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
                isEnabled: mod.isEnabled
            )
            modpacks[idx].entries.append(entry)
        }
        modpacks[idx].updatedAt = Date()
        persistModpacks()
    }

    // MARK: - Update Checking

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

    // MARK: - SMAPI Installation

    func installSMAPI() {
        guard settings.isGamePathValid else {
            showToast("Set your game path before installing SMAPI", type: .warning)
            return
        }
        guard !isSMAPIInstalling else { return }
        isSMAPIInstalling = true
        smapiInstallError = nil
        Task {
            do {
                try await SMAPIInstallService.downloadAndInstall(to: settings.gamePath)
                showToast("SMAPI installed!", type: .success)
                SoundService.play(.bigSelect)
            } catch {
                smapiInstallError = error.localizedDescription
                showToast("SMAPI install failed", type: .warning)
            }
            isSMAPIInstalling = false
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

    func addModsToModpack(_ modpackID: UUID, mods modsToAdd: [Mod]) {
        guard let index = modpacks.firstIndex(where: { $0.id == modpackID }) else { return }
        for mod in modsToAdd {
            // Mods are being explicitly added to this profile, so enable them. Update
            // an existing entry to enabled rather than skipping it.
            if let existingIdx = modpacks[index].entries.firstIndex(where: {
                $0.uniqueID.caseInsensitiveCompare(mod.id) == .orderedSame
            }) {
                modpacks[index].entries[existingIdx].isEnabled = true
            } else {
                modpacks[index].entries.append(ModpackEntry(
                    uniqueID: mod.id,
                    name: mod.manifest.name,
                    version: mod.manifest.version,
                    nexusModID: mod.nexusModID,
                    nexusFileID: nil,
                    isEnabled: true
                ))
            }
        }
        persistModpacks()
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
                if let key = settings.nexusAPIKey {
                    await nexusAPI.setAPIKey(key)
                }

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
            if let key = settings.nexusAPIKey {
                await nexusAPI.setAPIKey(key)
            }
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

    // MARK: - App Update Check

    var isUpdating = false
    var updateError: String?

    func checkForAppUpdate() {
        Task {
            do {
                availableUpdate = try await UpdateService.checkForUpdate()
                if availableUpdate != nil {
                    showAppUpdatePrompt = true
                }
            } catch {
                // Silent startup check: don't interrupt the user, just log.
                NSLog("[AppState] Silent app-update check failed: \(error.localizedDescription)")
            }
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
        /// Modpack membership stripped on delete, captured so undo can restore it.
        let removedEntries: [(modpackID: UUID, entry: ModpackEntry)]
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

                // Drop only the trashed on-disk instance; a same-ID duplicate copy
                // (a supported state) at a different path must survive.
                mods.removeAll { $0.folderURL == mod.folderURL }
                if selectedModID == mod.id { selectedModID = nil }
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        guard !deletedMods.isEmpty else { return }

        // Capture the modpack entries about to be stripped so undo can put them back.
        let deletedIDs = deletedMods.map(\.id)
        var removedEntries: [(modpackID: UUID, entry: ModpackEntry)] = []
        for modpack in modpacks {
            for entry in modpack.entries
            where deletedIDs.contains(where: { $0.caseInsensitiveCompare(entry.uniqueID) == .orderedSame }) {
                removedEntries.append((modpackID: modpack.id, entry: entry))
            }
        }

        for mod in deletedMods {
            removeModFromAllModpacks(mod.id)
        }
        DependencyResolver.resolveAll(mods: mods)

        let pending = PendingDeletion(
            id: deletionID,
            mods: deletedMods,
            originalURLs: originalURLs,
            wasEnabled: wasEnabled,
            stagingURLs: stagingURLs,
            removedEntries: removedEntries
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
            let targetURL = pending.originalURLs[i]

            do {
                let restoredURL = try ModManagementService.restoreFromTrash(stagingURL: pending.stagingURLs[i], to: targetURL)
                mod.folderURL = restoredURL
                mod.folderName = restoredURL.lastPathComponent
                mod.isEnabled = pending.wasEnabled[i]
                mods.append(mod)
            } catch {
                errorMessage = "Failed to restore \(mod.manifest.name): \(error.localizedDescription)"
            }
        }

        mods.sort { $0.manifest.name.localizedCaseInsensitiveCompare($1.manifest.name) == .orderedAscending }
        DependencyResolver.resolveAll(mods: mods)

        // Restore the modpack membership that softDeleteMods stripped, guarding
        // against modpacks that no longer exist and against re-adding duplicates.
        var modpacksChanged = false
        for removed in pending.removedEntries {
            guard let idx = modpacks.firstIndex(where: { $0.id == removed.modpackID }) else { continue }
            if !modpacks[idx].entries.contains(where: { $0.uniqueID.caseInsensitiveCompare(removed.entry.uniqueID) == .orderedSame }) {
                modpacks[idx].entries.append(removed.entry)
                modpacks[idx].updatedAt = Date()
                modpacksChanged = true
            }
        }
        if modpacksChanged {
            persistModpacks()
        }

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
        var failedCount = 0
        for id in ids {
            guard let mod = mods.first(where: { $0.id == id }), !mod.isEnabled, !mod.isBuiltIn else { continue }
            do {
                try ModManagementService.enableMod(mod, settings: settings)
                pruneStaleDuplicates(of: mod)
                syncActiveModpackEntry(mod: mod, isEnabled: true)
                enabledCount += 1
            } catch { failedCount += 1 }
        }
        DependencyResolver.resolveAll(mods: mods)
        if failedCount > 0 {
            showToast("\(failedCount) mod\(failedCount == 1 ? "" : "s") failed to enable", type: .warning)
        } else if enabledCount > 0 {
            showToast("\(enabledCount) mod\(enabledCount == 1 ? "" : "s") enabled", type: .success)
            SoundService.play(.bigSelect)
        }
    }

    func batchDisableMods(_ ids: Set<String>) {
        var disabledCount = 0
        var failedCount = 0
        for id in ids {
            guard let mod = mods.first(where: { $0.id == id }), mod.isEnabled, !mod.isBuiltIn else { continue }
            do {
                try ModManagementService.disableMod(mod, settings: settings)
                pruneStaleDuplicates(of: mod)
                // Sync only after the disk move succeeds, mirroring batchEnableMods,
                // so a failed move can't leave the profile recording a wrong state.
                syncActiveModpackEntry(mod: mod, isEnabled: false)
                disabledCount += 1
            } catch { failedCount += 1 }
        }
        DependencyResolver.resolveAll(mods: mods)
        if failedCount > 0 {
            showToast("\(failedCount) mod\(failedCount == 1 ? "" : "s") failed to disable", type: .warning)
        } else if disabledCount > 0 {
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
        if let key = settings.nexusAPIKey {
            await nexusAPI.setAPIKey(key)
        }
        var mods: [NexusModInfo] = []
        for modId in Self.essentialModIDs {
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
            if let key = settings.nexusAPIKey {
                await nexusAPI.setAPIKey(key)
            }
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
            if let key = settings.nexusAPIKey {
                await nexusAPI.setAPIKey(key)
            }
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
            if let key = settings.nexusAPIKey {
                await nexusAPI.setAPIKey(key)
            }
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

    // MARK: - Modpack Operations

    func loadModpacks() {
        modpacks = ModpackService.loadModpacks(settings: settings)
    }

    /// Persists modpacks, surfacing a failure via errorMessage instead of silently
    /// dropping it. Used by the entry-mutation/sync sites that previously swallowed
    /// the save error with `try?`.
    private func persistModpacks() {
        do {
            try ModpackService.saveModpacks(modpacks, settings: settings)
        } catch {
            errorMessage = error.localizedDescription
        }
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
        Task { await applyModpackAsync(modpack) }
    }

    /// Awaitable apply. Returns true when the profile applied without a fatal error
    /// (non-fatal per-mod failures/missing are still reported via toast). Callers that
    /// need to react to the outcome (e.g. the detail sheet's result alert) await this.
    @discardableResult
    func applyModpackAsync(_ modpack: Modpack) async -> Bool {
        guard !isModpackLoading else { return false }
        isModpackLoading = true
        modpackError = nil
        defer { isModpackLoading = false }
        do {
                // The mass folder moves run off the main thread so a large profile
                // switch can't beachball the UI. loadMods() then rebuilds `mods` from
                // disk on the MainActor, discarding the detached in-memory mutations.
                let currentSettings = settings
                let snapshot = mods
                let result = try await Task.detached(priority: .userInitiated) {
                    try ModpackService.applyModpack(modpack, mods: snapshot, settings: currentSettings)
                }.value
                activeModpackID = modpack.id

                // Always refresh mods from disk, even if some moves failed
                loadMods()

                let enabledCount = mods.filter { !$0.isBuiltIn && $0.isEnabled }.count
                if !result.failures.isEmpty {
                    let names = result.failures.prefix(3).map(\.name).joined(separator: ", ")
                    let suffix = result.failures.count > 3 ? ", …" : ""
                    showToast("Profile loaded, but \(result.failures.count) mod\(result.failures.count == 1 ? "" : "s") could not be moved: \(names)\(suffix)", type: .warning)
                } else if !result.missing.isEmpty {
                    let names = result.missing.map(\.name).joined(separator: ", ")
                    showToast("Profile loaded (\(enabledCount) mods enabled). Missing: \(names)", type: .warning)
                } else {
                    showToast("Profile \"\(modpack.name)\" loaded — \(enabledCount) mods enabled", type: .success)
                }
                SoundService.play(.bigSelect)
                return true
            } catch {
                modpackError = error.localizedDescription
                loadMods()
                return false
            }
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
              let data = string.data(using: .utf8) else {
            errorMessage = "No valid modpack data found in clipboard."
            return
        }
        do {
            // Decode inside the do/catch so a version-mismatch (or any decode) error
            // is surfaced instead of being swallowed into a generic message.
            let shareable = try ShareableModpack.fromJSON(data)
            let modpack = shareable.toModpack()
            modpacks.append(modpack)
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
        Task {
            let securityScoped = url.startAccessingSecurityScopedResource()
            defer { if securityScoped { url.stopAccessingSecurityScopedResource() } }

            do {
                if url.pathExtension.lowercased() == "smm" {
                    let data = try Data(contentsOf: url)
                    let shareable = try ShareableModpack.fromJSON(data)
                    modpacks.append(shareable.toModpack())
                } else if url.pathExtension.lowercased() == "json" {
                    let modpack = try ModpackService.importFromJSON(at: url)
                    modpacks.append(modpack)
                } else {
                    // Extraction + recursive mod copies run off the main thread.
                    let currentSettings = settings
                    let existing = mods
                    let (modpack, imported) = try await Task.detached(priority: .userInitiated) {
                        try ModpackService.importFromZIP(at: url, settings: currentSettings, existingMods: existing)
                    }.value
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
    }

    func importModpackFromURL(urlString: String) async {
        isModpackLoading = true
        modpackError = nil
        do {
            let tempDir = FileManager.default.temporaryDirectory
            let localURL = try await externalDownloader.downloadFile(from: urlString, to: tempDir)
            let currentSettings = settings
            let existing = mods
            let (modpack, imported) = try await Task.detached(priority: .userInitiated) {
                try ModpackService.importFromZIP(at: localURL, settings: currentSettings, existingMods: existing)
            }.value
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
                    // Nexus gives no SMAPI id; use a stable non-empty synthetic id so
                    // entries don't all collide on "" and applyModpack can still resolve
                    // them to installed mods via nexusModID.
                    uniqueID: "nexus:\(cm.modId)",
                    name: cm.name,
                    version: cm.version,
                    nexusModID: cm.modId,
                    nexusFileID: cm.fileId,
                    isEnabled: !(cm.optional ?? false)
                )
            }

            let modpack = Modpack(
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
        persistModpacks()
    }

    func removeModpackEntry(modpackID: UUID, entryID: String) {
        guard let idx = modpacks.firstIndex(where: { $0.id == modpackID }) else { return }
        modpacks[idx].entries.removeAll { $0.uniqueID == entryID }
        modpacks[idx].updatedAt = Date()
        persistModpacks()
    }

    func batchToggleModpackEntries(modpackID: UUID, entryIDs: Set<String>, enabled: Bool) {
        guard let idx = modpacks.firstIndex(where: { $0.id == modpackID }) else { return }
        for entryID in entryIDs {
            if let entryIdx = modpacks[idx].entries.firstIndex(where: { $0.uniqueID == entryID }) {
                modpacks[idx].entries[entryIdx].isEnabled = enabled
            }
        }
        modpacks[idx].updatedAt = Date()
        persistModpacks()
    }

    func removeModFromAllModpacks(_ modID: String) {
        var changed = false
        for i in modpacks.indices {
            let before = modpacks[i].entries.count
            modpacks[i].entries.removeAll { $0.uniqueID == modID }
            if modpacks[i].entries.count != before {
                modpacks[i].updatedAt = Date()
                changed = true
            }
        }
        if changed {
            persistModpacks()
        }
    }

    func batchRemoveModpackEntries(modpackID: UUID, entryIDs: Set<String>) {
        guard let idx = modpacks.firstIndex(where: { $0.id == modpackID }) else { return }
        modpacks[idx].entries.removeAll { entryIDs.contains($0.uniqueID) }
        modpacks[idx].updatedAt = Date()
        persistModpacks()
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
        persistModpacks()
    }
}
