import Foundation

enum GamePathDetector {
    private static let standardPaths = [
        "~/Library/Application Support/Steam/steamapps/common/Stardew Valley/Contents/MacOS",
        "~/Library/Application Support/Steam/steamapps/common/Stardew Valley (game preview)/Contents/MacOS",
    ]

    static func detect() -> String? {
        let fm = FileManager.default

        // Check standard Steam paths
        for path in standardPaths {
            let expanded = NSString(string: path).expandingTildeInPath
            let smapiPath = (expanded as NSString).appendingPathComponent("StardewModdingAPI")
            if fm.isExecutableFile(atPath: smapiPath) {
                return expanded
            }
        }

        // Try parsing libraryfolders.vdf for additional Steam library locations
        let vdfPath = NSString(string: "~/Library/Application Support/Steam/steamapps/libraryfolders.vdf").expandingTildeInPath
        if let vdfContents = try? String(contentsOfFile: vdfPath, encoding: .utf8) {
            let paths = parseLibraryFolders(vdf: vdfContents)
            for libraryPath in paths {
                let gamePath = (libraryPath as NSString).appendingPathComponent(
                    "steamapps/common/Stardew Valley/Contents/MacOS"
                )
                let smapiPath = (gamePath as NSString).appendingPathComponent("StardewModdingAPI")
                if fm.isExecutableFile(atPath: smapiPath) {
                    return gamePath
                }
            }
        }

        // Fallback: return standard path even without SMAPI (game may be installed but not SMAPI)
        for path in standardPaths {
            let expanded = NSString(string: path).expandingTildeInPath
            if fm.fileExists(atPath: expanded) {
                return expanded
            }
        }

        return nil
    }

    private static func parseLibraryFolders(vdf: String) -> [String] {
        var paths: [String] = []
        // Simple VDF parser: look for "path" keys
        let pattern = #""path"\s+"([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return paths }
        let matches = regex.matches(in: vdf, range: NSRange(vdf.startIndex..., in: vdf))
        for match in matches {
            if let range = Range(match.range(at: 1), in: vdf) {
                paths.append(String(vdf[range]))
            }
        }
        return paths
    }
}
