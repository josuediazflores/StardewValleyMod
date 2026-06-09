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

        guard FileManager.default.isExecutableFile(atPath: smapiPath) else {
            throw GameLauncherError.smapiNotFound
        }

        if settings.showSMAPIConsole {
            try launchInTerminal(settings: settings)
        } else {
            try launchDirect(settings: settings)
        }
    }

    /// Launches SMAPI inside Terminal.app so its console output is visible.
    /// SMAPI's own binary never opens a terminal — it expects to be started from one.
    private static func launchInTerminal(settings: AppSettings) throws {
        let script = """
        #!/bin/bash
        cd \(shellQuoted(settings.gamePath)) || exit 1
        exec ./StardewModdingAPI
        """
        let scriptURL = FileManager.default.temporaryDirectory.appending(path: "smm-launch-smapi.command")

        do {
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: scriptURL.path(percentEncoded: false)
            )

            let process = Process()
            process.executableURL = URL(filePath: "/usr/bin/open")
            process.arguments = ["-a", "Terminal", scriptURL.path(percentEncoded: false)]
            try process.run()
        } catch {
            throw GameLauncherError.launchFailed(error.localizedDescription)
        }
    }

    private static func launchDirect(settings: AppSettings) throws {
        let process = Process()
        process.executableURL = settings.smapiURL
        process.currentDirectoryURL = URL(filePath: settings.gamePath)

        do {
            try process.run()
        } catch {
            throw GameLauncherError.launchFailed(error.localizedDescription)
        }
    }

    private static func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
