import Foundation

struct NexusCollectionInfo: Codable, Identifiable {
    let id: Int
    let slug: String
    let name: String
    let summary: String?
    let author: String?
    let modCount: Int?
    let endorsements: Int?
    let imageUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, slug, name, summary, author
        case modCount = "mod_count"
        case endorsements
        case imageUrl = "image_url"
    }
}

struct NexusCollectionMod: Codable, Identifiable {
    let modId: Int
    let name: String
    let version: String?
    let fileId: Int?
    let optional: Bool?

    var id: Int { modId }

    enum CodingKeys: String, CodingKey {
        case modId = "mod_id"
        case name, version
        case fileId = "file_id"
        case optional
    }
}
