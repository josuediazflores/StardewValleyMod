import Foundation

enum ModType: String, CaseIterable, Identifiable {
    case codeMod = "Code Mod"
    case contentPack = "Content Pack"
    case unknown = "Unknown"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .codeMod: L.s("mod_type_code")
        case .contentPack: L.s("mod_type_content")
        case .unknown: L.s("mod_type_unknown")
        }
    }
}

enum DependencyStatus: Equatable {
    case satisfied
    case missing
    case disabled
}

struct ResolvedDependency: Identifiable {
    let entry: ModDependencyEntry
    let status: DependencyStatus
    let modName: String?

    var id: String { entry.uniqueID }
}

enum ModFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case enabled = "Enabled"
    case disabled = "Disabled"
    case codeMods = "Code Mods"
    case contentPacks = "Content Packs"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: L.s("filter_all")
        case .enabled: L.s("filter_enabled")
        case .disabled: L.s("filter_disabled")
        case .codeMods: L.s("filter_code_mods")
        case .contentPacks: L.s("filter_content_packs")
        }
    }

    var shortLabel: String {
        switch self {
        case .all: L.s("filter_all")
        case .enabled: L.s("filter_enabled")
        case .disabled: L.s("filter_disabled")
        case .codeMods: L.s("filter_code_short")
        case .contentPacks: L.s("filter_packs_short")
        }
    }
}

@Observable
final class Mod: Identifiable, Hashable {
    let id: String
    let manifest: ModManifest
    let folderName: String
    var folderURL: URL
    var isEnabled: Bool
    let isBuiltIn: Bool
    let subfolder: String?

    var resolvedDependencies: [ResolvedDependency] = []

    var modType: ModType {
        if manifest.entryDll != nil { return .codeMod }
        if manifest.contentPackFor != nil { return .contentPack }
        return .unknown
    }

    var nexusModID: Int? {
        guard let keys = manifest.updateKeys else { return nil }
        for key in keys {
            let parts = key.split(separator: ":")
            if parts.count == 2, parts[0].lowercased() == "nexus", let id = Int(parts[1]) {
                return id
            }
        }
        return nil
    }

    init(manifest: ModManifest, folderName: String, folderURL: URL, isEnabled: Bool, subfolder: String? = nil) {
        self.id = manifest.uniqueID
        self.manifest = manifest
        self.folderName = folderName
        self.folderURL = folderURL
        self.isEnabled = isEnabled
        self.isBuiltIn = manifest.uniqueID.hasPrefix("SMAPI.")
        self.subfolder = subfolder
    }

    static func == (lhs: Mod, rhs: Mod) -> Bool {
        lhs.id == rhs.id && lhs.isEnabled == rhs.isEnabled
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
