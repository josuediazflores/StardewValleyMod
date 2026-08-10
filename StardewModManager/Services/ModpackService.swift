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
            // Preserve corrupted file so the user can recover manually
            let backupURL = fileURL.deletingLastPathComponent().appendingPathComponent("modpacks.json.corrupt")
            try? FileManager.default.copyItem(at: fileURL, to: backupURL)
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
            ModpackEntry(mod: mod, isEnabled: mod.isEnabled)
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
        var failures: [ApplyFailure] = []
        var alreadyCorrect = 0

        // Duplicate folders for the same mod can exist on disk (e.g. one enabled copy
        // and one disabled copy), so track every instance per uniqueID. Keys are
        // lowercased because SMAPI treats uniqueIDs case-insensitively.
        let userMods = mods.filter { !$0.isBuiltIn }
        let modsByID = Dictionary(grouping: userMods, by: { $0.id.lowercased() })
        // Collection entries carry no SMAPI id (only a Nexus mod id), so also index by
        // nexusModID to resolve them to already-installed mods.
        let modsByNexusID = Dictionary(grouping: userMods.filter { $0.nexusModID != nil }, by: { $0.nexusModID! })

        let entryIDs = Set(modpack.entries.map { $0.uniqueID.lowercased() })
        let entryNexusIDs = Set(modpack.entries.compactMap { $0.nexusModID })

        // An installed mod belongs to this profile if its uniqueID matches an entry
        // (case-insensitive) OR its Nexus mod id matches an entry's — so collection
        // mods the user already has are never treated as "not in the profile".
        func isInProfile(_ mod: Mod) -> Bool {
            if entryIDs.contains(mod.id.lowercased()) { return true }
            if let nexusID = mod.nexusModID, entryNexusIDs.contains(nexusID) { return true }
            return false
        }

        // Resolve an entry to its installed instances, falling back to nexusModID when
        // the (normalized) uniqueID matches nothing installed.
        func instances(for entry: ModpackEntry) -> [Mod] {
            if let byID = modsByID[entry.uniqueID.lowercased()], !byID.isEmpty {
                return byID
            }
            if let nexusID = entry.nexusModID, let byNexus = modsByNexusID[nexusID], !byNexus.isEmpty {
                return byNexus
            }
            return []
        }

        func disable(_ mod: Mod) {
            do {
                try ModManagementService.disableMod(mod, settings: settings)
                disabledNames.append(mod.manifest.name)
            } catch {
                failures.append(ApplyFailure(name: mod.manifest.name, reason: error.localizedDescription))
            }
        }

        // Process each entry in the modpack
        for entry in modpack.entries {
            let matched = instances(for: entry)
            guard !matched.isEmpty else {
                if mods.contains(where: { $0.isBuiltIn && $0.id.caseInsensitiveCompare(entry.uniqueID) == .orderedSame }) {
                    alreadyCorrect += 1
                } else if entry.isEnabled {
                    // A profile listing an uninstalled mod as disabled is vacuously satisfied
                    missingEntries.append(entry)
                }
                continue
            }

            if entry.isEnabled {
                // Keep exactly one instance enabled; extra enabled copies get disabled
                if let enabledInstance = matched.first(where: \.isEnabled) {
                    alreadyCorrect += 1
                    for extra in matched where extra !== enabledInstance && extra.isEnabled {
                        disable(extra)
                    }
                } else {
                    // Several disabled copies can exist — enable the newest one
                    let candidate = matched.max(by: {
                        $0.manifest.version.compare($1.manifest.version, options: .numeric) == .orderedAscending
                    }) ?? matched[0]
                    do {
                        try ModManagementService.enableMod(candidate, settings: settings)
                        enabledNames.append(candidate.manifest.name)
                    } catch {
                        failures.append(ApplyFailure(name: candidate.manifest.name, reason: error.localizedDescription))
                    }
                }
            } else {
                if matched.contains(where: \.isEnabled) {
                    for instance in matched where instance.isEnabled {
                        disable(instance)
                    }
                } else {
                    alreadyCorrect += 1
                }
            }
        }

        // Disable mods not in the modpack (they're not part of this profile)
        for mod in userMods where !isInProfile(mod) && mod.isEnabled {
            disable(mod)
        }

        return ApplyResult(
            enabled: enabledNames,
            disabled: disabledNames,
            missing: missingEntries,
            failures: failures,
            alreadyCorrect: alreadyCorrect
        )
    }

    // MARK: - Delete

    static func deleteModpack(_ modpack: Modpack, settings: AppSettings) throws {
        var modpacks = loadModpacks(settings: settings)

        guard let index = modpacks.firstIndex(where: { $0.id == modpack.id }) else {
            throw ModpackError.modpackNotFound
        }

        // Remove bundled files if present, but only when the resolved path stays
        // strictly inside the modpacks directory. A persisted bundleFolderName is
        // untrusted and could otherwise point removeItem at an arbitrary location.
        // A rejected path just skips the file removal; the modpack is still removed.
        if let bundleName = modpack.bundleFolderName {
            let baseURL = settings.modpacksDirectoryURL.standardizedFileURL.resolvingSymlinksInPath()
            let bundleURL = settings.modpacksDirectoryURL.appending(path: bundleName)
                .standardizedFileURL.resolvingSymlinksInPath()
            let basePath = baseURL.path(percentEncoded: false)
            let bundlePath = bundleURL.path(percentEncoded: false)
            if bundlePath.hasPrefix(basePath + "/"),
               bundlePath != basePath,
               FileManager.default.fileExists(atPath: bundlePath) {
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

        // Duplicate on-disk copies of one mod can exist — export the enabled one
        let modsByID = Dictionary(grouping: mods, by: \.id)
            .mapValues { instances in instances.first(where: \.isEnabled) ?? instances[0] }

        // Copy enabled mod folders into the staging directory
        let modsStaging = tempDir.appending(path: "Mods")
        try fm.createDirectory(at: modsStaging, withIntermediateDirectories: true)

        // Track which entries have matching installed mods
        let exportedEntries = modpack.entries.filter { entry in
            guard entry.isEnabled else { return true } // keep disabled entries as-is
            return modsByID[entry.uniqueID] != nil
        }

        for entry in modpack.entries where entry.isEnabled {
            guard let mod = modsByID[entry.uniqueID] else { continue }
            // Mirror the subfolder so two mods sharing a folder name can't collide
            let relative = mod.subfolder.map { "\($0)/\(mod.folderName)" } ?? mod.folderName
            let destination = modsStaging.appending(path: relative)
            try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.copyItem(at: mod.folderURL, to: destination)
        }

        // Write the modpack manifest with only entries that have matching mods
        var exportModpack = modpack
        exportModpack.entries = exportedEntries
        let manifestEncoder = JSONEncoder()
        manifestEncoder.dateEncodingStrategy = .iso8601
        manifestEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let manifestData = try manifestEncoder.encode(exportModpack)
        try manifestData.write(to: tempDir.appending(path: "modpack.json"), options: .atomic)

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

    /// ZIP a subset of mods into a temp file for Bluetooth transfer
    static func zipMods(_ mods: [Mod]) throws -> URL {
        try zipModFolders(mods.map { (folderName: $0.folderName, folderURL: $0.folderURL, subfolder: $0.subfolder) })
    }

    /// ZIP mod folders by path — safe to call from any thread
    static func zipModFolders(_ folders: [(folderName: String, folderURL: URL, subfolder: String?)]) throws -> URL {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appending(path: "transfer_\(UUID().uuidString)")

        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let modsStaging = tempDir.appending(path: "Mods")
        try fm.createDirectory(at: modsStaging, withIntermediateDirectories: true)

        for folder in folders {
            // Mirror the subfolder so two mods sharing a folder name can't silently overwrite
            let relative = folder.subfolder.map { "\($0)/\(folder.folderName)" } ?? folder.folderName
            let destination = modsStaging.appending(path: relative)
            try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fm.fileExists(atPath: destination.path(percentEncoded: false)) {
                try fm.removeItem(at: destination)
            }
            try fm.copyItem(at: folder.folderURL, to: destination)
        }

        let zipURL = fm.temporaryDirectory.appending(path: "mods_transfer_\(UUID().uuidString).zip")

        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--keepParent",
                             tempDir.path(percentEncoded: false),
                             zipURL.path(percentEncoded: false)]
        try process.run()
        process.waitUntilExit()

        try? fm.removeItem(at: tempDir)

        guard process.terminationStatus == 0 else {
            throw ModpackError.exportFailed("Failed to create transfer ZIP")
        }

        return zipURL
    }

    // MARK: - Import

    static func importFromJSON(at url: URL) throws -> Modpack {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode(Modpack.self, from: data)
            // Assign a fresh id so importing the same file twice can't create two
            // modpacks that collide on identity (which breaks ForEach/selection).
            // Untrusted: only the app itself ever sets a real bundle folder name.
            return Modpack(
                id: UUID(),
                name: decoded.name,
                description: decoded.description,
                entries: decoded.entries,
                source: .imported(fileName: url.lastPathComponent),
                includesFiles: decoded.includesFiles,
                bundleFolderName: nil,
                createdAt: decoded.createdAt,
                updatedAt: decoded.updatedAt
            )
        } catch let error as ModpackError {
            throw error
        } catch {
            throw ModpackError.importFailed(error.localizedDescription)
        }
    }

    static func importFromZIP(at url: URL, settings: AppSettings, existingMods: [Mod] = []) throws -> (Modpack, [Mod]) {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? fm.removeItem(at: tempDir) }

        do {
            try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        } catch {
            throw ModpackError.importFailed("Failed to create temp directory: \(error.localizedDescription)")
        }

        // Extract ZIP using the validated extractor (zip-slip / symlink / zip-bomb guarded)
        do {
            try ArchiveService.extract(url, to: tempDir)
        } catch {
            throw ModpackError.importFailed(error.localizedDescription)
        }

        // Look for modpack.json in extracted contents (may be nested inside a folder from --keepParent)
        let modpackManifestURL = findFile(named: "modpack.json", in: tempDir, fm: fm)

        var modpack: Modpack
        if let manifestURL = modpackManifestURL {
            let data = try Data(contentsOf: manifestURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode(Modpack.self, from: data)
            // Assign a fresh id: reusing the file's UUID lets a repeated import
            // create identity-colliding modpacks (breaks ForEach/selection).
            modpack = Modpack(
                id: UUID(),
                name: decoded.name,
                description: decoded.description,
                entries: decoded.entries,
                source: decoded.source,
                includesFiles: decoded.includesFiles,
                bundleFolderName: nil,
                createdAt: decoded.createdAt,
                updatedAt: decoded.updatedAt
            )
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

        let modFolders = ModFolderScanner.findModFolders(in: modsDir, fm: fm)
        for modFolder in modFolders {
            do {
                let result = try ModManagementService.importMod(from: modFolder, settings: settings, existingMods: existingMods)
                importedMods.append(contentsOf: result.mods)
            } catch {
                // Skip individual mods that fail to import
                continue
            }
        }

        // Build entries from imported mods if modpack.json was absent
        if modpackManifestURL == nil {
            modpack.entries = importedMods.map { mod in
                ModpackEntry(mod: mod, isEnabled: true)
            }
        }

        modpack.source = .imported(fileName: url.lastPathComponent)
        modpack.includesFiles = true
        // Untrusted: a decoded modpack.json could carry an arbitrary bundle folder
        // name; only the app itself ever sets a real one.
        modpack.bundleFolderName = nil

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
}
