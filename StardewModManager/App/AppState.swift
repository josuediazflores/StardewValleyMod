import Foundation
import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case myMods = "My Mods"
    case browseNexus = "Browse Nexus"
    case importMods = "Import Mods"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .myMods: return "folder.fill"
        case .browseNexus: return "globe"
        case .importMods: return "square.and.arrow.down"
        case .settings: return "gear"
        }
    }
}

@Observable
@MainActor
final class AppState {
    var settings = AppSettings()
    var mods: [Mod] = []
    var sidebarSelection: SidebarItem? = .myMods
    var selectedModID: String?
    var searchText = ""
    var filterMode: ModFilter = .all
    var isLoading = false
    var errorMessage: String?

    // Nexus state
    var nexusTrendingMods: [NexusModInfo] = []
    var nexusLatestMods: [NexusModInfo] = []
    var nexusSearchResults: [NexusModInfo] = []
    var nexusSearchText = ""
    var isNexusLoading = false
    var nexusError: String?

    let nexusAPI = NexusAPIService()

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

    // MARK: - Game Launch

    func launchGame() {
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
}
