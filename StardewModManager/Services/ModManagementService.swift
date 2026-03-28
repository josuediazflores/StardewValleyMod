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

        let destination = settings.modsDirectoryURL.appending(path: mod.folderName)
        // Remove existing copy at destination to prevent move failure
        if fm.fileExists(atPath: destination.path(percentEncoded: false)) {
            try? fm.removeItem(at: destination)
        }
        do {
            try fm.moveItem(at: mod.folderURL, to: destination)
            mod.folderURL = destination
            mod.isEnabled = true
        } catch {
            throw ModManagementError.moveError(error.localizedDescription)
        }
    }

    static func disableMod(_ mod: Mod, settings: AppSettings) throws {
        let fm = FileManager.default
        try ensureDirectoryExists(settings.disabledModsDirectoryURL, fm: fm)

        let destination = settings.disabledModsDirectoryURL.appending(path: mod.folderName)
        // Remove existing copy at destination to prevent move failure
        if fm.fileExists(atPath: destination.path(percentEncoded: false)) {
            try? fm.removeItem(at: destination)
        }
        do {
            try fm.moveItem(at: mod.folderURL, to: destination)
            mod.folderURL = destination
            mod.isEnabled = false
        } catch {
            throw ModManagementError.moveError(error.localizedDescription)
        }
    }

    static func deleteMod(_ mod: Mod) throws {
        do {
            try FileManager.default.removeItem(at: mod.folderURL)
        } catch {
            throw ModManagementError.deleteError(error.localizedDescription)
        }
    }

    static func importMod(from sourceURL: URL, settings: AppSettings) throws -> [Mod] {
        let fm = FileManager.default
        try ensureDirectoryExists(settings.modsDirectoryURL, fm: fm)

        if sourceURL.pathExtension.lowercased() == "zip" {
            return try importFromZip(sourceURL, settings: settings, fm: fm)
        } else {
            return try importFromFolder(sourceURL, settings: settings, fm: fm)
        }
    }

    private static func importFromFolder(_ folderURL: URL, settings: AppSettings, fm: FileManager) throws -> [Mod] {
        let manifestURL = folderURL.appending(path: "manifest.json")
        guard fm.fileExists(atPath: manifestURL.path(percentEncoded: false)) else {
            throw ModManagementError.invalidMod("No manifest.json found in \(folderURL.lastPathComponent)")
        }

        let destination = settings.modsDirectoryURL.appending(path: folderURL.lastPathComponent)
        if fm.fileExists(atPath: destination.path(percentEncoded: false)) {
            try fm.removeItem(at: destination)
        }

        do {
            try fm.copyItem(at: folderURL, to: destination)
        } catch {
            throw ModManagementError.importError(error.localizedDescription)
        }

        guard let manifest = ManifestParser.parse(at: destination.appending(path: "manifest.json")) else {
            throw ModManagementError.invalidMod("Could not parse manifest.json")
        }

        return [Mod(manifest: manifest, folderName: destination.lastPathComponent, folderURL: destination, isEnabled: true)]
    }

    private static func importFromZip(_ zipURL: URL, settings: AppSettings, fm: FileManager) throws -> [Mod] {
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
            let imported = try importFromFolder(modFolder, settings: settings, fm: fm)
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
