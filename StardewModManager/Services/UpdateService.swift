import Foundation

struct AppUpdate {
    let version: String
    let htmlURL: String
    let downloadURL: String?
}

enum UpdateService {
    private static let releasesURL = "https://api.github.com/repos/josuediazflores/StardewValleyMod/releases/latest"

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    static func checkForUpdate() async -> AppUpdate? {
        guard let url = URL(string: releasesURL) else { return nil }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("StardewModManager/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else { return nil }

        struct GitHubRelease: Codable {
            let tagName: String
            let htmlUrl: String
            let assets: [Asset]?

            struct Asset: Codable {
                let name: String
                let browserDownloadUrl: String

                enum CodingKeys: String, CodingKey {
                    case name
                    case browserDownloadUrl = "browser_download_url"
                }
            }

            enum CodingKeys: String, CodingKey {
                case tagName = "tag_name"
                case htmlUrl = "html_url"
                case assets
            }
        }

        guard let release = try? JSONDecoder().decode(GitHubRelease.self, from: data) else { return nil }

        let latestVersion = release.tagName.hasPrefix("v") ? String(release.tagName.dropFirst()) : release.tagName

        guard isNewer(latestVersion, than: currentVersion) else { return nil }

        let dmg = release.assets?.first(where: { $0.name.hasSuffix(".dmg") || $0.name.hasSuffix(".zip") || $0.name.hasSuffix(".app") })

        return AppUpdate(
            version: latestVersion,
            htmlURL: release.htmlUrl,
            downloadURL: dmg?.browserDownloadUrl
        )
    }

    private static func isNewer(_ latest: String, than current: String) -> Bool {
        let latestParts = latest.split(separator: ".").compactMap { Int($0) }
        let currentParts = current.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(latestParts.count, currentParts.count) {
            let l = i < latestParts.count ? latestParts[i] : 0
            let c = i < currentParts.count ? currentParts[i] : 0
            if l > c { return true }
            if l < c { return false }
        }
        return false
    }
}
