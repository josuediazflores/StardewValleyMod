import Foundation

enum SMAPIInstallService {
    private static let releasesURL = "https://api.github.com/repos/Pathoschild/SMAPI/releases/latest"

    struct Release {
        let version: String
        let downloadURL: URL
    }

    static func fetchLatestRelease() async throws -> Release {
        guard let url = URL(string: releasesURL) else { throw SMAPIInstallError.fetchFailed }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("StardewModManager", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw SMAPIInstallError.fetchFailed
        }

        struct GitHubRelease: Decodable {
            let tagName: String
            let assets: [Asset]?

            struct Asset: Decodable {
                let name: String
                let browserDownloadUrl: String

                enum CodingKeys: String, CodingKey {
                    case name
                    case browserDownloadUrl = "browser_download_url"
                }
            }

            enum CodingKeys: String, CodingKey {
                case tagName = "tag_name"
                case assets
            }
        }

        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        let version = release.tagName.hasPrefix("v") ? String(release.tagName.dropFirst()) : release.tagName

        guard let asset = release.assets?.first(where: { $0.name.hasSuffix(".zip") }),
              let downloadURL = URL(string: asset.browserDownloadUrl) else {
            throw SMAPIInstallError.noDownloadURL
        }

        return Release(version: version, downloadURL: downloadURL)
    }

    static func downloadAndInstall(to gamePath: String) async throws {
        let release = try await fetchLatestRelease()
        let fm = FileManager.default

        // Download the installer zip
        let (tempZipURL, response) = try await URLSession.shared.download(from: release.downloadURL)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw SMAPIInstallError.downloadFailed
        }

        let tempDir = fm.temporaryDirectory.appending(path: "SMAPIInstall-\(UUID().uuidString)")
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? fm.removeItem(at: tempDir)
            try? fm.removeItem(at: tempZipURL)
        }

        // Extract with ditto (preserves executable permissions)
        let extract = Process()
        extract.executableURL = URL(filePath: "/usr/bin/ditto")
        extract.arguments = ["-xk", tempZipURL.path(percentEncoded: false), tempDir.path(percentEncoded: false)]
        try extract.run()
        extract.waitUntilExit()

        guard extract.terminationStatus == 0 else {
            throw SMAPIInstallError.extractFailed
        }

        // Find internal/macOS directory in the extracted contents
        guard let macOSDir = findInternalMacOSDir(in: tempDir) else {
            throw SMAPIInstallError.installFilesNotFound
        }

        // Copy SMAPI files into game directory using ditto (merges without deleting existing files)
        let copy = Process()
        copy.executableURL = URL(filePath: "/usr/bin/ditto")
        copy.arguments = [macOSDir.path(percentEncoded: false), gamePath]
        try copy.run()
        copy.waitUntilExit()

        guard copy.terminationStatus == 0 else {
            throw SMAPIInstallError.copyFailed
        }

        // Verify SMAPI executable is in place
        let smapiPath = URL(filePath: gamePath).appending(path: "StardewModdingAPI").path(percentEncoded: false)
        guard fm.isExecutableFile(atPath: smapiPath) else {
            throw SMAPIInstallError.verificationFailed
        }
    }

    /// Recursively search for the `internal/macOS` directory in the extracted SMAPI installer
    private static func findInternalMacOSDir(in baseDir: URL) -> URL? {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: baseDir, includingPropertiesForKeys: [.isDirectoryKey],
                                              options: [.skipsHiddenFiles]) else { return nil }

        for case let url as URL in enumerator {
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDir && url.lastPathComponent == "macOS" && url.deletingLastPathComponent().lastPathComponent == "internal" {
                return url
            }
        }
        return nil
    }

    enum SMAPIInstallError: LocalizedError {
        case fetchFailed
        case noDownloadURL
        case downloadFailed
        case extractFailed
        case installFilesNotFound
        case copyFailed
        case verificationFailed

        var errorDescription: String? {
            switch self {
            case .fetchFailed: return "Could not fetch SMAPI release info from GitHub."
            case .noDownloadURL: return "No download URL found in the latest SMAPI release."
            case .downloadFailed: return "Failed to download the SMAPI installer."
            case .extractFailed: return "Failed to extract the SMAPI installer."
            case .installFilesNotFound: return "Could not find SMAPI install files in the downloaded archive."
            case .copyFailed: return "Failed to copy SMAPI files to the game directory."
            case .verificationFailed: return "SMAPI was not found after installation — files may not have copied correctly."
            }
        }
    }
}
