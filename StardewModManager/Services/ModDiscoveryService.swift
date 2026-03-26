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

        guard let contents = try? fm.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return mods }

        for itemURL in contents {
            guard (try? itemURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else {
                continue
            }

            // Skip backup folders
            if itemURL.lastPathComponent.hasPrefix("Mods_backup") { continue }

            let manifestURL = itemURL.appending(path: "manifest.json")
            guard fm.fileExists(atPath: manifestURL.path(percentEncoded: false)) else { continue }

            if let manifest = ManifestParser.parse(at: manifestURL) {
                let mod = Mod(
                    manifest: manifest,
                    folderName: itemURL.lastPathComponent,
                    folderURL: itemURL,
                    isEnabled: isEnabled
                )
                mods.append(mod)
            }
        }

        return mods
    }
}
