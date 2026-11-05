import Foundation
import Testing
@testable import SheepCore

@Suite struct SynthTests {
    @Test(arguments: SoundEffect.allCases)
    func everySoundIsShortAudibleAndNormalized(_ effect: SoundEffect) {
        let s = Synth.samples(effect)
        let seconds = Double(s.count) / Synth.sampleRate
        #expect(seconds > 0.05 && seconds < 1.5)
        let peak = s.map(abs).max() ?? 0
        #expect(abs(peak - 0.8) < 0.01)
        #expect(s.allSatisfy { $0.isFinite && abs($0) <= 1 })
        // Fades in and out instead of clicking.
        #expect(abs(s.first!) < 0.05 && abs(s.last!) < 0.05)
    }

    @Test func soundsAreDeterministic() {
        for e in SoundEffect.allCases { #expect(Synth.samples(e) == Synth.samples(e)) }
    }

    @Test func squeaksArePitchedHigherThanBleats() {
        func crossingsPerSecond(_ s: [Float]) -> Double {
            let n = zip(s, s.dropFirst()).filter { ($0 < 0) != ($1 < 0) }.count
            return Double(n) / (Double(s.count) / Synth.sampleRate)
        }
        #expect(crossingsPerSecond(Synth.samples(.squeak)) > 3 * crossingsPerSecond(Synth.samples(.bleat)))
    }

    @Test func wavHeaderIsValid() {
        let samples = Synth.samples(.pop)
        let wav = Synth.wav(samples)
        #expect(wav.count == 44 + samples.count * 2)
        #expect(String(decoding: wav[0..<4], as: UTF8.self) == "RIFF")
        #expect(String(decoding: wav[8..<12], as: UTF8.self) == "WAVE")
        #expect(String(decoding: wav[36..<40], as: UTF8.self) == "data")
        let rate = wav[24..<28].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        #expect(UInt32(littleEndian: rate) == 44_100)
    }

    @Test func eachAnimalAndFinaleHasASound() {
        #expect(Set(Animal.allCases.map(SoundEffect.call(for:))).count == Animal.allCases.count)
        for style in FinaleStyle.allCases { _ = SoundEffect.finale(style) }
    }

    @Test func soundsAreOffByDefault() {
        #expect(PetSettings().sounds == false)
    }
}
