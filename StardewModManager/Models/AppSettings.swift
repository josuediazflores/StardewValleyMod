import Foundation

enum AppTheme: String, CaseIterable, Identifiable {
    case stardew = "Stardew"
    case pink = "Pink"
    case night = "Night"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .stardew: L.s("theme_stardew")
        case .pink: L.s("theme_pink")
        case .night: L.s("theme_night")
        }
    }

    static var current: AppTheme {
        AppTheme(rawValue: UserDefaults.standard.string(forKey: DefaultsKey.appTheme) ?? "Stardew") ?? .stardew
    }
}

@Observable
final class AppSettings {
    /// Called whenever the Nexus API key changes so a single dependent (the Nexus API actor,
    /// wired by AppState) is updated in one place instead of every request site re-pushing the
    /// key. Not part of observation.
    @ObservationIgnored
    var onNexusAPIKeyChange: ((String?) -> Void)?

    var gamePath: String {
        didSet { UserDefaults.standard.set(gamePath, forKey: DefaultsKey.gamePath) }
    }
    var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: DefaultsKey.appTheme) }
    }
    var nexusAPIKey: String? {
        didSet {
            if let nexusAPIKey {
                try? KeychainService.save(apiKey: nexusAPIKey)
            } else {
                KeychainService.delete()
            }
            onNexusAPIKeyChange?(nexusAPIKey)
        }
    }
    var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: DefaultsKey.hasCompletedOnboarding) }
    }
    var enableSounds: Bool {
        didSet { UserDefaults.standard.set(enableSounds, forKey: DefaultsKey.enableSounds) }
    }
    var showSMAPIConsole: Bool {
        didSet { UserDefaults.standard.set(showSMAPIConsole, forKey: DefaultsKey.showSMAPIConsole) }
    }
    var language: String {
        didSet { UserDefaults.standard.set(language, forKey: DefaultsKey.appLanguage) }
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
        theme = AppTheme(rawValue: UserDefaults.standard.string(forKey: DefaultsKey.appTheme) ?? "Stardew") ?? .stardew
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: DefaultsKey.hasCompletedOnboarding)
        enableSounds = UserDefaults.standard.object(forKey: DefaultsKey.enableSounds) == nil ? true : UserDefaults.standard.bool(forKey: DefaultsKey.enableSounds)
        showSMAPIConsole = UserDefaults.standard.object(forKey: DefaultsKey.showSMAPIConsole) == nil ? true : UserDefaults.standard.bool(forKey: DefaultsKey.showSMAPIConsole)
        language = UserDefaults.standard.string(forKey: DefaultsKey.appLanguage) ?? "system"
        if let saved = UserDefaults.standard.string(forKey: DefaultsKey.gamePath), !saved.isEmpty {
            gamePath = saved
            // Existing users already have a game path — skip onboarding
            if !hasCompletedOnboarding {
                hasCompletedOnboarding = true
                UserDefaults.standard.set(true, forKey: DefaultsKey.hasCompletedOnboarding)
            }
        } else {
            gamePath = GamePathDetector.detect() ?? ""
        }
        // Migrate API key from UserDefaults to Keychain
        if let legacyKey = UserDefaults.standard.string(forKey: DefaultsKey.legacyNexusAPIKey), !legacyKey.isEmpty {
            try? KeychainService.save(apiKey: legacyKey)
            UserDefaults.standard.removeObject(forKey: DefaultsKey.legacyNexusAPIKey)
            nexusAPIKey = legacyKey
        } else {
            nexusAPIKey = KeychainService.load()
        }
    }
}
