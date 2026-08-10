import Foundation

enum ModManagementError: LocalizedError {
    case modNotFound
    case moveError(String)
    case deleteError(String)
    case importError(String)
    case invalidMod(String)

    var errorDescription: String? {
        switch self {
        case .modNotFound: return "Mod folder not found."
        case .moveError(let msg): return "Failed to move mod: \(msg)"
        case .deleteError(let msg): return "Failed to delete mod: \(msg)"
        case .importError(let msg): return "Failed to import mod: \(msg)"
        case .invalidMod(let msg): return "Invalid mod: \(msg)"
        }
    }
}

/// One nested mod that failed to import, so a multi-mod archive can report
/// partial success instead of discarding everything on the first failure.
struct ImportFailure {
    let name: String
    let reason: String
}

/// Result of importing (possibly several) mods: the ones that landed plus any
/// per-folder failures that were skipped so already-copied mods aren't lost.
struct ImportResult {
    let mods: [Mod]
    let failures: [ImportFailure]
}

enum ModManagementService {
    static func enableMod(_ mod: Mod, settings: AppSettings) throws {
        let fm = FileManager.default
        try ensureDirectoryExists(settings.modsDirectoryURL, fm: fm)
        try moveMod(mod, toBase: settings.modsDirectoryURL, fromBase: settings.disabledModsDirectoryURL, fm: fm)
        mod.isEnabled = true
    }

    static func disableMod(_ mod: Mod, settings: AppSettings) throws {
        let fm = FileManager.default
        try ensureDirectoryExists(settings.disabledModsDirectoryURL, fm: fm)
        try moveMod(mod, toBase: settings.disabledModsDirectoryURL, fromBase: settings.modsDirectoryURL, fm: fm)
        mod.isEnabled = false
    }

    /// Move a mod between the Mods and Disabled Mods directories, mirroring its
    /// relative subfolder path so the user's folder organization survives the round-trip.
    private static func moveMod(_ mod: Mod, toBase destinationBase: URL, fromBase sourceBase: URL, fm: FileManager) throws {
        let sourceParent = mod.folderURL.deletingLastPathComponent()

        var destParent = destinationBase
        if let subfolder = mod.subfolder, !subfolder.isEmpty {
            destParent = destinationBase.appending(path: subfolder)

            // Self-heal stale copies left flat at the base by older app versions:
            // a same-ID folder at the root is a leftover of this mod, not a different mod
            let legacyFlat = destinationBase.appending(path: mod.folderName)
            if fm.fileExists(atPath: legacyFlat.path(percentEncoded: false)),
               let occupant = ManifestParser.parse(at: legacyFlat.appending(path: "manifest.json")),
               occupant.uniqueID.caseInsensitiveCompare(mod.id) == .orderedSame {
                try? fm.removeItem(at: legacyFlat)
            }
        }
        try ensureDirectoryExists(destParent, fm: fm)

        let safe = try collisionSafeDestination(parent: destParent, folderName: mod.folderName, uniqueID: mod.id, fm: fm)
        let destination = safe.url
        do {
            try fm.moveItem(at: mod.folderURL, to: destination)
        } catch {
            // Put the displaced same-ID occupant back before surfacing the failure
            if let backup = safe.displacedBackup {
                try? fm.moveItem(at: backup, to: destination)
            }
            throw ModManagementError.moveError(error.localizedDescription)
        }
        preserveDisplacedConfig(backup: safe.displacedBackup, at: destination, fm: fm)
        mod.folderURL = destination
        mod.folderName = destination.lastPathComponent

        removeEmptyAncestors(of: sourceParent, upTo: sourceBase, fm: fm)
    }

    /// A destination path plus, when a stale same-ID occupant had to be moved aside,
    /// the recoverable trash-staging backup so its config.json can be carried forward.
    private struct SafeDestination {
        let url: URL
        let displacedBackup: URL?
    }

    /// Pick a destination that never silently deletes another mod: an occupant with the
    /// same uniqueID is a stale copy of this mod and is moved into recoverable trash
    /// staging (so its user config survives); anything else keeps its place and the move
    /// gets a numbered folder name instead.
    private static func collisionSafeDestination(parent: URL, folderName: String, uniqueID: String, fm: FileManager) throws -> SafeDestination {
        let candidate = parent.appending(path: folderName)
        guard fm.fileExists(atPath: candidate.path(percentEncoded: false)) else {
            return SafeDestination(url: candidate, displacedBackup: nil)
        }

        if let occupant = ManifestParser.parse(at: candidate.appending(path: "manifest.json")),
           occupant.uniqueID.caseInsensitiveCompare(uniqueID) == .orderedSame {
            // Stage the stale copy instead of destroying it, so a same-ID occupant's
            // config.json (and the folder itself) stays recoverable via the trash.
            try ensureDirectoryExists(trashStagingURL, fm: fm)
            let backup = trashStagingURL.appending(path: "\(UUID().uuidString)_\(candidate.lastPathComponent)")
            do {
                try fm.moveItem(at: candidate, to: backup)
            } catch {
                throw ModManagementError.moveError(error.localizedDescription)
            }
            return SafeDestination(url: candidate, displacedBackup: backup)
        }

        for n in 2...99 {
            let alternative = parent.appending(path: "\(folderName) \(n)")
            if !fm.fileExists(atPath: alternative.path(percentEncoded: false)) {
                return SafeDestination(url: alternative, displacedBackup: nil)
            }
        }
        throw ModManagementError.moveError("Too many name collisions for \(folderName)")
    }

    /// After an incoming folder is placed at `destination`, carry a displaced same-ID
    /// occupant's config.json forward when the new copy doesn't ship its own, then
    /// discard the backup. Mirrors importFromFolder's in-place replace behavior.
    private static func preserveDisplacedConfig(backup: URL?, at destination: URL, fm: FileManager) {
        guard let backup else { return }
        let oldConfig = backup.appending(path: "config.json")
        let newConfig = destination.appending(path: "config.json")
        if fm.fileExists(atPath: oldConfig.path(percentEncoded: false)),
           !fm.fileExists(atPath: newConfig.path(percentEncoded: false)) {
            try? fm.copyItem(at: oldConfig, to: newConfig)
        }
        try? fm.removeItem(at: backup)
    }

    /// Remove intermediate directories left empty after a move, walking up from
    /// `directory` to (but never including) `baseDir`. Uses rmdir(2), which fails on
    /// non-empty directories, so content added concurrently is never deleted.
    private static func removeEmptyAncestors(of directory: URL, upTo baseDir: URL, fm: FileManager) {
        // Normalize away trailing slashes so a base path like "…/Mods/" can never be
        // mistaken for a child of itself and rmdir'd out from under the app.
        func normalized(_ path: String) -> String {
            var p = path
            while p.count > 1 && p.hasSuffix("/") { p.removeLast() }
            return p
        }
        let basePath = normalized(baseDir.resolvingSymlinksInPath().path(percentEncoded: false))
        var current = directory.resolvingSymlinksInPath()

        while true {
            let currentPath = normalized(current.path(percentEncoded: false))
            // Stop at (and never operate on) the base directory itself.
            guard currentPath != basePath, currentPath.hasPrefix(basePath + "/") else { break }
            guard let contents = try? fm.contentsOfDirectory(atPath: current.path(percentEncoded: false)) else { break }
            guard contents.allSatisfy({ $0 == ".DS_Store" }) else { break }
            if contents.contains(".DS_Store") {
                try? fm.removeItem(at: current.appending(path: ".DS_Store"))
            }
            let removed = current.withUnsafeFileSystemRepresentation { ptr -> Bool in
                guard let ptr else { return false }
                return rmdir(ptr) == 0
            }
            guard removed else { break }
            current = current.deletingLastPathComponent()
        }
    }

    static func deleteMod(_ mod: Mod) throws {
        do {
            try FileManager.default.removeItem(at: mod.folderURL)
        } catch {
            throw ModManagementError.deleteError(error.localizedDescription)
        }
    }

    // MARK: - Trash Staging (for undo)

    static var trashStagingURL: URL {
        FileManager.default.temporaryDirectory.appending(path: "StardewModManager_trash")
    }

    static func trashMod(_ mod: Mod) throws -> URL {
        let fm = FileManager.default
        try ensureDirectoryExists(trashStagingURL, fm: fm)

        let destination = trashStagingURL.appending(path: "\(UUID().uuidString)_\(mod.folderName)")
        do {
            try fm.moveItem(at: mod.folderURL, to: destination)
            return destination
        } catch {
            throw ModManagementError.deleteError(error.localizedDescription)
        }
    }

    /// Restores a trashed mod folder, returning the URL it actually landed at
    /// (may differ from `destinationURL` if a different mod now occupies it).
    @discardableResult
    static func restoreFromTrash(stagingURL: URL, to destinationURL: URL) throws -> URL {
        let fm = FileManager.default
        let parentDir = destinationURL.deletingLastPathComponent()
        try ensureDirectoryExists(parentDir, fm: fm)

        let uniqueID = ManifestParser.parse(at: stagingURL.appending(path: "manifest.json"))?.uniqueID ?? ""
        let safe = try collisionSafeDestination(
            parent: parentDir,
            folderName: destinationURL.lastPathComponent,
            uniqueID: uniqueID,
            fm: fm
        )
        let destination = safe.url
        do {
            try fm.moveItem(at: stagingURL, to: destination)
        } catch {
            // Restore the displaced same-ID occupant before surfacing the failure
            if let backup = safe.displacedBackup {
                try? fm.moveItem(at: backup, to: destination)
            }
            throw ModManagementError.moveError(error.localizedDescription)
        }
        preserveDisplacedConfig(backup: safe.displacedBackup, at: destination, fm: fm)
        return destination
    }

    static func emptyTrash(stagingURLs: [URL]) {
        let fm = FileManager.default
        for url in stagingURLs {
            try? fm.removeItem(at: url)
        }
    }

    static func importMod(from sourceURL: URL, settings: AppSettings, existingMods: [Mod] = []) throws -> ImportResult {
        let fm = FileManager.default
        try ensureDirectoryExists(settings.modsDirectoryURL, fm: fm)

        if sourceURL.pathExtension.lowercased() == "zip" {
            return try importFromZip(sourceURL, settings: settings, existingMods: existingMods, fm: fm)
        } else {
            return try importFromFolder(sourceURL, settings: settings, existingMods: existingMods, fm: fm)
        }
    }

    private static func importFromFolder(_ folderURL: URL, settings: AppSettings, existingMods: [Mod], fm: FileManager) throws -> ImportResult {
        let manifestURL = folderURL.appending(path: "manifest.json")

        // If manifest.json exists at top level, import directly
        if fm.fileExists(atPath: manifestURL.path(percentEncoded: false)) {
            guard let manifest = ManifestParser.parse(at: manifestURL) else {
                throw ModManagementError.invalidMod("Could not parse manifest.json")
            }

            // Already installed — replace it in place, keeping its location, folder name,
            // subfolder, and enabled state (avoids creating a duplicate copy at the root).
            // Prefer the enabled instance when stale duplicates exist.
            let matches: (Mod) -> Bool = {
                !$0.isBuiltIn
                    && $0.id.caseInsensitiveCompare(manifest.uniqueID) == .orderedSame
                    && fm.fileExists(atPath: $0.folderURL.path(percentEncoded: false))
            }
            if let existing = existingMods.first(where: { matches($0) && $0.isEnabled })
                ?? existingMods.first(where: matches) {
                // Stage-and-swap so a failed copy can't destroy the installed mod
                try ensureDirectoryExists(trashStagingURL, fm: fm)
                let backup = trashStagingURL.appending(path: "\(UUID().uuidString)_\(existing.folderName)")
                do {
                    try fm.moveItem(at: existing.folderURL, to: backup)
                } catch {
                    throw ModManagementError.importError(error.localizedDescription)
                }
                do {
                    try fm.copyItem(at: folderURL, to: existing.folderURL)
                } catch {
                    try? fm.moveItem(at: backup, to: existing.folderURL)
                    throw ModManagementError.importError(error.localizedDescription)
                }

                // Keep the user's mod settings if the new copy doesn't ship its own
                let oldConfig = backup.appending(path: "config.json")
                let newConfig = existing.folderURL.appending(path: "config.json")
                if fm.fileExists(atPath: oldConfig.path(percentEncoded: false)),
                   !fm.fileExists(atPath: newConfig.path(percentEncoded: false)) {
                    try? fm.copyItem(at: oldConfig, to: newConfig)
                }
                try? fm.removeItem(at: backup)

                return ImportResult(mods: [Mod(
                    manifest: manifest,
                    folderName: existing.folderName,
                    folderURL: existing.folderURL,
                    isEnabled: existing.isEnabled,
                    subfolder: existing.subfolder
                )], failures: [])
            }

            let safe = try collisionSafeDestination(
                parent: settings.modsDirectoryURL,
                folderName: folderURL.lastPathComponent,
                uniqueID: manifest.uniqueID,
                fm: fm
            )
            let destination = safe.url

            do {
                try fm.copyItem(at: folderURL, to: destination)
            } catch {
                // Restore the displaced same-ID occupant before surfacing the failure
                if let backup = safe.displacedBackup {
                    try? fm.moveItem(at: backup, to: destination)
                }
                throw ModManagementError.importError(error.localizedDescription)
            }
            preserveDisplacedConfig(backup: safe.displacedBackup, at: destination, fm: fm)

            return ImportResult(mods: [Mod(manifest: manifest, folderName: destination.lastPathComponent, folderURL: destination, isEnabled: true)], failures: [])
        }

        // No top-level manifest — search for nested mod folders
        let nestedFolders = findModFolders(in: folderURL, fm: fm)
        guard !nestedFolders.isEmpty else {
            throw ModManagementError.invalidMod("No manifest.json found in \(folderURL.lastPathComponent)")
        }

        // Import each nested mod independently so one bad folder can't discard the
        // mods already copied; collect per-folder failures to surface to the user.
        var importedMods: [Mod] = []
        var failures: [ImportFailure] = []
        for nestedFolder in nestedFolders {
            do {
                let result = try importFromFolder(nestedFolder, settings: settings, existingMods: existingMods, fm: fm)
                importedMods.append(contentsOf: result.mods)
                failures.append(contentsOf: result.failures)
            } catch {
                let name = ManifestParser.parse(at: nestedFolder.appending(path: "manifest.json"))?.name
                    ?? nestedFolder.lastPathComponent
                failures.append(ImportFailure(name: name, reason: error.localizedDescription))
            }
        }
        return ImportResult(mods: importedMods, failures: failures)
    }

    private static func importFromZip(_ zipURL: URL, settings: AppSettings, existingMods: [Mod], fm: FileManager) throws -> ImportResult {
        let tempDir = fm.temporaryDirectory.appending(path: UUID().uuidString)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempDir) }

        // Extract using the validated extractor (zip-slip / symlink / zip-bomb guarded)
        do {
            try ArchiveService.extract(zipURL, to: tempDir)
        } catch {
            throw ModManagementError.importError(error.localizedDescription)
        }

        // Find all manifest.json files in the extracted contents
        let modFolders = findModFolders(in: tempDir, fm: fm)

        if modFolders.isEmpty {
            throw ModManagementError.invalidMod("No mods found in ZIP (no manifest.json files)")
        }

        // Continue past a failing nested mod so already-copied mods aren't lost;
        // aggregate the failures for the caller to surface.
        var importedMods: [Mod] = []
        var failures: [ImportFailure] = []
        for modFolder in modFolders {
            do {
                let result = try importFromFolder(modFolder, settings: settings, existingMods: existingMods, fm: fm)
                importedMods.append(contentsOf: result.mods)
                failures.append(contentsOf: result.failures)
            } catch {
                let name = ManifestParser.parse(at: modFolder.appending(path: "manifest.json"))?.name
                    ?? modFolder.lastPathComponent
                failures.append(ImportFailure(name: name, reason: error.localizedDescription))
            }
        }

        return ImportResult(mods: importedMods, failures: failures)
    }

    private static func findModFolders(in directory: URL, fm: FileManager) -> [URL] {
        var result: [URL] = []

        guard let enumerator = fm.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return result }

        var manifestParentDirs: Set<String> = []

        for case let fileURL as URL in enumerator {
            if fileURL.lastPathComponent == "manifest.json" {
                let parentDir = fileURL.deletingLastPathComponent()
                let parentPath = parentDir.path(percentEncoded: false)
                // Avoid adding nested mod folders that are children of already-found mods
                if !manifestParentDirs.contains(where: { parentPath.hasPrefix($0) && parentPath != $0 }) {
                    manifestParentDirs.insert(parentPath)
                    result.append(parentDir)
                }
            }
        }

        return result
    }

    /// Peek into a zip to extract mod names without installing
    static func peekModNames(from zipURL: URL) -> [String] {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appending(path: "peek_\(UUID().uuidString)")
        defer { try? fm.removeItem(at: tempDir) }

        do {
            try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
            try ArchiveService.extract(zipURL, to: tempDir)

            let modDirs = findModFolders(in: tempDir, fm: fm)
            return modDirs.compactMap { dir in
                let manifestURL = dir.appending(path: "manifest.json")
                guard let manifest = ManifestParser.parse(at: manifestURL) else { return nil }
                return manifest.name
            }
        } catch {
            return []
        }
    }

    private static func ensureDirectoryExists(_ url: URL, fm: FileManager) throws {
        if !fm.fileExists(atPath: url.path(percentEncoded: false)) {
            try fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}
