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

    var isUpdating = false
    var updateError: String?

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

    init() {
        // Feed the Nexus API key to the actor from one place: push the current key now (loaded
        // from the Keychain by AppSettings) and again whenever it changes, so the individual
        // request paths don't each have to re-push it before every call.
        let api = nexusAPI
        settings.onNexusAPIKeyChange = { key in
            Task { await api.setAPIKey(key) }
        }
        if let key = settings.nexusAPIKey {
            Task { await api.setAPIKey(key) }
        }
    }

    // MARK: - Mod Library

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

    // MARK: - Mod Loading

    func loadMods() {
        isLoading = true
        errorMessage = nil

        mods = ModDiscoveryService.discoverMods(settings: settings)
        DependencyResolver.resolveAll(mods: mods)
        loadModpacks()

        isLoading = false
    }

    /// A move can replace a stale same-ID copy on disk; drop any in-memory Mod
    /// whose backing folder no longer exists so the list can't show phantoms.
    func pruneStaleDuplicates(of mod: Mod) {
        let fm = FileManager.default
        mods.removeAll {
            $0 !== mod
                && $0.id.caseInsensitiveCompare(mod.id) == .orderedSame
                && !fm.fileExists(atPath: $0.folderURL.path(percentEncoded: false))
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

}
