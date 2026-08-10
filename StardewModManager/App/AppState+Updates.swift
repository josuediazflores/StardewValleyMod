import Foundation
import SwiftUI

extension AppState {

    // MARK: - SMAPI Installation

    func installSMAPI() {
        guard settings.isGamePathValid else {
            showToast("Set your game path before installing SMAPI", type: .warning)
            return
        }
        guard !isSMAPIInstalling else { return }
        isSMAPIInstalling = true
        smapiInstallError = nil
        Task {
            do {
                try await SMAPIInstallService.downloadAndInstall(to: settings.gamePath)
                showToast("SMAPI installed!", type: .success)
                SoundService.play(.bigSelect)
            } catch {
                smapiInstallError = error.localizedDescription
                showToast("SMAPI install failed", type: .warning)
            }
            isSMAPIInstalling = false
        }
    }

    // MARK: - App Update Check

    func checkForAppUpdate() {
        Task {
            do {
                availableUpdate = try await UpdateService.checkForUpdate()
                if availableUpdate != nil {
                    showAppUpdatePrompt = true
                }
            } catch {
                // Silent startup check: don't interrupt the user, just log.
                NSLog("[AppState] Silent app-update check failed: \(error.localizedDescription)")
            }
        }
    }

    func performAppUpdate() {
        guard let update = availableUpdate else { return }
        isUpdating = true
        updateError = nil
        Task {
            do {
                try await UpdateService.downloadAndInstall(update: update)
            } catch {
                isUpdating = false
                updateError = error.localizedDescription
            }
        }
    }

}
