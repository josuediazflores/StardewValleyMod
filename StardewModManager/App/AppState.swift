import Foundation
import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case modpacks = "Modpacks"
    case browseNexus = "Browse Nexus"
    case importMods = "Import Mods"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .modpacks: return "archivebox.fill"
        case .browseNexus: return "globe"
        case .importMods: return "square.and.arrow.down"
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
    var showInspector = true
    var errorMessage: String?

    // Update checking state
    var modUpdates: [String: ModUpdateInfo] = [:]
    var isCheckingUpdates = false

    // NXM protocol state
    var nxmDownloadStatus: String?
    var showModpackPicker = false
    var pendingNXMMods: [Mod] = []

    // Nexus state
    var nexusTrendingMods: [NexusModInfo] = []
    var nexusLatestMods: [NexusModInfo] = []
    var nexusSearchResults: [NexusModInfo] = []
    var nexusSearchText = ""
    var isNexusLoading = false
    var nexusError: String?

    let nexusAPI = NexusAPIService()
    let externalDownloader = ExternalDownloadService()

    // Modpack state
    var modpacks: [Modpack] = []
    var activeModpackID: UUID?
    var selectedModpackID: UUID?
    var isModpackLoading = false
    var modpackError: String?
    var expandedModpackID: UUID? = AppState.currentProfileID

    static let currentProfileID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    var activeModpack: Modpack? {
        guard let id = activeModpackID else { return nil }
        return modpacks.first { $0.id == id }
    }

    var selectedModpack: Modpack? {
        guard let id = selectedModpackID else { return nil }
        return modpacks.first { $0.id == id }
    }

    var currentProfileModpack: Modpack {
        let entries = mods.filter { !$0.isBuiltIn }.map { mod in
            ModpackEntry(
                uniqueID: mod.id,
                name: mod.manifest.name,
                version: mod.manifest.version,
                nexusModID: mod.nexusModID,
                nexusFileID: nil,
                isEnabled: mod.isEnabled
            )
        }
        return Modpack(
            id: AppState.currentProfileID,
            name: "Current Profile",
            description: "Your currently installed mods",
            entries: entries,
            source: .currentProfile,
            includesFiles: false,
            bundleFolderName: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    var filteredModpacks: [Modpack] {
        guard !searchText.isEmpty, expandedModpackID == nil else { return modpacks }
        let query = searchText.lowercased()
        return modpacks.filter {
            $0.name.lowercased().contains(query) ||
            $0.description.lowercased().contains(query)
        }
    }

    func filteredEntriesForModpack(_ modpack: Modpack) -> [ModpackEntry] {
        var result = modpack.entries

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
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func performDisableMod(_ mod: Mod) {
        do {
            try ModManagementService.disableMod(mod, settings: settings)
            DependencyResolver.resolveAll(mods: mods)
        } catch {
            errorMessage = error.localizedDescription
        }
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
        for url in urls {
            do {
                let securityScoped = url.startAccessingSecurityScopedResource()
                defer { if securityScoped { url.stopAccessingSecurityScopedResource() } }

                let imported = try ModManagementService.importMod(from: url, settings: settings)
                for newMod in imported {
                    mods.removeAll { $0.id == newMod.id }
                    mods.append(newMod)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        mods.sort { $0.manifest.name.localizedCaseInsensitiveCompare($1.manifest.name) == .orderedAscending }
        DependencyResolver.resolveAll(mods: mods)
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
                let imported = try ModManagementService.importMod(from: zipURL, settings: settings)
                try? FileManager.default.removeItem(at: zipURL)

                for newMod in imported {
                    mods.removeAll { $0.id == newMod.id }
                    mods.append(newMod)
                }
                mods.sort { $0.manifest.name.localizedCaseInsensitiveCompare($1.manifest.name) == .orderedAscending }
                DependencyResolver.resolveAll(mods: mods)

                nxmDownloadStatus = nil
                pendingNXMMods = imported
                showModpackPicker = true
            } catch {
                nxmDownloadStatus = nil
                errorMessage = "NXM download failed: \(error.localizedDescription)"
            }
        }
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

    // MARK: - Game Launch

    func launchGame() {
        if let soundURL = Bundle.module.url(forResource: "bigSelect", withExtension: "wav") {
            NSSound(contentsOf: soundURL, byReference: true)?.play()
        }
        do {
            try GameLauncherService.launch(settings: settings)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Nexus Operations

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

    func loadTrendingMods() async {
        isNexusLoading = true
        nexusError = nil
        do {
            if let key = settings.nexusAPIKey {
                await nexusAPI.setAPIKey(key)
            }
            nexusTrendingMods = try await nexusAPI.trendingMods()
        } catch {
            nexusError = error.localizedDescription
        }
        isNexusLoading = false
    }

    func loadLatestMods() async {
        isNexusLoading = true
        nexusError = nil
        do {
            if let key = settings.nexusAPIKey {
                await nexusAPI.setAPIKey(key)
            }
            nexusLatestMods = try await nexusAPI.latestAddedMods()
        } catch {
            nexusError = error.localizedDescription
        }
        isNexusLoading = false
    }

    func searchNexusMods(query: String) async {
        isNexusLoading = true
        nexusError = nil
        do {
            if let key = settings.nexusAPIKey {
                await nexusAPI.setAPIKey(key)
            }
            nexusSearchResults = try await nexusAPI.searchMods(query: query)
        } catch {
            nexusError = error.localizedDescription
        }
        isNexusLoading = false
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
                modpackError = "Applied profile. Missing mods: \(names)"
            }
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

    func importModpackFromFile(url: URL) {
        do {
            let securityScoped = url.startAccessingSecurityScopedResource()
            defer { if securityScoped { url.stopAccessingSecurityScopedResource() } }

            if url.pathExtension.lowercased() == "json" {
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
        guard let idx = modpacks.firstIndex(where: { $0.id == modpackID }),
              let entryIdx = modpacks[idx].entries.firstIndex(where: { $0.uniqueID == entryID }) else { return }
        modpacks[idx].entries[entryIdx].isEnabled.toggle()
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
