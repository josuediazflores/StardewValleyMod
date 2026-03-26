import Foundation

enum ModType: String, CaseIterable, Identifiable {
    case codeMod = "Code Mod"
    case contentPack = "Content Pack"
    case unknown = "Unknown"

    var id: String { rawValue }
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
}

@Observable
final class Mod: Identifiable, Hashable {
    let id: String
    let manifest: ModManifest
    let folderName: String
    var folderURL: URL
    var isEnabled: Bool
    let isBuiltIn: Bool

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

    init(manifest: ModManifest, folderName: String, folderURL: URL, isEnabled: Bool) {
        self.id = manifest.uniqueID
        self.manifest = manifest
        self.folderName = folderName
        self.folderURL = folderURL
        self.isEnabled = isEnabled
        self.isBuiltIn = manifest.uniqueID.hasPrefix("SMAPI.")
    }

    static func == (lhs: Mod, rhs: Mod) -> Bool {
        lhs.id == rhs.id && lhs.isEnabled == rhs.isEnabled
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
