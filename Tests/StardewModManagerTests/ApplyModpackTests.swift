import Foundation
import XCTest
@testable import StardewModManager

/// SUITE 2 — `ModpackService.applyModpack` matching matrix (Phase 2f, 2g).
/// Mods are real on-disk folders so enable/disable perform genuine moves; the
/// assertions cover which mods end enabled / disabled / reported missing.
final class ApplyModpackTests: StardewTestCase {

    // MARK: - Basic matrix: enable listed, disable unlisted, report missing

    func testApplyEnablesDisablesAndReportsMissing() throws {
        let modA = try installMod(baseDir: modsDir, folderName: "A", uniqueID: "mod.a", name: "Mod A", isEnabled: true)
        let modB = try installMod(baseDir: modsDir, folderName: "B", uniqueID: "mod.b", name: "Mod B", isEnabled: true)
        let modC = try installMod(baseDir: disabledDir, folderName: "C", uniqueID: "mod.c", name: "Mod C", isEnabled: false)

        // Profile wants A + C enabled and lists an uninstalled D. B is not in the profile.
        let modpack = makeModpack(entries: [
            ModpackEntry(uniqueID: "mod.a", name: "Mod A", version: "1.0.0", nexusModID: nil, nexusFileID: nil, isEnabled: true),
            ModpackEntry(uniqueID: "mod.c", name: "Mod C", version: "1.0.0", nexusModID: nil, nexusFileID: nil, isEnabled: true),
            ModpackEntry(uniqueID: "mod.d", name: "Mod D", version: "1.0.0", nexusModID: nil, nexusFileID: nil, isEnabled: true),
        ])

        let result = try ModpackService.applyModpack(modpack, mods: [modA, modB, modC], settings: settings)

        // A already correct, C enabled, B disabled (not in profile), D missing.
        XCTAssertTrue(modA.isEnabled)
        XCTAssertTrue(modC.isEnabled)
        XCTAssertFalse(modB.isEnabled)

        XCTAssertTrue(exists(modsDir.appending(path: "A")))
        XCTAssertTrue(exists(modsDir.appending(path: "C")))
        XCTAssertTrue(exists(disabledDir.appending(path: "B")))

        XCTAssertEqual(result.enabled, ["Mod C"])
        XCTAssertEqual(result.disabled, ["Mod B"])
        XCTAssertEqual(result.missing.map(\.uniqueID), ["mod.d"])
        XCTAssertEqual(result.alreadyCorrect, 1)
        XCTAssertTrue(result.failures.isEmpty)
    }

    // MARK: - Case-insensitive uniqueID matching (Phase 2f)

    /// An entry whose uniqueID differs only in case from an installed mod still
    /// matches: the mod ends enabled, and is never reported missing or disabled.
    func testCaseInsensitiveUniqueIDMatches() throws {
        let mod = try installMod(
            baseDir: disabledDir,
            folderName: "ContentPatcher",
            uniqueID: "Pathoschild.ContentPatcher",
            name: "Content Patcher",
            isEnabled: false
        )

        let modpack = makeModpack(entries: [
            // Lower-cased id, differs only in case from the installed mod.
            ModpackEntry(uniqueID: "pathoschild.contentpatcher", name: "Content Patcher", version: "1.0.0", nexusModID: nil, nexusFileID: nil, isEnabled: true),
        ])

        let result = try ModpackService.applyModpack(modpack, mods: [mod], settings: settings)

        XCTAssertTrue(mod.isEnabled)
        XCTAssertTrue(exists(modsDir.appending(path: "ContentPatcher")))
        XCTAssertEqual(result.enabled, ["Content Patcher"])
        XCTAssertTrue(result.missing.isEmpty)
        XCTAssertTrue(result.disabled.isEmpty)
        XCTAssertTrue(result.failures.isEmpty)
    }

    // MARK: - Nexus-collection membership by nexusModID (Phase 2g)

    /// Regression guard for the "disable everything" collection bug: a profile of
    /// synthetic `nexus:<id>` entries must resolve installed mods by their real
    /// nexusModID. A matching installed mod stays ENABLED (is in the profile) while
    /// an unrelated installed mod is correctly disabled.
    func testNexusCollectionMembershipKeepsMatchingModEnabled() throws {
        // Installed mod carries a real Nexus update key -> nexusModID 3753.
        let sve = try installMod(
            baseDir: modsDir,
            folderName: "SVE",
            uniqueID: "FlashShifter.StardewValleyExpandedCP",
            name: "Stardew Valley Expanded",
            isEnabled: true,
            updateKeys: ["Nexus:3753"]
        )
        XCTAssertEqual(sve.nexusModID, 3753, "precondition: nexusModID parsed from update key")
        // Unrelated installed mod, not part of the collection.
        let other = try installMod(
            baseDir: modsDir,
            folderName: "Other",
            uniqueID: "some.other.mod",
            name: "Other Mod",
            isEnabled: true
        )

        // Collection entry has a synthetic id but the real nexusModID.
        let modpack = makeModpack(
            entries: [
                ModpackEntry(uniqueID: "nexus:3753", name: "Stardew Valley Expanded", version: nil, nexusModID: 3753, nexusFileID: nil, isEnabled: true),
            ],
            source: .nexusCollection(collectionId: 42)
        )

        let result = try ModpackService.applyModpack(modpack, mods: [sve, other], settings: settings)

        // The installed mod matching by nexusModID must NOT be disabled.
        XCTAssertTrue(sve.isEnabled, "mod matching the collection by nexusModID must stay enabled")
        XCTAssertTrue(exists(modsDir.appending(path: "SVE")))
        XCTAssertFalse(result.disabled.contains("Stardew Valley Expanded"))
        XCTAssertFalse(result.missing.contains(where: { $0.nexusModID == 3753 }))

        // The unrelated mod is correctly disabled (not in the profile).
        XCTAssertFalse(other.isEnabled)
        XCTAssertTrue(exists(disabledDir.appending(path: "Other")))
        XCTAssertEqual(result.disabled, ["Other Mod"])
        XCTAssertTrue(result.failures.isEmpty)
    }

    // MARK: - Duplicate on-disk instances group correctly

    /// Two on-disk copies sharing a uniqueID (one enabled, one disabled) are grouped
    /// as a single mod: applying a profile that enables it keeps the enabled copy
    /// enabled and leaves the disabled copy alone — no crash, sensible result.
    func testDuplicateInstancesGroupWithoutCrashing() throws {
        let enabledCopy = try installMod(baseDir: modsDir, folderName: "Dup", uniqueID: "dup.mod", name: "Dup Mod", isEnabled: true)
        let disabledCopy = try installMod(baseDir: disabledDir, folderName: "Dup", uniqueID: "dup.mod", name: "Dup Mod", isEnabled: false)

        let modpack = makeModpack(entries: [
            ModpackEntry(uniqueID: "dup.mod", name: "Dup Mod", version: "1.0.0", nexusModID: nil, nexusFileID: nil, isEnabled: true),
        ])

        let result = try ModpackService.applyModpack(modpack, mods: [enabledCopy, disabledCopy], settings: settings)

        // The already-enabled instance stays enabled; the disabled copy is untouched.
        XCTAssertTrue(enabledCopy.isEnabled)
        XCTAssertFalse(disabledCopy.isEnabled)
        XCTAssertTrue(exists(modsDir.appending(path: "Dup")))
        XCTAssertTrue(exists(disabledDir.appending(path: "Dup")))
        XCTAssertGreaterThanOrEqual(result.alreadyCorrect, 1)
        XCTAssertTrue(result.missing.isEmpty)
        XCTAssertTrue(result.failures.isEmpty)
    }
}
