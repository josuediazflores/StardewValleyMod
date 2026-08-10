import Foundation

enum ShareableModpackError: LocalizedError {
    case unsupportedFormatVersion(found: Int, supported: Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormatVersion:
            return "This modpack was made with a newer version of Stardew Mod Manager. Please update to import it."
        }
    }
}

struct ShareableModpack: Codable {
    /// Highest modpack format version this build knows how to read.
    static let currentSupportedFormatVersion = 1

    let formatVersion: Int
    let name: String
    let description: String
    let modCount: Int
    let createdAt: Date
    let mods: [ShareableModpackMod]

    struct ShareableModpackMod: Codable {
        let uniqueID: String
        let name: String
        let version: String?
        let nexusModID: Int?
    }

    /// Create from a Modpack, including only enabled entries
    static func from(_ modpack: Modpack) -> ShareableModpack {
        let enabledEntries = modpack.entries.filter(\.isEnabled)
        return ShareableModpack(
            formatVersion: 1,
            name: modpack.name,
            description: modpack.description,
            modCount: enabledEntries.count,
            createdAt: modpack.createdAt,
            mods: enabledEntries.map { entry in
                ShareableModpackMod(
                    uniqueID: entry.uniqueID,
                    name: entry.name,
                    version: entry.version,
                    nexusModID: entry.nexusModID
                )
            }
        )
    }

    /// Convert to a Modpack for import (all mods set as enabled)
    func toModpack() -> Modpack {
        Modpack(
            id: UUID(),
            name: name,
            description: description,
            entries: mods.map { mod in
                ModpackEntry(
                    uniqueID: mod.uniqueID,
                    name: mod.name,
                    version: mod.version,
                    nexusModID: mod.nexusModID,
                    nexusFileID: nil,
                    isEnabled: true
                )
            },
            source: .imported(fileName: "\(name).smm"),
            includesFiles: false,
            bundleFolderName: nil,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }

    /// Encode to pretty-printed JSON data
    func toJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// Decode from JSON data
    static func fromJSON(_ data: Data) throws -> ShareableModpack {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let modpack = try decoder.decode(ShareableModpack.self, from: data)
        guard modpack.formatVersion <= currentSupportedFormatVersion else {
            throw ShareableModpackError.unsupportedFormatVersion(
                found: modpack.formatVersion,
                supported: currentSupportedFormatVersion
            )
        }
        return modpack
    }
}
