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
        }
        try ensureDirectoryExists(destParent, fm: fm)

        let destination = try collisionSafeDestination(parent: destParent, folderName: mod.folderName, uniqueID: mod.id, fm: fm)
        do {
            try fm.moveItem(at: mod.folderURL, to: destination)
        } catch {
            throw ModManagementError.moveError(error.localizedDescription)
        }
        mod.folderURL = destination
        mod.folderName = destination.lastPathComponent

        removeEmptyAncestors(of: sourceParent, upTo: sourceBase, fm: fm)
    }

    /// Pick a destination that never silently deletes another mod: an occupant with the
    /// same uniqueID is a stale copy of this mod and is replaced; anything else keeps its
    /// place and the move gets a numbered folder name instead.
    private static func collisionSafeDestination(parent: URL, folderName: String, uniqueID: String, fm: FileManager) throws -> URL {
        let candidate = parent.appending(path: folderName)
        guard fm.fileExists(atPath: candidate.path(percentEncoded: false)) else { return candidate }

        if let occupant = ManifestParser.parse(at: candidate.appending(path: "manifest.json")),
           occupant.uniqueID.caseInsensitiveCompare(uniqueID) == .orderedSame {
            do {
                try fm.removeItem(at: candidate)
            } catch {
                throw ModManagementError.moveError(error.localizedDescription)
            }
            return candidate
        }

        for n in 2...99 {
            let alternative = parent.appending(path: "\(folderName) \(n)")
            if !fm.fileExists(atPath: alternative.path(percentEncoded: false)) {
                return alternative
            }
        }
        throw ModManagementError.moveError("Too many name collisions for \(folderName)")
    }

    /// Remove intermediate directories left empty after a move, walking up from
    /// `directory` to (but never including) `baseDir`. Uses rmdir(2), which fails on
    /// non-empty directories, so content added concurrently is never deleted.
    private static func removeEmptyAncestors(of directory: URL, upTo baseDir: URL, fm: FileManager) {
        let basePath = baseDir.resolvingSymlinksInPath().path(percentEncoded: false)
        var current = directory.resolvingSymlinksInPath()

        while current.path(percentEncoded: false).hasPrefix(basePath + "/") {
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
        let destination = try collisionSafeDestination(
            parent: parentDir,
            folderName: destinationURL.lastPathComponent,
            uniqueID: uniqueID,
            fm: fm
        )
        do {
            try fm.moveItem(at: stagingURL, to: destination)
        } catch {
            throw ModManagementError.moveError(error.localizedDescription)
        }
        return destination
    }

    static func emptyTrash(stagingURLs: [URL]) {
        let fm = FileManager.default
        for url in stagingURLs {
            try? fm.removeItem(at: url)
        }
    }

    static func importMod(from sourceURL: URL, settings: AppSettings, existingMods: [Mod] = []) throws -> [Mod] {
        let fm = FileManager.default
        try ensureDirectoryExists(settings.modsDirectoryURL, fm: fm)

        if sourceURL.pathExtension.lowercased() == "zip" {
            return try importFromZip(sourceURL, settings: settings, existingMods: existingMods, fm: fm)
        } else {
            return try importFromFolder(sourceURL, settings: settings, existingMods: existingMods, fm: fm)
        }
    }

    private static func importFromFolder(_ folderURL: URL, settings: AppSettings, existingMods: [Mod], fm: FileManager) throws -> [Mod] {
        let manifestURL = folderURL.appending(path: "manifest.json")

        // If manifest.json exists at top level, import directly
        if fm.fileExists(atPath: manifestURL.path(percentEncoded: false)) {
            guard let manifest = ManifestParser.parse(at: manifestURL) else {
                throw ModManagementError.invalidMod("Could not parse manifest.json")
            }

            // Already installed — replace it in place, keeping its location, folder name,
            // subfolder, and enabled state (avoids creating a duplicate copy at the root)
            if let existing = existingMods.first(where: {
                !$0.isBuiltIn
                    && $0.id.caseInsensitiveCompare(manifest.uniqueID) == .orderedSame
                    && fm.fileExists(atPath: $0.folderURL.path(percentEncoded: false))
            }) {
                do {
                    try fm.removeItem(at: existing.folderURL)
                    try fm.copyItem(at: folderURL, to: existing.folderURL)
                } catch {
                    throw ModManagementError.importError(error.localizedDescription)
                }
                return [Mod(
                    manifest: manifest,
                    folderName: existing.folderName,
                    folderURL: existing.folderURL,
                    isEnabled: existing.isEnabled,
                    subfolder: existing.subfolder
                )]
            }

            let destination = try collisionSafeDestination(
                parent: settings.modsDirectoryURL,
                folderName: folderURL.lastPathComponent,
                uniqueID: manifest.uniqueID,
                fm: fm
            )

            do {
                try fm.copyItem(at: folderURL, to: destination)
            } catch {
                throw ModManagementError.importError(error.localizedDescription)
            }

            return [Mod(manifest: manifest, folderName: destination.lastPathComponent, folderURL: destination, isEnabled: true)]
        }

        // No top-level manifest — search for nested mod folders
        let nestedFolders = findModFolders(in: folderURL, fm: fm)
        guard !nestedFolders.isEmpty else {
            throw ModManagementError.invalidMod("No manifest.json found in \(folderURL.lastPathComponent)")
        }

        var importedMods: [Mod] = []
        for nestedFolder in nestedFolders {
            let imported = try importFromFolder(nestedFolder, settings: settings, existingMods: existingMods, fm: fm)
            importedMods.append(contentsOf: imported)
        }
        return importedMods
    }

    private static func importFromZip(_ zipURL: URL, settings: AppSettings, existingMods: [Mod], fm: FileManager) throws -> [Mod] {
        let tempDir = fm.temporaryDirectory.appending(path: UUID().uuidString)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempDir) }

        // Extract using ditto
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/ditto")
        process.arguments = ["-xk", zipURL.path(percentEncoded: false), tempDir.path(percentEncoded: false)]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ModManagementError.importError("Failed to extract ZIP file")
        }

        // Find all manifest.json files in the extracted contents
        let modFolders = findModFolders(in: tempDir, fm: fm)

        if modFolders.isEmpty {
            throw ModManagementError.invalidMod("No mods found in ZIP (no manifest.json files)")
        }

        var importedMods: [Mod] = []
        for modFolder in modFolders {
            let imported = try importFromFolder(modFolder, settings: settings, existingMods: existingMods, fm: fm)
            importedMods.append(contentsOf: imported)
        }

        return importedMods
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
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-xk", zipURL.path(percentEncoded: false), tempDir.path(percentEncoded: false)]
            try process.run()
            process.waitUntilExit()

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
