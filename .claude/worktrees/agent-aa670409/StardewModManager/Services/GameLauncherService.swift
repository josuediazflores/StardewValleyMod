import Foundation

enum GameLauncherError: LocalizedError {
    case smapiNotFound
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .smapiNotFound: return "SMAPI (StardewModdingAPI) was not found. Please install SMAPI first."
        case .launchFailed(let msg): return "Failed to launch game: \(msg)"
        }
    }
}

enum GameLauncherService {
    static func launch(settings: AppSettings) throws {
        let smapiPath = settings.smapiURL.path(percentEncoded: false)
        let gameDir = settings.gamePath

        guard FileManager.default.isExecutableFile(atPath: smapiPath) else {
            throw GameLauncherError.smapiNotFound
        }

        let process = Process()
        process.executableURL = settings.smapiURL
        process.currentDirectoryURL = URL(filePath: gameDir)
        process.arguments = ["--use-current-shell"]

        do {
            try process.run()
        } catch {
            throw GameLauncherError.launchFailed(error.localizedDescription)
        }
    }
}
