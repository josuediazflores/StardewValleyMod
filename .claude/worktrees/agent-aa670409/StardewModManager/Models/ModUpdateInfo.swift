import Foundation

// MARK: - SMAPI Update Check API Models

struct ModUpdateInfo {
    let modID: String
    let currentVersion: String
    let newVersion: String
    let updateURL: String?
}

// Request models
struct SMAPIUpdateRequest: Encodable {
    let mods: [SMAPIModSearchEntry]
    let apiVersion: String
    let gameVersion: String
    let platform: String
    let includeExtendedMetadata: Bool
}

struct SMAPIModSearchEntry: Encodable {
    let id: String
    let installedVersion: String
    let updateKeys: [String]
}

// Response models
struct SMAPIUpdateResponse: Decodable {
    let id: String
    let suggestedUpdate: SuggestedUpdate?
}

struct SuggestedUpdate: Decodable {
    let version: String
    let url: String?
}
