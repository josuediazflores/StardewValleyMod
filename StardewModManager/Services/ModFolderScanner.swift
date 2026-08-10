import Foundation

/// Recursively finds mod folders (directories containing a `manifest.json`) under
/// `dir`, skipping any folder nested inside an already-found mod so a mod's own
/// bundled sub-mods aren't imported twice. Consolidates the identical walk that
/// ModManagementService, ModpackService, and ModDiscoveryService each carried.
enum ModFolderScanner {
    /// - Parameters:
    ///   - dir: Directory to scan.
    ///   - excluding: Path substrings to skip (e.g. `["Mods_backup"]`); any manifest
    ///     whose parent path contains one of these is ignored entirely.
    ///   - fm: FileManager to use.
    /// - Returns: The parent directory of each qualifying `manifest.json`, in
    ///   enumeration order.
    static func findModFolders(in dir: URL, excluding: [String] = [], fm: FileManager = .default) -> [URL] {
        var result: [URL] = []

        guard let enumerator = fm.enumerator(
            at: dir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return result }

        var manifestParentDirs: Set<String> = []

        for case let fileURL as URL in enumerator {
            guard fileURL.lastPathComponent == "manifest.json" else { continue }
            let parentDir = fileURL.deletingLastPathComponent()
            let parentPath = parentDir.path(percentEncoded: false)

            // Skip excluded folders (e.g. backups) before they can be recorded.
            if excluding.contains(where: { parentPath.contains($0) }) { continue }

            // Avoid adding nested mod folders that are children of already-found mods.
            // Use a path-boundary check so a sibling whose name merely shares a prefix
            // (e.g. "Mods" vs "Mods_backup") isn't mistaken for a child.
            if manifestParentDirs.contains(where: { parentPath.hasPrefix($0 + "/") && parentPath != $0 }) { continue }

            manifestParentDirs.insert(parentPath)
            result.append(parentDir)
        }

        return result
    }
}
