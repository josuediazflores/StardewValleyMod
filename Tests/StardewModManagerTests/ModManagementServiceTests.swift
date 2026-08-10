import Foundation
import XCTest
@testable import StardewModManager

/// SUITE 1 — the destructive filesystem paths in `ModManagementService`
/// (the Phase 2 data-loss fixes). Everything runs inside a per-test temp dir.
final class ModManagementServiceTests: StardewTestCase {

    // MARK: - enable/disable round-trip (subfolder mirroring + nested content)

    /// A mod that lives under a subfolder, with nested content inside its own
    /// folder, survives a disabled -> enabled -> disabled round-trip: the manifest
    /// and nested files are intact, the relative subfolder is mirrored across the
    /// Mods / Mods_Disabled boundary, and empty ancestor folders are cleaned up.
    func testEnableDisableRoundTripPreservesManifestAndNestedContent() throws {
        let mod = try installMod(
            baseDir: disabledDir,
            folderName: "CoolMod",
            uniqueID: "cool.mod",
            name: "Cool Mod",
            isEnabled: false,
            subfolder: "Gameplay",
            extraFiles: ["assets/data.json": "NESTED"]
        )

        // Enable: Mods_Disabled/Gameplay/CoolMod -> Mods/Gameplay/CoolMod
        try ModManagementService.enableMod(mod, settings: settings)

        let enabledFolder = modsDir.appending(path: "Gameplay/CoolMod")
        XCTAssertTrue(mod.isEnabled)
        XCTAssertEqual(mod.folderURL.path(percentEncoded: false), enabledFolder.path(percentEncoded: false))
        XCTAssertEqual(mod.subfolder, "Gameplay")
        XCTAssertEqual(parsedUniqueID(at: enabledFolder), "cool.mod")
        XCTAssertEqual(read(enabledFolder.appending(path: "assets/data.json")), "NESTED")
        // Source subfolder was emptied and swept, but the base dir remains.
        XCTAssertFalse(exists(disabledDir.appending(path: "Gameplay")))
        XCTAssertTrue(exists(disabledDir))

        // Disable again: back to Mods_Disabled/Gameplay/CoolMod
        try ModManagementService.disableMod(mod, settings: settings)

        let disabledFolder = disabledDir.appending(path: "Gameplay/CoolMod")
        XCTAssertFalse(mod.isEnabled)
        XCTAssertEqual(mod.folderURL.path(percentEncoded: false), disabledFolder.path(percentEncoded: false))
        XCTAssertEqual(parsedUniqueID(at: disabledFolder), "cool.mod")
        XCTAssertEqual(read(disabledFolder.appending(path: "assets/data.json")), "NESTED")
        XCTAssertFalse(exists(modsDir.appending(path: "Gameplay")))
        XCTAssertTrue(exists(modsDir))
    }

    // MARK: - collisionSafeDestination: SAME uniqueID (Phase 2b)

    /// Enabling a mod into a slot already occupied by a folder with the SAME
    /// uniqueID must not destroy the occupant's user config. The occupant is moved
    /// aside to recoverable trash staging (never overwritten in place) and its
    /// config.json is carried forward onto the moved-in copy.
    func testEnableOntoSameIDOccupantPreservesConfig() throws {
        // Incoming copy in Mods_Disabled — ships NO config of its own, but has a
        // marker file so we can prove the moved-in folder is the incoming one.
        let incoming = try installMod(
            baseDir: disabledDir,
            folderName: "CoolMod",
            uniqueID: "cool.mod",
            isEnabled: false,
            extraFiles: ["incoming-marker.txt": "INCOMING"]
        )
        // Occupant already sitting in Mods with the SAME uniqueID and a user config.
        try installMod(
            baseDir: modsDir,
            folderName: "CoolMod",
            uniqueID: "cool.mod",
            isEnabled: true,
            extraFiles: ["config.json": "OCCUPANT_CONFIG"]
        )

        try ModManagementService.enableMod(incoming, settings: settings)

        let dest = modsDir.appending(path: "CoolMod")
        XCTAssertTrue(exists(dest))
        // The incoming copy landed here (its marker survived the move)...
        XCTAssertEqual(read(dest.appending(path: "incoming-marker.txt")), "INCOMING")
        // ...and the occupant's config was preserved onto it rather than destroyed.
        // This is the data-loss guard: a naive overwrite would have lost this file.
        XCTAssertEqual(read(dest.appending(path: "config.json")), "OCCUPANT_CONFIG")
        XCTAssertEqual(parsedUniqueID(at: dest), "cool.mod")
        XCTAssertFalse(exists(disabledDir.appending(path: "CoolMod")))
        XCTAssertTrue(incoming.isEnabled)
        // Note on "recoverable": the occupant is moved to trash staging (not hard
        // deleted) so its config survives; preserveDisplacedConfig then carries that
        // config forward and clears the staging copy, so the surviving config.json
        // above is the observable proof the occupant was not destructively removed.
    }

    // MARK: - collisionSafeDestination: DIFFERENT uniqueID (Phase 2b)

    /// Enabling a mod into a slot occupied by a DIFFERENT mod (different uniqueID)
    /// must never touch the occupant — the incoming copy gets a numbered
    /// "Name 2" folder instead.
    func testEnableOntoDifferentIDOccupantUsesNumberedFolder() throws {
        let incoming = try installMod(
            baseDir: disabledDir,
            folderName: "Shared",
            uniqueID: "incoming.mod",
            isEnabled: false,
            extraFiles: ["incoming-marker.txt": "INCOMING"]
        )
        try installMod(
            baseDir: modsDir,
            folderName: "Shared",
            uniqueID: "occupant.mod",
            isEnabled: true,
            extraFiles: ["occupant-marker.txt": "OCCUPANT"]
        )

        try ModManagementService.enableMod(incoming, settings: settings)

        // Occupant untouched.
        let occupantFolder = modsDir.appending(path: "Shared")
        XCTAssertTrue(exists(occupantFolder))
        XCTAssertEqual(parsedUniqueID(at: occupantFolder), "occupant.mod")
        XCTAssertEqual(read(occupantFolder.appending(path: "occupant-marker.txt")), "OCCUPANT")

        // Incoming placed in a numbered sibling.
        let numbered = modsDir.appending(path: "Shared 2")
        XCTAssertTrue(exists(numbered))
        XCTAssertEqual(parsedUniqueID(at: numbered), "incoming.mod")
        XCTAssertEqual(read(numbered.appending(path: "incoming-marker.txt")), "INCOMING")

        XCTAssertFalse(exists(disabledDir.appending(path: "Shared")))
        XCTAssertEqual(incoming.folderName, "Shared 2")
        XCTAssertEqual(incoming.folderURL.path(percentEncoded: false), numbered.path(percentEncoded: false))
        XCTAssertTrue(incoming.isEnabled)
    }

    // MARK: - removeEmptyAncestors base-dir guard (Phase 2d)

    /// Disabling (and re-enabling) the only root-level mod must never rmdir the
    /// base Mods / Mods_Disabled directories, even though they become empty.
    func testDisablingOnlyRootModDoesNotRemoveBaseDirectories() throws {
        let mod = try installMod(
            baseDir: modsDir,
            folderName: "OnlyMod",
            uniqueID: "only.mod",
            isEnabled: true
        )

        try ModManagementService.disableMod(mod, settings: settings)
        // Mods became empty but must still exist; the mod is now in Mods_Disabled.
        XCTAssertTrue(exists(modsDir), "base Mods directory must not be rmdir'd")
        XCTAssertTrue(exists(disabledDir))
        XCTAssertTrue(exists(disabledDir.appending(path: "OnlyMod")))
        XCTAssertFalse(exists(modsDir.appending(path: "OnlyMod")))

        try ModManagementService.enableMod(mod, settings: settings)
        // Mods_Disabled became empty but must still exist.
        XCTAssertTrue(exists(disabledDir), "base Mods_Disabled directory must not be rmdir'd")
        XCTAssertTrue(exists(modsDir))
        XCTAssertTrue(exists(modsDir.appending(path: "OnlyMod")))
        XCTAssertFalse(exists(disabledDir.appending(path: "OnlyMod")))
    }

    // MARK: - delete/trash a single instance (Phase 2c)

    /// Trashing one folder of a mod that has two on-disk copies sharing a uniqueID
    /// (one enabled, one disabled) removes only that folder and leaves the sibling
    /// on disk. The trashed folder is recoverable in trash staging.
    func testTrashingOneInstanceLeavesSiblingOnDisk() throws {
        let enabledCopy = try installMod(
            baseDir: modsDir,
            folderName: "Dup",
            uniqueID: "dup.mod",
            isEnabled: true
        )
        try installMod(
            baseDir: disabledDir,
            folderName: "Dup",
            uniqueID: "dup.mod",
            isEnabled: false
        )

        let staged = try ModManagementService.trashMod(enabledCopy)

        // Trashed folder gone from its original location...
        XCTAssertFalse(exists(modsDir.appending(path: "Dup")))
        // ...the other same-ID copy is untouched...
        XCTAssertTrue(exists(disabledDir.appending(path: "Dup")))
        XCTAssertEqual(parsedUniqueID(at: disabledDir.appending(path: "Dup")), "dup.mod")
        // ...and the trashed copy is recoverable in staging (not hard-deleted).
        XCTAssertTrue(exists(staged))
        XCTAssertEqual(parsedUniqueID(at: staged), "dup.mod")
    }

    /// The same single-instance guarantee for a hard delete: removing one folder
    /// leaves the sibling copy on disk.
    func testDeletingOneInstanceLeavesSiblingOnDisk() throws {
        let disabledCopy = try installMod(
            baseDir: disabledDir,
            folderName: "Dup",
            uniqueID: "dup.mod",
            isEnabled: false
        )
        try installMod(
            baseDir: modsDir,
            folderName: "Dup",
            uniqueID: "dup.mod",
            isEnabled: true
        )

        try ModManagementService.deleteMod(disabledCopy)

        XCTAssertFalse(exists(disabledDir.appending(path: "Dup")))
        XCTAssertTrue(exists(modsDir.appending(path: "Dup")))
    }
}
