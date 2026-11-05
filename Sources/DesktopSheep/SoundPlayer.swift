import AVFoundation
import SheepCore

/// Plays the synthesized sound effects, each one rendered once and cached.
@MainActor
final class SoundPlayer {
    private var players: [SoundEffect: AVAudioPlayer] = [:]
    private var lastPlayed: [SoundEffect: Double] = [:]

    func play(_ effect: SoundEffect, now: Double) {
        // Don't let a whole flock bleat in the same instant.
        if let last = lastPlayed[effect], now - last < 0.35 { return }
        lastPlayed[effect] = now
        let player = players[effect] ?? {
            let p = try? AVAudioPlayer(data: Synth.wav(Synth.samples(effect)))
            p?.volume = 0.45
            p?.prepareToPlay()
            players[effect] = p
            return p
        }()
        player?.currentTime = 0
        player?.play()
    }
}
