import Foundation
import XCTest
@testable import StardewModManager

/// SUITE 3 — import parsing and archive-traversal rejection
/// (Phase 1a, 1d, 2j).
final class ImportParsingTests: StardewTestCase {

    // MARK: - .smm formatVersion validation (Phase 2j)

    /// `ShareableModpack.fromJSON` rejects a formatVersion newer than this build
    /// supports, and accepts the supported version.
    func testShareableModpackRejectsNewerFormatVersion() throws {
        let supported = ShareableModpack.currentSupportedFormatVersion

        let future = ShareableModpack(
            formatVersion: supported + 1,
            name: "Future Pack",
            description: "made by a newer app",
            modCount: 0,
            createdAt: Date(),
            mods: []
        )
        let futureData = try future.toJSON()

        XCTAssertThrowsError(try ShareableModpack.fromJSON(futureData)) { error in
            guard case ShareableModpackError.unsupportedFormatVersion(let found, let sup) = error else {
                return XCTFail("expected unsupportedFormatVersion, got \(error)")
            }
            XCTAssertEqual(found, supported + 1)
            XCTAssertEqual(sup, supported)
        }
    }

    func testShareableModpackAcceptsSupportedFormatVersion() throws {
        let ok = ShareableModpack(
            formatVersion: ShareableModpack.currentSupportedFormatVersion,
            name: "Current Pack",
            description: "fine",
            modCount: 1,
            createdAt: Date(),
            mods: [.init(uniqueID: "a.b", name: "A B", version: "1.0.0", nexusModID: nil)]
        )
        let data = try ok.toJSON()

        let decoded = try ShareableModpack.fromJSON(data)
        XCTAssertEqual(decoded.formatVersion, ShareableModpack.currentSupportedFormatVersion)
        XCTAssertEqual(decoded.name, "Current Pack")
        XCTAssertEqual(decoded.mods.count, 1)
    }

    // MARK: - JSON import assigns a fresh id each time (Phase 2j)

    /// Importing the same modpack JSON twice must yield two Modpacks with DIFFERENT
    /// ids, so a repeated import can't create identity-colliding modpacks.
    func testImportFromJSONAssignsFreshIDEachTime() throws {
        let original = makeModpack(entries: [
            ModpackEntry(uniqueID: "mod.a", name: "Mod A", version: "1.0.0", nexusModID: nil, nexusFileID: nil, isEnabled: true),
        ])
        let fileURL = tempDir.appending(path: "pack.json")
        try ModpackService.exportAsJSON(original, to: fileURL)

        let first = try ModpackService.importFromJSON(at: fileURL)
        let second = try ModpackService.importFromJSON(at: fileURL)

        XCTAssertNotEqual(first.id, second.id, "each import must mint a fresh id")
        XCTAssertNotEqual(first.id, original.id)
        // Content still round-trips.
        XCTAssertEqual(first.name, original.name)
        XCTAssertEqual(first.entries.map(\.uniqueID), ["mod.a"])
    }

    // MARK: - bundleFolderName sanitization (Phase 1a)

    /// A modpack imported from JSON always has `bundleFolderName == nil`, no matter
    /// what the JSON claimed — only the app itself ever sets a real bundle name.
    func testImportFromJSONStripsBundleFolderName() throws {
        let claimed = makeModpack(
            entries: [],
            bundleFolderName: "sneaky-bundle"
        )
        let fileURL = tempDir.appending(path: "claimed.json")
        try ModpackService.exportAsJSON(claimed, to: fileURL)

        let imported = try ModpackService.importFromJSON(at: fileURL)
        XCTAssertNil(imported.bundleFolderName, "imported modpack must never carry a bundle folder name")
    }

    /// `deleteModpack` must refuse to remove a bundle path that escapes the modpacks
    /// directory. A sentinel file outside that directory must survive a delete whose
    /// persisted bundleFolderName is a "../escape" traversal.
    func testDeleteModpackRefusesPathOutsideModpacksDirectory() throws {
        // Sentinel sits OUTSIDE the modpacks dir, at <gamePath>/escape — exactly where
        // "../escape" resolves to from within the Modpacks directory.
        let sentinel = tempDir.appending(path: "escape")
        try Data("DO_NOT_DELETE".utf8).write(to: sentinel)

        let malicious = makeModpack(
            entries: [],
            includesFiles: true,
            bundleFolderName: "../escape"
        )
        // Persist it so deleteModpack can find and remove it from the saved list.
        try ModpackService.saveModpacks([malicious], settings: settings)

        try ModpackService.deleteModpack(malicious, settings: settings)

        // The out-of-bounds path was NOT deleted...
        XCTAssertTrue(exists(sentinel), "delete must not remove a path outside the modpacks directory")
        XCTAssertEqual(read(sentinel), "DO_NOT_DELETE")
        // ...but the modpack was still removed from the persisted list.
        XCTAssertTrue(ModpackService.loadModpacks(settings: settings).isEmpty)
    }

    // MARK: - ArchiveService traversal rejection (Phase 1d)

    /// A zip containing a symlink entry must be rejected by the validated extractor
    /// with .unsafeEntry (caught by the isSymbolicLink guard).
    func testArchiveExtractRejectsSymlinkEntry() throws {
        let fm = FileManager.default
        let srcDir = tempDir.appending(path: "evil-src")
        try fm.createDirectory(at: srcDir, withIntermediateDirectories: true)
        try Data("real".utf8).write(to: srcDir.appending(path: "real.txt"))
        // A symlink entry — categorically unsafe in an untrusted archive.
        try fm.createSymbolicLink(
            at: srcDir.appending(path: "link.txt"),
            withDestinationURL: srcDir.appending(path: "real.txt")
        )

        let zipURL = tempDir.appending(path: "evil.zip")
        // /usr/bin/zip --symlinks stores symlinks as symlinks (ditto would follow them).
        let status = try run("/usr/bin/zip", ["--symlinks", "-r", zipURL.path(percentEncoded: false), "."], cwd: srcDir)
        XCTAssertEqual(status, 0, "zip must succeed building the fixture")

        let extractDir = tempDir.appending(path: "evil-out")
        XCTAssertThrowsError(try ArchiveService.extract(zipURL, to: extractDir)) { error in
            guard case ArchiveError.unsafeEntry = error else {
                return XCTFail("expected ArchiveError.unsafeEntry, got \(error)")
            }
        }
    }

    /// A normal zip of a mod folder (no symlinks, no traversal) must extract
    /// successfully. Regression guard for the trailing-slash containment bug where
    /// `basePath` retained a trailing "/", making `baseWithSlash` end in "//" so every
    /// legitimate entry was rejected and all untrusted zip imports failed app-wide.
    func testArchiveExtractAcceptsNormalModZip() throws {
        let fm = FileManager.default
        let modFolder = tempDir.appending(path: "GoodMod")
        try fm.createDirectory(at: modFolder, withIntermediateDirectories: true)
        try writeManifest(in: modFolder, uniqueID: "good.mod", name: "Good Mod")

        let zipURL = tempDir.appending(path: "good.zip")
        // Mirror how the app compresses trusted data: ditto -c -k --keepParent.
        let status = try run("/usr/bin/ditto", [
            "-c", "-k", "--keepParent",
            modFolder.path(percentEncoded: false),
            zipURL.path(percentEncoded: false),
        ])
        XCTAssertEqual(status, 0, "ditto must succeed building the fixture")

        let extractDir = tempDir.appending(path: "good-out")
        // A valid archive with no symlinks or traversal must extract without throwing.
        XCTAssertNoThrow(
            try ArchiveService.extract(zipURL, to: extractDir),
            "ArchiveService.extract rejected a valid archive"
        )

        let extractedManifest = extractDir.appending(path: "GoodMod/manifest.json")
        XCTAssertTrue(exists(extractedManifest))
        XCTAssertEqual(parsedUniqueID(at: extractDir.appending(path: "GoodMod")), "good.mod")
    }
}
