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

        // Skip backup folders, mirroring the previous inline "Mods_backup" guard.
        let modFolders = ModFolderScanner.findModFolders(in: directoryURL, excluding: ["Mods_backup"], fm: fm)
        let basePath = directoryURL.resolvingSymlinksInPath().path(percentEncoded: false)

        for parentDir in modFolders {
            let manifestURL = parentDir.appending(path: "manifest.json")
            guard let manifest = ManifestParser.parse(at: manifestURL) else { continue }

            // Determine relative parent path inside the base directory (e.g. "Gameplay/Combat").
            // Resolve symlinks on both sides so the prefix match can't silently fail
            // (the move logic uses this path to place the folder).
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
