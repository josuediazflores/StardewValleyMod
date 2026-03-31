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

        let (resourceName, volume): (String, Float) = switch sound {
        case .bigSelect: ("bigSelect", 1.0)
        case .click:     ("click", 0.5)
        case .warning:   ("warning", 0.7)
        }

        guard let url = Bundle.appBundle.url(forResource: resourceName, withExtension: "wav") else { return }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = volume
            player.prepareToPlay()
            player.play()
            shared.player = player  // retain until playback finishes
        } catch {}
    }
}
