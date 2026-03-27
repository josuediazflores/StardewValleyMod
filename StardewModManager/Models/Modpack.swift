import Foundation

struct ModpackEntry: Codable, Identifiable, Hashable {
    let uniqueID: String
    let name: String
    let version: String?
    let nexusModID: Int?
    let nexusFileID: Int?
    var isEnabled: Bool

    var id: String { uniqueID }
}

enum ModpackSource: Codable, Hashable {
    case manual
    case imported(fileName: String)
    case nexusCollection(collectionId: Int)
    case externalURL(urlString: String)
}

struct Modpack: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var description: String
    var entries: [ModpackEntry]
    var source: ModpackSource
    var includesFiles: Bool
    var bundleFolderName: String?
    let createdAt: Date
    var updatedAt: Date

    static func == (lhs: Modpack, rhs: Modpack) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct ApplyResult {
    let enabled: [String]
    let disabled: [String]
    let missing: [ModpackEntry]
    let alreadyCorrect: Int
}

struct TrustWarning {
    let sourceURL: String
    let message: String
    let risks: [String]

    static func forURL(_ urlString: String) -> TrustWarning {
        let lowered = urlString.lowercased()

        if lowered.contains("drive.google.com") {
            return TrustWarning(
                sourceURL: urlString,
                message: "This file is hosted on Google Drive. Google Drive links can be modified by the uploader at any time.",
                risks: [
                    "The file contents may have changed since it was originally shared.",
                    "Google Drive files are not scanned for mod compatibility.",
                    "The uploader's identity cannot be verified."
                ]
            )
        }

        if lowered.contains("nexusmods.com") {
            return TrustWarning(
                sourceURL: urlString,
                message: "This file is from Nexus Mods, a trusted modding platform.",
                risks: [
                    "Always check mod compatibility with your game version.",
                    "Review the mod page for any known issues before installing."
                ]
            )
        }

        if lowered.hasSuffix(".zip") || lowered.hasSuffix(".7z") || lowered.hasSuffix(".rar") {
            return TrustWarning(
                sourceURL: urlString,
                message: "This is a direct link to an archive file. Exercise caution with direct downloads from unknown sources.",
                risks: [
                    "The file source cannot be verified.",
                    "Archive contents may include unexpected or malicious files.",
                    "No automatic virus scanning is performed.",
                    "The file may not be compatible with your game version."
                ]
            )
        }

        return TrustWarning(
            sourceURL: urlString,
            message: "This file is from an unrecognized source. Proceed with caution.",
            risks: [
                "The source has not been verified as a trusted modding platform.",
                "File contents and safety cannot be guaranteed.",
                "No automatic virus scanning is performed.",
                "The file may not be compatible with your game version."
            ]
        )
    }
}
