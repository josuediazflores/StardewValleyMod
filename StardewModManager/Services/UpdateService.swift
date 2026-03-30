import Foundation
import AppKit

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

        let zip = release.assets?.first(where: { $0.name.hasSuffix(".zip") })

        return AppUpdate(
            version: latestVersion,
            htmlURL: release.htmlUrl,
            downloadURL: zip?.browserDownloadUrl
        )
    }

    /// Download the update zip, extract it, replace the current app, and relaunch
    static func downloadAndInstall(update: AppUpdate) async throws {
        guard let downloadURL = update.downloadURL, let url = URL(string: downloadURL) else {
            throw UpdateError.noDownloadURL
        }

        // Download the zip
        let (tempZipURL, response) = try await URLSession.shared.download(from: url)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw UpdateError.downloadFailed
        }

        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appending(path: "StardewModManagerUpdate-\(UUID().uuidString)")
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Extract the zip using ditto (preserves permissions and code signing)
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/ditto")
        process.arguments = ["-xk", tempZipURL.path(percentEncoded: false), tempDir.path(percentEncoded: false)]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw UpdateError.extractFailed
        }

        // Find the .app in the extracted directory
        let contents = try fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        guard let newAppURL = contents.first(where: { $0.pathExtension == "app" }) else {
            throw UpdateError.noAppFound
        }

        // Replace current app
        let currentAppPath = Bundle.main.bundleURL
        let backupPath = currentAppPath.deletingLastPathComponent().appending(path: "StardewModManager_backup.app")

        // Remove old backup if exists
        try? fm.removeItem(at: backupPath)

        // Move current app to backup
        try fm.moveItem(at: currentAppPath, to: backupPath)

        // Move new app into place
        try fm.moveItem(at: newAppURL, to: currentAppPath)

        // Clean up
        try? fm.removeItem(at: tempDir)
        try? fm.removeItem(at: tempZipURL)
        try? fm.removeItem(at: backupPath)

        // Relaunch
        let task = Process()
        task.executableURL = URL(filePath: "/usr/bin/open")
        task.arguments = ["-n", currentAppPath.path(percentEncoded: false)]
        try task.run()

        // Exit current instance
        DispatchQueue.main.async {
            NSApplication.shared.terminate(nil)
        }
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

    enum UpdateError: LocalizedError {
        case noDownloadURL
        case downloadFailed
        case extractFailed
        case noAppFound

        var errorDescription: String? {
            switch self {
            case .noDownloadURL: return "No download URL available for this update."
            case .downloadFailed: return "Failed to download the update."
            case .extractFailed: return "Failed to extract the update."
            case .noAppFound: return "Could not find the app in the downloaded update."
            }
        }
    }
}
