import Foundation

// SPM's auto-generated Bundle.module hardcodes the build machine's absolute path as a
// fallback, which causes a fatal crash on any other machine. This safe accessor resolves
// the resource bundle relative to the running executable instead.
extension Foundation.Bundle {
    static let appBundle: Bundle = {
        let bundleName = "StardewModManager_StardewModManager"

        // Look next to the executable (Contents/MacOS/) — this is where build-app.sh places it
        let executableURL = Bundle.main.executableURL ?? Bundle.main.bundleURL
        let nextToExecutable = executableURL
            .deletingLastPathComponent()
            .appendingPathComponent("\(bundleName).bundle")

        if let bundle = Bundle(url: nextToExecutable) {
            return bundle
        }

        // Fallback: Bundle.main may resolve it directly
        let mainPath = Bundle.main.bundleURL.appendingPathComponent("\(bundleName).bundle")
        if let bundle = Bundle(url: mainPath) {
            return bundle
        }

        // Last resort: use Bundle.main itself (resources may be embedded directly)
        return Bundle.main
    }()

    /// Returns a bundle for the user's chosen language, falling back to appBundle (system locale).
    static var localizedAppBundle: Bundle {
        guard let lang = UserDefaults.standard.string(forKey: DefaultsKey.appLanguage),
              lang != "system",
              let path = appBundle.path(forResource: lang, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return appBundle
        }
        return bundle
    }

    /// The English (`en.lproj`) sub-bundle, used as the last-resort fallback for keys missing
    /// from the user's selected-language table so they degrade to English instead of the raw
    /// key. Resolves to appBundle if en.lproj can't be located.
    static let englishAppBundle: Bundle = {
        guard let path = appBundle.path(forResource: "en", ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return appBundle
        }
        return bundle
    }()
}
