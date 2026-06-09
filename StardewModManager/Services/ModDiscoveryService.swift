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

            // Determine relative parent path inside the base directory (e.g. "Gameplay/Combat")
            let basePath = directoryURL.path(percentEncoded: false)
            let relativePath = parentPath.replacingOccurrences(of: basePath, with: "")
            let components = relativePath.split(separator: "/").map(String.init)
            let subfolder: String? = components.count > 1 ? components.dropLast().joined(separator: "/") : nil

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
