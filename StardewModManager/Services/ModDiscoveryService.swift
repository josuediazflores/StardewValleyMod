import Foundation

enum ModDiscoveryService {
    static func discoverMods(settings: AppSettings) -> [Mod] {
        var mods: [Mod] = []
        let fm = FileManager.default

        // Scan enabled mods
        mods += scanDirectory(settings.modsDirectoryURL, isEnabled: true, fm: fm)

        // Scan disabled mods
        mods += scanDirectory(settings.disabledModsDirectoryURL, isEnabled: false, fm: fm)

        return mods.sorted { $0.manifest.name.localizedCaseInsensitiveCompare($1.manifest.name) == .orderedAscending }
    }

    private static func scanDirectory(_ directoryURL: URL, isEnabled: Bool, fm: FileManager) -> [Mod] {
        var mods: [Mod] = []
        guard let enumerator = fm.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey, .creationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return mods }

        var manifestParentDirs: Set<String> = []

        for case let fileURL as URL in enumerator {
            guard fileURL.lastPathComponent == "manifest.json" else { continue }
            let parentDir = fileURL.deletingLastPathComponent()
            let parentPath = parentDir.path(percentEncoded: false)

            // Skip backup folders
            if parentPath.contains("Mods_backup") { continue }

            // Avoid nested mod folders (child of already-found mod)
            if manifestParentDirs.contains(where: { parentPath.hasPrefix($0) && parentPath != $0 }) { continue }
            manifestParentDirs.insert(parentPath)

            guard let manifest = ManifestParser.parse(at: fileURL) else { continue }

            // Determine relative parent path inside the base directory (e.g. "Gameplay/Combat").
            // Resolve symlinks on both sides so the prefix match can't silently fail
            // (the move logic uses this path to place the folder).
            let basePath = directoryURL.resolvingSymlinksInPath().path(percentEncoded: false)
            let resolvedParent = parentDir.resolvingSymlinksInPath().path(percentEncoded: false)
            var subfolder: String?
            if resolvedParent.hasPrefix(basePath + "/") {
                let components = resolvedParent.dropFirst(basePath.count + 1).split(separator: "/")
                if components.count > 1 {
                    subfolder = components.dropLast().joined(separator: "/")
                }
            }

            let creationDate = (try? parentDir.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date()

            let mod = Mod(
                manifest: manifest,
                folderName: parentDir.lastPathComponent,
                folderURL: parentDir,
                isEnabled: isEnabled,
                subfolder: subfolder,
                dateAdded: creationDate
            )
            mods.append(mod)
        }

        return mods
    }
}
