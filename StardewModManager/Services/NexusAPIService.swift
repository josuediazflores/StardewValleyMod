import Foundation

enum NexusAPIError: LocalizedError {
    case noAPIKey
    case invalidAPIKey
    case rateLimited
    case networkError(String)
    case decodingError(String)
    case premiumRequired

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "No Nexus Mods API key configured."
        case .invalidAPIKey: return "Invalid API key. Please check your key in Settings."
        case .rateLimited: return "API rate limit reached. Please wait before making more requests."
        case .networkError(let msg): return "Network error: \(msg)"
        case .decodingError(let msg): return "Failed to parse response: \(msg)"
        case .premiumRequired: return "Direct downloads require a Nexus Mods Premium account."
        }
    }
}

actor NexusAPIService {
    private let baseURL = "https://api.nexusmods.com/v1"
    private let gameDomain = "stardewvalley"
    private let session = URLSession.shared

    private var apiKey: String?

    var hourlyRemaining: Int?
    var dailyRemaining: Int?

    func setAPIKey(_ key: String?) {
        apiKey = key
    }

    // MARK: - Validate API Key

    func validateKey(_ key: String) async throws -> NexusUser {
        let request = try buildRequest(path: "/users/validate.json", apiKey: key)
        let (data, response) = try await performRequest(request)
        try checkResponse(response)
        return try JSONDecoder().decode(NexusUser.self, from: data)
    }

    // MARK: - Browse Mods

    func trendingMods() async throws -> [NexusModInfo] {
        try await fetchModList(path: "/games/\(gameDomain)/mods/trending.json")
    }

    func latestAddedMods() async throws -> [NexusModInfo] {
        try await fetchModList(path: "/games/\(gameDomain)/mods/latest_added.json")
    }

    func latestUpdatedMods() async throws -> [NexusModInfo] {
        try await fetchModList(path: "/games/\(gameDomain)/mods/latest_updated.json")
    }

    func modDetails(modId: Int) async throws -> NexusModInfo {
        let request = try buildRequest(path: "/games/\(gameDomain)/mods/\(modId).json")
        let (data, response) = try await performRequest(request)
        try checkResponse(response)
        return try JSONDecoder().decode(NexusModInfo.self, from: data)
    }

    // MARK: - Mod Files

    func modFiles(modId: Int) async throws -> [NexusModFileInfo] {
        let request = try buildRequest(path: "/games/\(gameDomain)/mods/\(modId)/files.json")
        let (data, response) = try await performRequest(request)
        try checkResponse(response)
        let filesResponse = try JSONDecoder().decode(NexusModFilesResponse.self, from: data)
        return filesResponse.files
    }

    func downloadLinks(modId: Int, fileId: Int) async throws -> [NexusDownloadLink] {
        let request = try buildRequest(
            path: "/games/\(gameDomain)/mods/\(modId)/files/\(fileId)/download_link.json"
        )
        let (data, response) = try await performRequest(request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 403 {
            throw NexusAPIError.premiumRequired
        }
        try checkResponse(response)
        return try JSONDecoder().decode([NexusDownloadLink].self, from: data)
    }

    // MARK: - Download File

    func downloadFile(url: String, to destinationDir: URL) async throws -> URL {
        guard let downloadURL = URL(string: url) else {
            throw NexusAPIError.networkError("Invalid download URL")
        }

        let (tempURL, response) = try await session.download(from: downloadURL)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw NexusAPIError.networkError("Download failed with status \(httpResponse.statusCode)")
        }

        let fileName = response.suggestedFilename ?? "mod_download.zip"
        let destURL = destinationDir.appending(path: fileName)

        let fm = FileManager.default
        if fm.fileExists(atPath: destURL.path(percentEncoded: false)) {
            try fm.removeItem(at: destURL)
        }
        try fm.moveItem(at: tempURL, to: destURL)

        return destURL
    }

    // MARK: - Search (v2 GraphQL)

    func searchMods(query: String) async throws -> [NexusModInfo] {
        guard let key = apiKey, !key.isEmpty else { throw NexusAPIError.noAPIKey }

        let graphqlURL = URL(string: "https://api.nexusmods.com/v2/graphql")!
        var request = URLRequest(url: graphqlURL)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let graphqlQuery = """
        {
          "query": "query SearchMods($searchText: String!) { mods(filter: { gameDomainName: { value: \\"stardewvalley\\" }, searchText: { value: $searchText } }, sortBy: { downloads: { direction: DESC } }) { nodes { modId name summary version author pictureUrl endorsementCount modDownloads } } }",
          "variables": { "searchText": "\(query.replacingOccurrences(of: "\"", with: "\\\""))" }
        }
        """
        request.httpBody = graphqlQuery.data(using: .utf8)

        let (data, response) = try await performRequest(request)
        try checkResponse(response)

        // Parse the GraphQL response
        struct GraphQLResponse: Codable {
            struct DataField: Codable {
                struct ModsField: Codable {
                    let nodes: [NexusModInfo]
                }
                let mods: ModsField
            }
            let data: DataField
        }

        let gqlResponse = try JSONDecoder().decode(GraphQLResponse.self, from: data)
        return gqlResponse.data.mods.nodes
    }

    // MARK: - Collections

    func collectionDetails(slug: String) async throws -> NexusCollectionInfo {
        guard let apiKey, !apiKey.isEmpty else { throw NexusAPIError.noAPIKey }

        let query = """
        query { collectionRevision(slug: "\(slug)", gameDomainName: "\(gameDomain)") { collection { id name summary description user { name } endorsements modCount } } }
        """
        let body: [String: Any] = ["query": query]
        let jsonData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: URL(string: "https://api.nexusmods.com/v2/graphql")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        let (data, response) = try await performRequest(request)
        try checkResponse(response)

        struct GQLResponse: Codable {
            struct DataField: Codable {
                struct RevisionField: Codable {
                    struct CollectionField: Codable {
                        let id: Int
                        let name: String
                        let summary: String?
                        let description: String?
                        let user: UserField?
                        let endorsements: Int?
                        let modCount: Int?
                        struct UserField: Codable { let name: String }
                    }
                    let collection: CollectionField
                }
                let collectionRevision: RevisionField
            }
            let data: DataField
        }

        let gql = try JSONDecoder().decode(GQLResponse.self, from: data)
        let c = gql.data.collectionRevision.collection
        return NexusCollectionInfo(
            id: c.id, slug: slug, name: c.name, summary: c.summary,
            author: c.user?.name, modCount: c.modCount,
            endorsements: c.endorsements, imageUrl: nil
        )
    }

    func collectionMods(slug: String) async throws -> [NexusCollectionMod] {
        guard let apiKey, !apiKey.isEmpty else { throw NexusAPIError.noAPIKey }

        let query = """
        query { collectionRevision(slug: "\(slug)", gameDomainName: "\(gameDomain)") { modFiles { mod { modId name } file { fileId } version optional } } }
        """
        let body: [String: Any] = ["query": query]
        let jsonData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: URL(string: "https://api.nexusmods.com/v2/graphql")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        let (data, response) = try await performRequest(request)
        try checkResponse(response)

        struct GQLResponse: Codable {
            struct DataField: Codable {
                struct RevisionField: Codable {
                    struct ModFileEntry: Codable {
                        struct ModRef: Codable { let modId: Int; let name: String }
                        struct FileRef: Codable { let fileId: Int? }
                        let mod: ModRef
                        let file: FileRef?
                        let version: String?
                        let optional: Bool?
                    }
                    let modFiles: [ModFileEntry]
                }
                let collectionRevision: RevisionField
            }
            let data: DataField
        }

        let gql = try JSONDecoder().decode(GQLResponse.self, from: data)
        return gql.data.collectionRevision.modFiles.map { entry in
            NexusCollectionMod(
                modId: entry.mod.modId,
                name: entry.mod.name,
                version: entry.version,
                fileId: entry.file?.fileId,
                optional: entry.optional
            )
        }
    }

    static func parseCollectionURL(_ urlString: String) -> String? {
        // https://next.nexusmods.com/stardewvalley/collections/{slug}
        guard let url = URL(string: urlString),
              url.host?.contains("nexusmods.com") == true,
              url.pathComponents.contains("collections"),
              let slugIndex = url.pathComponents.firstIndex(of: "collections"),
              slugIndex + 1 < url.pathComponents.count else {
            return nil
        }
        return url.pathComponents[slugIndex + 1]
    }

    // MARK: - Helpers

    private func fetchModList(path: String) async throws -> [NexusModInfo] {
        let request = try buildRequest(path: path)
        let (data, response) = try await performRequest(request)
        try checkResponse(response)
        return try JSONDecoder().decode([NexusModInfo].self, from: data)
    }

    private func buildRequest(path: String, apiKey key: String? = nil) throws -> URLRequest {
        let effectiveKey = key ?? apiKey
        guard let apiKey = effectiveKey, !apiKey.isEmpty else { throw NexusAPIError.noAPIKey }

        guard let url = URL(string: baseURL + path) else {
            throw NexusAPIError.networkError("Invalid URL: \(baseURL + path)")
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                updateRateLimits(from: httpResponse)
            }
            return (data, response)
        } catch {
            throw NexusAPIError.networkError(error.localizedDescription)
        }
    }

    private func checkResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        switch httpResponse.statusCode {
        case 200...299: return
        case 401: throw NexusAPIError.invalidAPIKey
        case 429: throw NexusAPIError.rateLimited
        default:
            throw NexusAPIError.networkError("Server returned status \(httpResponse.statusCode)")
        }
    }

    private func updateRateLimits(from response: HTTPURLResponse) {
        if let remaining = response.value(forHTTPHeaderField: "X-RL-Hourly-Remaining"),
           let value = Int(remaining) {
            hourlyRemaining = value
        }
        if let remaining = response.value(forHTTPHeaderField: "X-RL-Daily-Remaining"),
           let value = Int(remaining) {
            dailyRemaining = value
        }
    }
}
