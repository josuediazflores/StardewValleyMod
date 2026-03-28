import Foundation

enum AppTheme: String, CaseIterable, Identifiable {
    case stardew = "Stardew"
    case pink = "Pink"

    var id: String { rawValue }

    static var current: AppTheme {
        AppTheme(rawValue: UserDefaults.standard.string(forKey: "appTheme") ?? "Stardew") ?? .stardew
    }
}

@Observable
final class AppSettings {
    var gamePath: String {
        didSet { UserDefaults.standard.set(gamePath, forKey: "gamePath") }
    }
    var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "appTheme") }
    }
    var nexusAPIKey: String? {
        didSet {
            if let nexusAPIKey {
                try? KeychainService.save(apiKey: nexusAPIKey)
            } else {
                KeychainService.delete()
            }
        }
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
        theme = AppTheme(rawValue: UserDefaults.standard.string(forKey: "appTheme") ?? "Stardew") ?? .stardew
        if let saved = UserDefaults.standard.string(forKey: "gamePath"), !saved.isEmpty {
            gamePath = saved
        } else {
            gamePath = GamePathDetector.detect() ?? ""
        }
        // Migrate API key from UserDefaults to Keychain
        if let legacyKey = UserDefaults.standard.string(forKey: "nexusAPIKey"), !legacyKey.isEmpty {
            try? KeychainService.save(apiKey: legacyKey)
            UserDefaults.standard.removeObject(forKey: "nexusAPIKey")
            nexusAPIKey = legacyKey
        } else {
            nexusAPIKey = KeychainService.load()
        }
    }
}
