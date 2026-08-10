import Foundation

/// Every UserDefaults key the app persists, in one place. Read and write preferences
/// through these constants so a key can't drift between the read site and the write site.
enum DefaultsKey {
    static let appTheme = "appTheme"
    static let enableSounds = "enableSounds"
    static let appLanguage = "appLanguage"
    static let gamePath = "gamePath"
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let showSMAPIConsole = "showSMAPIConsole"

    /// Legacy key: the Nexus API key used to live in UserDefaults before it moved to the
    /// Keychain. Kept only so AppSettings.init can migrate and clear any leftover value.
    static let legacyNexusAPIKey = "nexusAPIKey"
}

/// App-wide configuration that tracks external services (Stardew Valley, SMAPI, the GitHub
/// release feed, the featured Nexus mods). Kept together so a new Stardew or SMAPI release is
/// a one-line change here instead of a hunt through the services.
enum AppConfig {
    /// Stardew Valley game version reported to the SMAPI update API. Bump on a major Stardew
    /// release so update checks resolve against the right game version.
    static let gameVersion = "1.6.0"

    /// SMAPI API version reported to the SMAPI update API. Bump when targeting a new SMAPI
    /// major version.
    static let apiVersion = "4.0.0"

    /// GitHub "latest release" feed for the app's own self-updater. Update if the repo owner
    /// or name ever changes.
    static let releasesURL = "https://api.github.com/repos/josuediazflores/StardewValleyMod/releases/latest"

    /// Nexus mod IDs featured as "essentials" on the Browse tab. Curate as the recommended
    /// starter set changes; display order is preserved.
    static let essentialModIDs = [1915, 5098, 1063, 541, 4, 239, 12747, 3753, 11115, 518]
}
