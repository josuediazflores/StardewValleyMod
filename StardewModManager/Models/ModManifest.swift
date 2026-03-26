import Foundation

struct ContentPackReference: Decodable, Hashable {
    let uniqueID: String
    let minimumVersion: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let id = try? container.decode(String.self, forKey: .uniqueID) {
            uniqueID = id
        } else {
            uniqueID = try container.decode(String.self, forKey: .uniqueId)
        }
        minimumVersion = try container.decodeIfPresent(String.self, forKey: .minimumVersion)
    }

    private enum CodingKeys: String, CodingKey {
        case uniqueID = "UniqueID"
        case uniqueId = "UniqueId"
        case minimumVersion = "MinimumVersion"
    }
}

struct ModDependencyEntry: Decodable, Hashable {
    let uniqueID: String
    let minimumVersion: String?
    let isRequired: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let id = try? container.decode(String.self, forKey: .uniqueID) {
            uniqueID = id
        } else {
            uniqueID = try container.decode(String.self, forKey: .uniqueId)
        }

        minimumVersion = try container.decodeIfPresent(String.self, forKey: .minimumVersion)

        if let req = try? container.decode(Bool.self, forKey: .isRequired) {
            isRequired = req
        } else if let req = try? container.decode(Bool.self, forKey: .required) {
            isRequired = req
        } else {
            isRequired = true
        }
    }

    private enum CodingKeys: String, CodingKey {
        case uniqueID = "UniqueID"
        case uniqueId = "UniqueId"
        case minimumVersion = "MinimumVersion"
        case isRequired = "IsRequired"
        case required = "Required"
    }
}

struct ModManifest: Decodable, Hashable {
    let name: String
    let author: String
    let version: String
    let description: String?
    let uniqueID: String
    let entryDll: String?
    let contentPackFor: ContentPackReference?
    let dependencies: [ModDependencyEntry]?
    let updateKeys: [String]?
    let minimumApiVersion: String?
    let minimumGameVersion: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        author = try container.decode(String.self, forKey: .author)
        version = try container.decode(String.self, forKey: .version)
        description = try container.decodeIfPresent(String.self, forKey: .description)

        if let id = try? container.decode(String.self, forKey: .uniqueID) {
            uniqueID = id
        } else {
            uniqueID = try container.decode(String.self, forKey: .uniqueId)
        }

        entryDll = try container.decodeIfPresent(String.self, forKey: .entryDll)
        contentPackFor = try container.decodeIfPresent(ContentPackReference.self, forKey: .contentPackFor)
        dependencies = try container.decodeIfPresent([ModDependencyEntry].self, forKey: .dependencies)
        updateKeys = try container.decodeIfPresent([String].self, forKey: .updateKeys)
        minimumApiVersion = try container.decodeIfPresent(String.self, forKey: .minimumApiVersion)
        minimumGameVersion = try container.decodeIfPresent(String.self, forKey: .minimumGameVersion)
    }

    private enum CodingKeys: String, CodingKey {
        case name = "Name"
        case author = "Author"
        case version = "Version"
        case description = "Description"
        case uniqueID = "UniqueID"
        case uniqueId = "UniqueId"
        case entryDll = "EntryDll"
        case contentPackFor = "ContentPackFor"
        case dependencies = "Dependencies"
        case updateKeys = "UpdateKeys"
        case minimumApiVersion = "MinimumApiVersion"
        case minimumGameVersion = "MinimumGameVersion"
    }
}
