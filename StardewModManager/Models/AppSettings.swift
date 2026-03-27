import Foundation

@Observable
final class AppSettings {
    var gamePath: String {
        didSet { UserDefaults.standard.set(gamePath, forKey: "gamePath") }
    }
    var nexusAPIKey: String? {
        didSet { UserDefaults.standard.set(nexusAPIKey, forKey: "nexusAPIKey") }
    }
    var isAPIKeyValidated: Bool = false
    var nexusUserName: String?
    var isNexusPremium: Bool = false

    var modsDirectoryURL: URL {
        URL(filePath: gamePath).appending(path: "Mods")
    }

    var disabledModsDirectoryURL: URL {
        URL(filePath: gamePath).appending(path: "Mods_Disabled")
    }

    var modpacksDirectoryURL: URL {
        URL(filePath: gamePath).appending(path: "Modpacks")
    }

    var smapiURL: URL {
        URL(filePath: gamePath).appending(path: "StardewModdingAPI")
    }

    var isSMAPIInstalled: Bool {
        FileManager.default.isExecutableFile(atPath: smapiURL.path(percentEncoded: false))
    }

    var isGamePathValid: Bool {
        FileManager.default.fileExists(atPath: gamePath)
    }

    init() {
        if let saved = UserDefaults.standard.string(forKey: "gamePath"), !saved.isEmpty {
            gamePath = saved
        } else {
            gamePath = GamePathDetector.detect() ?? ""
        }
        nexusAPIKey = UserDefaults.standard.string(forKey: "nexusAPIKey")
    }
}
