import Foundation
import AppKit
import Security

struct AppUpdate {
    let version: String
    let htmlURL: String
    let downloadURL: String?
}

enum UpdateService {
    private static let releasesURL = "https://api.github.com/repos/josuediazflores/StardewValleyMod/releases/latest"

    /// The exact asset name the release pipeline (build-app.sh) uploads. The updater
    /// matches this by name so a stray extra .zip on a release can't be installed by mistake.
    private static let expectedAssetName = "Stardew Mod Manager.zip"

    /// Gate for hard signature enforcement.
    ///
    /// Flip to `true` only AFTER the first Developer ID-signed + notarized release has
    /// shipped. Past/current releases are ad-hoc signed, so enforcing a Developer ID
    /// signature now would reject every ad-hoc self-update and brick in-app updating.
    private static let requireDeveloperIDSignature = false

    /// The Developer ID Team ID to pin the signature to when `requireDeveloperIDSignature`
    /// is on. Fill this in with the user's Team ID (the 10-character code in the
    /// "Developer ID Application: Name (TEAMID)" identity). While empty, the Team ID pin is
    /// skipped even in strict mode (a valid Apple-anchored signature is still required).
    private static let developerIDTeamID = ""

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    /// Check GitHub for a newer release.
    ///
    /// - Returns `nil` when the current version is already up to date.
    /// - Returns an `AppUpdate` when a newer version is available.
    /// - Throws when the check itself fails (network, HTTP, or decode), so a failed
    ///   check is distinguishable from "no update available".
    static func checkForUpdate() async throws -> AppUpdate? {
        guard let url = URL(string: releasesURL) else {
            throw UpdateError.checkFailed
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("StardewModManager/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw UpdateError.checkFailed
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UpdateError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw UpdateError.serverError(httpResponse.statusCode)
        }

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

        let release: GitHubRelease
        do {
            release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        } catch {
            throw UpdateError.invalidResponse
        }

        let latestVersion = release.tagName.hasPrefix("v") ? String(release.tagName.dropFirst()) : release.tagName

        guard isNewer(latestVersion, than: currentVersion) else { return nil }

        // Match the release asset by its exact expected name; only fall back to the first
        // .zip if the pipeline's asset isn't present (and log so the mismatch is visible).
        let assets = release.assets ?? []
        let zip: GitHubRelease.Asset?
        if let exact = assets.first(where: { $0.name == expectedAssetName }) {
            zip = exact
        } else if let fallback = assets.first(where: { $0.name.hasSuffix(".zip") }) {
            NSLog("[UpdateService] No asset named \"\(expectedAssetName)\" on release \(latestVersion); falling back to first .zip asset \"\(fallback.name)\".")
            zip = fallback
        } else {
            zip = nil
        }

        return AppUpdate(
            version: latestVersion,
            htmlURL: release.htmlUrl,
            downloadURL: zip?.browserDownloadUrl
        )
    }

    /// Download the update zip, extract it, replace the current app, and relaunch.
    ///
    /// The swap is transactional: the running app is only removed after the new bundle has
    /// been validated and moved into place, and the backup is only deleted after the new
    /// app is confirmed installed and relaunched. Any failure rolls back to the original app.
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

        // Always clean up the download scratch space, regardless of how we exit. The new
        // app bundle is moved out of tempDir before this runs, so this only removes leftovers.
        defer {
            try? fm.removeItem(at: tempDir)
            try? fm.removeItem(at: tempZipURL)
        }

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

        // Pre-swap validation: make sure the new bundle is well-formed and is the version
        // we expect BEFORE we touch the installed app. Throws if anything is off.
        try validateBundle(at: newAppURL, expectedVersion: update.version)

        // Pre-swap signature verification (gated by requireDeveloperIDSignature).
        try verifyCodeSignature(at: newAppURL)

        // Transactional replace.
        let currentAppPath = Bundle.main.bundleURL
        let backupPath = currentAppPath.deletingLastPathComponent().appending(path: "StardewModManager_backup.app")
        let currentPathString = currentAppPath.path(percentEncoded: false)
        let backupPathString = backupPath.path(percentEncoded: false)

        // Remove any stale backup from a previous run.
        try? fm.removeItem(at: backupPath)

        // Step 1: move the running app aside to the backup location.
        do {
            try fm.moveItem(at: currentAppPath, to: backupPath)
        } catch {
            throw UpdateError.installFailed(
                reason: "Couldn't move the current app aside (\(error.localizedDescription)).",
                backupPath: nil
            )
        }

        // Step 2: move the new app into place. If this fails, roll the backup back.
        do {
            try fm.moveItem(at: newAppURL, to: currentAppPath)
        } catch {
            try? fm.moveItem(at: backupPath, to: currentAppPath)
            if fm.fileExists(atPath: currentPathString) {
                throw UpdateError.installFailed(
                    reason: "Couldn't install the new version (\(error.localizedDescription)). Your existing app was restored.",
                    backupPath: nil
                )
            } else {
                // Rollback also failed — surface the backup location so the user can recover.
                throw UpdateError.installFailed(
                    reason: "Couldn't install the new version and automatic rollback failed.",
                    backupPath: backupPathString
                )
            }
        }

        // Step 3: confirm the replacement is actually in place before removing the backup.
        do {
            try validateBundle(at: currentAppPath, expectedVersion: update.version)
        } catch {
            try? fm.removeItem(at: currentAppPath)
            try? fm.moveItem(at: backupPath, to: currentAppPath)
            if fm.fileExists(atPath: currentPathString) {
                throw UpdateError.installFailed(
                    reason: "The installed update failed validation and was rolled back.",
                    backupPath: nil
                )
            } else {
                throw UpdateError.installFailed(
                    reason: "The installed update failed validation and automatic rollback failed.",
                    backupPath: backupPathString
                )
            }
        }

        // Relaunch the freshly installed app. Only once it launches do we delete the backup.
        guard relaunch(at: currentAppPath) else {
            // The new app is validated and in place, but it didn't relaunch. Keep the backup
            // for safety and leave this instance running so the user isn't left without an app.
            throw UpdateError.relaunchFailed(backupPath: backupPathString)
        }

        // Replacement confirmed and relaunch accepted — now it's safe to remove the backup.
        try? fm.removeItem(at: backupPath)

        // Exit current instance
        DispatchQueue.main.async {
            NSApplication.shared.terminate(nil)
        }
    }

    // MARK: - Validation helpers

    /// Verify the extracted bundle is a well-formed app of the expected version before we
    /// replace the installed copy. Throws `invalidBundle` / `versionMismatch` otherwise.
    private static func validateBundle(at appURL: URL, expectedVersion: String) throws {
        let fm = FileManager.default
        let infoPlistURL = appURL.appending(path: "Contents/Info.plist")

        guard let data = try? Data(contentsOf: infoPlistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            throw UpdateError.invalidBundle
        }

        // The executable named by CFBundleExecutable must actually exist as a file.
        guard let exeName = plist["CFBundleExecutable"] as? String, !exeName.isEmpty else {
            throw UpdateError.invalidBundle
        }
        let exeURL = appURL.appending(path: "Contents/MacOS/\(exeName)")
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: exeURL.path(percentEncoded: false), isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            throw UpdateError.invalidBundle
        }

        // The bundle version must match the update we intended to install.
        let bundleVersion = plist["CFBundleShortVersionString"] as? String
        guard bundleVersion == expectedVersion else {
            throw UpdateError.versionMismatch(expected: expectedVersion, found: bundleVersion ?? "unknown")
        }
    }

    /// Verify the downloaded bundle's code signature.
    ///
    /// - When `requireDeveloperIDSignature` is off (default): best-effort tamper check only.
    ///   A present-but-invalid signature is rejected; ad-hoc or unsigned bundles are allowed
    ///   (with a log note) so ad-hoc self-updates keep working before the first signed release.
    /// - When on: require a valid signature anchored to Apple, optionally pinned to the
    ///   Developer ID Team ID (skipped, with a log note, while `developerIDTeamID` is empty).
    private static func verifyCodeSignature(at bundleURL: URL) throws {
        var staticCode: SecStaticCode?
        let createStatus = SecStaticCodeCreateWithPath(bundleURL as CFURL, [], &staticCode)
        guard createStatus == errSecSuccess, let code = staticCode else {
            throw UpdateError.signatureInvalid("Couldn't read the update's code signature (status \(createStatus)).")
        }

        if requireDeveloperIDSignature {
            var requirementString = "anchor apple generic"
            if developerIDTeamID.isEmpty {
                NSLog("[UpdateService] requireDeveloperIDSignature is on but developerIDTeamID is empty — skipping the Team ID pin; only requiring an Apple-anchored signature.")
            } else {
                requirementString += " and certificate leaf[subject.OU] = \"\(developerIDTeamID)\""
            }

            var requirement: SecRequirement?
            let reqStatus = SecRequirementCreateWithString(requirementString as CFString, [], &requirement)
            guard reqStatus == errSecSuccess, let requirement else {
                throw UpdateError.signatureInvalid("Couldn't build the signature requirement (status \(reqStatus)).")
            }

            let checkStatus = SecStaticCodeCheckValidity(code, [], requirement)
            guard checkStatus == errSecSuccess else {
                throw UpdateError.signatureInvalid("The update is not signed by the expected Developer ID (status \(checkStatus)).")
            }
        } else {
            // Best-effort: reject only positive tamper evidence.
            let checkStatus = SecStaticCodeCheckValidity(code, [], nil)
            switch checkStatus {
            case errSecSuccess:
                // Signature present and internally valid (ad-hoc or Developer ID). Allow.
                NSLog("[UpdateService] Update signature passed the best-effort validity check.")
            case errSecCSUnsigned:
                // No signature at all. Allowed while requireDeveloperIDSignature is off.
                NSLog("[UpdateService] Update bundle is unsigned; allowing because requireDeveloperIDSignature is off.")
            default:
                throw UpdateError.signatureInvalid("The update's code signature failed validation (status \(checkStatus)); refusing to install a possibly tampered build.")
            }
        }
    }

    /// Launch the installed app in a new instance. Returns whether `open` accepted the launch.
    private static func relaunch(at appURL: URL) -> Bool {
        let task = Process()
        task.executableURL = URL(filePath: "/usr/bin/open")
        task.arguments = ["-n", appURL.path(percentEncoded: false)]
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
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
        case checkFailed
        case serverError(Int)
        case invalidResponse
        case invalidBundle
        case versionMismatch(expected: String, found: String)
        case signatureInvalid(String)
        case installFailed(reason: String, backupPath: String?)
        case relaunchFailed(backupPath: String)

        var errorDescription: String? {
            switch self {
            case .noDownloadURL: return "No download URL available for this update."
            case .downloadFailed: return "Failed to download the update."
            case .extractFailed: return "Failed to extract the update."
            case .noAppFound: return "Could not find the app in the downloaded update."
            case .checkFailed: return "Couldn't reach the update server. Check your internet connection and try again."
            case .serverError(let code): return "The update server returned an error (HTTP \(code))."
            case .invalidResponse: return "The update server sent an unexpected response."
            case .invalidBundle: return "The downloaded update is missing its application executable."
            case .versionMismatch(let expected, let found):
                return "The downloaded update is version \(found) but \(expected) was expected. Aborting to stay safe."
            case .signatureInvalid(let detail): return detail
            case .installFailed(let reason, let backupPath):
                if let backupPath { return "\(reason) A backup of your app is at \(backupPath)." }
                return reason
            case .relaunchFailed(let backupPath):
                return "The update was installed but the app couldn't be relaunched automatically. Please quit and reopen it. A backup is at \(backupPath) if it's needed."
            }
        }
    }
}
