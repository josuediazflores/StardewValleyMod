import AVFoundation

enum StardewSound {
    case bigSelect  // full volume — major actions
    case click      // quieter — minor actions
    case warning    // medium — destructive actions
}

@MainActor
final class SoundService {
    static let shared = SoundService()

    // Keep a strong reference so the player doesn't get deallocated mid-playback
    private var player: AVAudioPlayer?

    static var isEnabled: Bool {
        if UserDefaults.standard.object(forKey: "enableSounds") == nil { return true }
        return UserDefaults.standard.bool(forKey: "enableSounds")
    }

    static func play(_ sound: StardewSound) {
        guard isEnabled else { return }
        guard let url = Bundle.module.url(forResource: "bigSelect", withExtension: "wav") else { return }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            switch sound {
            case .bigSelect:
                player.volume = 1.0
            case .click:
                player.volume = 0.5
            case .warning:
                player.volume = 0.7
            }
            player.prepareToPlay()
            player.play()
            shared.player = player  // retain until playback finishes
        } catch {
            print("[SoundService] Failed to play: \(error)")
        }
    }
}
