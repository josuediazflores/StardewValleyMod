import Foundation

enum ModpackError: LocalizedError {
    case saveFailed(String)
    case loadFailed(String)
    case modpackNotFound
    case exportFailed(String)
    case importFailed(String)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let msg): return "Failed to save modpack: \(msg)"
        case .loadFailed(let msg): return "Failed to load modpacks: \(msg)"
        case .modpackNotFound: return "Modpack not found."
        case .exportFailed(let msg): return "Failed to export modpack: \(msg)"
        case .importFailed(let msg): return "Failed to import modpack: \(msg)"
        }
    }
}

enum ModpackService {
    private static let modpacksFileName = "modpacks.json"

    // MARK: - Persistence

    static func loadModpacks(settings: AppSettings) -> [Modpack] {
        let fm = FileManager.default
        let fileURL = settings.modpacksDirectoryURL.appending(path: modpacksFileName)

        guard fm.fileExists(atPath: fileURL.path(percentEncoded: false)) else {
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([Modpack].self, from: data)
        } catch {
            return []
        }
    }

    static func saveModpacks(_ modpacks: [Modpack], settings: AppSettings) throws {
        let fm = FileManager.default
        let dirURL = settings.modpacksDirectoryURL

        if !fm.fileExists(atPath: dirURL.path(percentEncoded: false)) {
            do {
                try fm.createDirectory(at: dirURL, withIntermediateDirectories: true)
            } catch {
                throw ModpackError.saveFailed(error.localizedDescription)
            }
        }

        let fileURL = dirURL.appending(path: modpacksFileName)

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(modpacks)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw ModpackError.saveFailed(error.localizedDescription)
        }
    }

    // MARK: - Create

    static func createModpack(name: String, description: String, from mods: [Mod]) -> Modpack {
        let entries = mods.filter { !$0.isBuiltIn }.map { mod in
            ModpackEntry(
                uniqueID: mod.id,
                name: mod.manifest.name,
                version: mod.manifest.version,
                nexusModID: mod.nexusModID,
                nexusFileID: nil,
                isEnabled: mod.isEnabled
            )
        }

        let now = Date()
        return Modpack(
            id: UUID(),
            name: name,
            description: description,
            entries: entries,
            source: .manual,
            includesFiles: false,
            bundleFolderName: nil,
            createdAt: now,
            updatedAt: now
        )
    }

    // MARK: - Apply

    static func applyModpack(_ modpack: Modpack, mods: [Mod], settings: AppSettings) throws -> ApplyResult {
        var enabledNames: [String] = []
        var disabledNames: [String] = []
        var missingEntries: [ModpackEntry] = []
        var alreadyCorrect = 0

        let modsByID = Dictionary(mods.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let entryIDs = Set(modpack.entries.map(\.uniqueID))

        // Process each entry in the modpack
        for entry in modpack.entries {
            guard let mod = modsByID[entry.uniqueID] else {
                missingEntries.append(entry)
                continue
            }

            if mod.isBuiltIn {
                alreadyCorrect += 1
                continue
            }

            if entry.isEnabled && !mod.isEnabled {
                try ModManagementService.enableMod(mod, settings: settings)
                enabledNames.append(mod.manifest.name)
            } else if !entry.isEnabled && mod.isEnabled {
                try ModManagementService.disableMod(mod, settings: settings)
                disabledNames.append(mod.manifest.name)
            } else {
                alreadyCorrect += 1
            }
        }

        // Disable mods not in the modpack (they're not part of this profile)
        for mod in mods where !mod.isBuiltIn && !entryIDs.contains(mod.id) && mod.isEnabled {
            try ModManagementService.disableMod(mod, settings: settings)
            disabledNames.append(mod.manifest.name)
        }

        return ApplyResult(
            enabled: enabledNames,
            disabled: disabledNames,
            missing: missingEntries,
            alreadyCorrect: alreadyCorrect
        )
    }

    // MARK: - Delete

    static func deleteModpack(_ modpack: Modpack, settings: AppSettings) throws {
        var modpacks = loadModpacks(settings: settings)

        guard let index = modpacks.firstIndex(where: { $0.id == modpack.id }) else {
            throw ModpackError.modpackNotFound
        }

        // Remove bundled files if present
        if let bundleName = modpack.bundleFolderName {
            let bundleURL = settings.modpacksDirectoryURL.appending(path: bundleName)
            if FileManager.default.fileExists(atPath: bundleURL.path(percentEncoded: false)) {
                try? FileManager.default.removeItem(at: bundleURL)
            }
        }

        modpacks.remove(at: index)
        try saveModpacks(modpacks, settings: settings)
    }

    // MARK: - Export

    static func exportAsJSON(_ modpack: Modpack, to url: URL) throws {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(modpack)
            try data.write(to: url, options: .atomic)
        } catch {
            throw ModpackError.exportFailed(error.localizedDescription)
        }
    }

    static func exportAsZIP(_ modpack: Modpack, mods: [Mod], settings: AppSettings, to url: URL) throws {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? fm.removeItem(at: tempDir) }

        do {
            try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        } catch {
            throw ModpackError.exportFailed("Failed to create temp directory: \(error.localizedDescription)")
        }

        let modsByID = Dictionary(mods.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        // Write the modpack manifest
        let manifestEncoder = JSONEncoder()
        manifestEncoder.dateEncodingStrategy = .iso8601
        manifestEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let manifestData = try manifestEncoder.encode(modpack)
        try manifestData.write(to: tempDir.appending(path: "modpack.json"), options: .atomic)

        // Copy enabled mod folders into the staging directory
        let modsStaging = tempDir.appending(path: "Mods")
        try fm.createDirectory(at: modsStaging, withIntermediateDirectories: true)

        for entry in modpack.entries where entry.isEnabled {
            guard let mod = modsByID[entry.uniqueID] else { continue }
            let destination = modsStaging.appending(path: mod.folderName)
            try fm.copyItem(at: mod.folderURL, to: destination)
        }

        // Remove existing file at destination if present
        if fm.fileExists(atPath: url.path(percentEncoded: false)) {
            try fm.removeItem(at: url)
        }

        // Create ZIP using ditto
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--keepParent",
                             tempDir.path(percentEncoded: false),
                             url.path(percentEncoded: false)]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ModpackError.exportFailed("ditto returned exit code \(process.terminationStatus)")
        }
    }

    // MARK: - Import

    static func importFromJSON(at url: URL) throws -> Modpack {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            var modpack = try decoder.decode(Modpack.self, from: data)
            modpack.source = .imported(fileName: url.lastPathComponent)
            return modpack
        } catch let error as ModpackError {
            throw error
        } catch {
            throw ModpackError.importFailed(error.localizedDescription)
        }
    }

    static func importFromZIP(at url: URL, settings: AppSettings) throws -> (Modpack, [Mod]) {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? fm.removeItem(at: tempDir) }

        do {
            try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        } catch {
            throw ModpackError.importFailed("Failed to create temp directory: \(error.localizedDescription)")
        }

        // Extract ZIP using ditto
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/ditto")
        process.arguments = ["-xk", url.path(percentEncoded: false), tempDir.path(percentEncoded: false)]
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw ModpackError.importFailed("Failed to extract ZIP: \(error.localizedDescription)")
        }

        guard process.terminationStatus == 0 else {
            throw ModpackError.importFailed("ditto returned exit code \(process.terminationStatus)")
        }

        // Look for modpack.json in extracted contents (may be nested inside a folder from --keepParent)
        let modpackManifestURL = findFile(named: "modpack.json", in: tempDir, fm: fm)

        var modpack: Modpack
        if let manifestURL = modpackManifestURL {
            let data = try Data(contentsOf: manifestURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            modpack = try decoder.decode(Modpack.self, from: data)
        } else {
            // No modpack.json — create one from discovered mods
            let now = Date()
            let baseName = url.deletingPathExtension().lastPathComponent
            modpack = Modpack(
                id: UUID(),
                name: baseName,
                description: "Imported from \(url.lastPathComponent)",
                entries: [],
                source: .imported(fileName: url.lastPathComponent),
                includesFiles: true,
                bundleFolderName: nil,
                createdAt: now,
                updatedAt: now
            )
        }

        // Find and import mod folders
        let modsDir = findDirectory(named: "Mods", in: tempDir, fm: fm) ?? tempDir
        var importedMods: [Mod] = []

        let modFolders = findModFolders(in: modsDir, fm: fm)
        for modFolder in modFolders {
            do {
                let imported = try ModManagementService.importMod(from: modFolder, settings: settings)
                importedMods.append(contentsOf: imported)
            } catch {
                // Skip individual mods that fail to import
                continue
            }
        }

        // Build entries from imported mods if modpack.json was absent
        if modpackManifestURL == nil {
            modpack.entries = importedMods.map { mod in
                ModpackEntry(
                    uniqueID: mod.id,
                    name: mod.manifest.name,
                    version: mod.manifest.version,
                    nexusModID: mod.nexusModID,
                    nexusFileID: nil,
                    isEnabled: true
                )
            }
        }

        modpack.source = .imported(fileName: url.lastPathComponent)
        modpack.includesFiles = true

        return (modpack, importedMods)
    }

    // MARK: - Helpers

    private static func findFile(named name: String, in directory: URL, fm: FileManager) -> URL? {
        guard let enumerator = fm.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        for case let fileURL as URL in enumerator {
            if fileURL.lastPathComponent == name {
                return fileURL
            }
        }
        return nil
    }

    private static func findDirectory(named name: String, in directory: URL, fm: FileManager) -> URL? {
        guard let enumerator = fm.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        for case let dirURL as URL in enumerator {
            if dirURL.lastPathComponent == name,
               (try? dirURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                return dirURL
            }
        }
        return nil
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
                if !manifestParentDirs.contains(where: { parentPath.hasPrefix($0) && parentPath != $0 }) {
                    manifestParentDirs.insert(parentPath)
                    result.append(parentDir)
                }
            }
        }

        return result
    }
}
