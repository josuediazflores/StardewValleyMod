import Foundation
import XCTest
@testable import StardewModManager

/// Base class for hermetic, filesystem-touching tests.
///
/// Every test gets its own unique temp directory that stands in for the user's
/// Stardew game folder, with `Mods` and `Mods_Disabled` pre-created. An
/// `AppSettings` is pointed at it via `gamePath`, so the services under test only
/// ever operate inside the temp tree — never the real user's install.
///
/// The shared trash-staging directory (`ModManagementService.trashStagingURL`,
/// which lives under the process temp dir, not the game folder) is wiped in both
/// `setUp` and `tearDown` so recoverable-delete assertions are deterministic.
class StardewTestCase: XCTestCase {
    var tempDir: URL!
    var settings: AppSettings!

    var modsDir: URL { settings.modsDirectoryURL }
    var disabledDir: URL { settings.disabledModsDirectoryURL }
    var modpacksDir: URL { settings.modpacksDirectoryURL }

    override func setUpWithError() throws {
        try super.setUpWithError()
        let fm = FileManager.default
        tempDir = fm.temporaryDirectory
            .appending(path: "SMMTests_\(UUID().uuidString)")
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

        settings = AppSettings()
        settings.gamePath = tempDir.path(percentEncoded: false)

        try fm.createDirectory(at: modsDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: disabledDir, withIntermediateDirectories: true)

        try? fm.removeItem(at: ModManagementService.trashStagingURL)
    }

    override func tearDownWithError() throws {
        let fm = FileManager.default
        if let tempDir { try? fm.removeItem(at: tempDir) }
        try? fm.removeItem(at: ModManagementService.trashStagingURL)
        try super.tearDownWithError()
    }

    // MARK: - Filesystem helpers

    func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }

    func read(_ url: URL) -> String? {
        (try? Data(contentsOf: url)).flatMap { String(data: $0, encoding: .utf8) }
    }

    func parsedUniqueID(at folderURL: URL) -> String? {
        ManifestParser.parse(at: folderURL.appending(path: "manifest.json"))?.uniqueID
    }

    /// Writes a SMAPI-style `manifest.json` (PascalCase keys) into `folderURL`.
    func writeManifest(
        in folderURL: URL,
        uniqueID: String,
        name: String,
        version: String = "1.0.0",
        updateKeys: [String]? = nil,
        entryDll: String? = nil
    ) throws {
        var dict: [String: Any] = [
            "Name": name,
            "Author": "Test Author",
            "Version": version,
            "UniqueID": uniqueID,
        ]
        if let updateKeys { dict["UpdateKeys"] = updateKeys }
        if let entryDll { dict["EntryDll"] = entryDll }
        let data = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted])
        try data.write(to: folderURL.appending(path: "manifest.json"))
    }

    /// Creates a mod folder on disk under `baseDir` (optionally nested under
    /// `subfolder`) with a manifest and any extra files, and returns a `Mod`
    /// pointed at it. `isEnabled` should reflect which base dir was used.
    @discardableResult
    func installMod(
        baseDir: URL,
        folderName: String,
        uniqueID: String,
        name: String? = nil,
        version: String = "1.0.0",
        isEnabled: Bool,
        subfolder: String? = nil,
        updateKeys: [String]? = nil,
        extraFiles: [String: String] = [:]
    ) throws -> Mod {
        let fm = FileManager.default
        let parent = subfolder.map { baseDir.appending(path: $0) } ?? baseDir
        let folderURL = parent.appending(path: folderName)
        try fm.createDirectory(at: folderURL, withIntermediateDirectories: true)
        try writeManifest(
            in: folderURL,
            uniqueID: uniqueID,
            name: name ?? folderName,
            version: version,
            updateKeys: updateKeys
        )
        for (relative, contents) in extraFiles {
            let fileURL = folderURL.appending(path: relative)
            try fm.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(contents.utf8).write(to: fileURL)
        }
        guard let manifest = ManifestParser.parse(at: folderURL.appending(path: "manifest.json")) else {
            throw TestSupportError.manifestParseFailed(folderURL.lastPathComponent)
        }
        return Mod(
            manifest: manifest,
            folderName: folderName,
            folderURL: folderURL,
            isEnabled: isEnabled,
            subfolder: subfolder
        )
    }

    func makeModpack(
        name: String = "Test Pack",
        entries: [ModpackEntry],
        source: ModpackSource = .manual,
        includesFiles: Bool = false,
        bundleFolderName: String? = nil
    ) -> Modpack {
        let now = Date()
        return Modpack(
            id: UUID(),
            name: name,
            description: "A test modpack",
            entries: entries,
            source: source,
            includesFiles: includesFiles,
            bundleFolderName: bundleFolderName,
            createdAt: now,
            updatedAt: now
        )
    }

    /// Runs an external process synchronously, failing the test on non-zero exit.
    @discardableResult
    func run(_ launchPath: String, _ arguments: [String], cwd: URL? = nil) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(filePath: launchPath)
        process.arguments = arguments
        if let cwd { process.currentDirectoryURL = cwd }
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }
}

enum TestSupportError: Error {
    case manifestParseFailed(String)
}
