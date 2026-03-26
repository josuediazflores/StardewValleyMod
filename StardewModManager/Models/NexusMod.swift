import Foundation

struct NexusModInfo: Codable, Identifiable {
    let modId: Int
    let name: String
    let summary: String
    let description: String?
    let version: String
    let author: String
    let pictureUrl: String?
    let endorsementCount: Int?
    let modDownloads: Int?
    let modUniqueDownloads: Int?
    let categoryId: Int?
    let available: Bool?

    var id: Int { modId }

    enum CodingKeys: String, CodingKey {
        case modId = "mod_id"
        case name, summary, description, version, author
        case pictureUrl = "picture_url"
        case endorsementCount = "endorsement_count"
        case modDownloads = "mod_downloads"
        case modUniqueDownloads = "mod_unique_downloads"
        case categoryId = "category_id"
        case available
    }
}

struct NexusModFileInfo: Codable, Identifiable {
    let fileId: Int
    let name: String
    let version: String?
    let categoryName: String?
    let isPrimary: Bool?
    let sizeKb: Int?
    let fileName: String?
    let description: String?

    var id: Int { fileId }

    enum CodingKeys: String, CodingKey {
        case fileId = "file_id"
        case name, version, description
        case categoryName = "category_name"
        case isPrimary = "is_primary"
        case sizeKb = "size_kb"
        case fileName = "file_name"
    }
}

struct NexusModFilesResponse: Codable {
    let files: [NexusModFileInfo]
}

struct NexusDownloadLink: Codable {
    let uri: String
    let name: String
    let shortName: String?

    enum CodingKeys: String, CodingKey {
        case uri = "URI"
        case name
        case shortName = "short_name"
    }
}

struct NexusUser: Codable {
    let userId: Int?
    let key: String?
    let name: String?
    let isPremium: Bool?
    let isSupporter: Bool?
    let email: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case key, name
        case isPremium = "is_premium"
        case isSupporter = "is_supporter"
        case email
    }
}
