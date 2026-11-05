import Foundation

/// Short original sound effects, synthesized from oscillators and noise (no recordings).
public enum SoundEffect: String, CaseIterable, Sendable {
    case bleat, meow, bark, squeak, chirp, thud, poof, boom, sizzle, pop, beam

    /// The call sound for an animal.
    public static func call(for animal: Animal) -> SoundEffect {
        switch animal {
        case .sheep: return .bleat
        case .cat: return .meow
        case .dog: return .bark
        case .bunny: return .squeak
        case .redPanda: return .chirp
        }
    }

    /// The sound when a grand finale goes off.
    public static func finale(_ style: FinaleStyle) -> SoundEffect {
        switch style {
        case .burn: return .sizzle
        case .explode: return .boom
        case .vanish: return .poof
        case .balloons, .shrink: return .pop
        case .beamUp: return .beam
        case .random: return .poof
        }
    }
}

public enum Synth {
    public static let sampleRate = 44_100.0

    /// Mono samples in -1...1.
    public static func samples(_ effect: SoundEffect) -> [Float] {
        var rng = SeededGenerator(seed: 0x5EED_0000 + UInt64(SoundEffect.allCases.firstIndex(of: effect)!))
        func white() -> Double { Double(rng.next() % 2_000_001) / 1_000_000 - 1 }
        var out: [Double]
        switch effect {
        case .bleat:
            // "Baa-aa": buzzy voice with the quick flutter of a bleat, pitch sagging at the end.
            out = tone(seconds: 0.62, harmonics: [1, 0.6, 0.45, 0.3, 0.2, 0.12]) { t, d in
                let f = 330 - 60 * (t / d) + sin(t * 2 * .pi * 6.5) * 8
                return (f, envelope(t, d, attack: 0.03, release: 0.18) * (0.75 + 0.25 * sin(t * 2 * .pi * 13)))
            }
        case .meow:
            // "Mi-aow": pitch rises then falls, the vowel opening up in the middle.
            out = tone(seconds: 0.55, harmonics: [1, 0.5, 0.3, 0.15]) { t, d in
                let x = t / d
                let f = 520 + 300 * sin(min(x * 1.3, 1) * .pi) - 120 * x
                return (f, envelope(t, d, attack: 0.04, release: 0.2))
            }
        case .bark:
            // Two short, rough "woof"s.
            out = []
            for k in 0..<2 {
                let burst = tone(seconds: 0.14, harmonics: [1, 0.7, 0.5, 0.35, 0.2]) { t, d in
                    (260 - 140 * (t / d), envelope(t, d, attack: 0.005, release: 0.08))
                }
                out += burst.enumerated().map { i, s in s * 0.85 + white() * 0.15 * envelope(Double(i) / sampleRate, 0.14, attack: 0.002, release: 0.05) }
                if k == 0 { out += Array(repeating: 0, count: Int(0.09 * sampleRate)) }
            }
        case .squeak:
            out = []
            for _ in 0..<2 {
                out += tone(seconds: 0.09, harmonics: [1, 0.15]) { t, d in (1900 + 900 * (t / d), envelope(t, d, attack: 0.005, release: 0.04)) }
                out += Array(repeating: 0, count: Int(0.05 * sampleRate))
            }
        case .chirp:
            out = []
            for k in 0..<3 {
                out += tone(seconds: 0.06, harmonics: [1, 0.3]) { t, d in (1300 + Double(k) * 120 + 600 * (t / d), envelope(t, d, attack: 0.004, release: 0.03)) }
                out += Array(repeating: 0, count: Int(0.04 * sampleRate))
            }
        case .thud:
            var lp = 0.0
            out = tone(seconds: 0.3, harmonics: [1, 0.3]) { t, d in (95 - 45 * (t / d), envelope(t, d, attack: 0.002, release: 0.25)) }
            out = out.enumerated().map { i, s in
                lp += (white() - lp) * 0.08
                return s + lp * 0.6 * envelope(Double(i) / sampleRate, 0.3, attack: 0.001, release: 0.2)
            }
        case .poof:
            var lp = 0.0
            out = (0..<Int(0.45 * sampleRate)).map { i in
                let t = Double(i) / sampleRate
                lp += (white() - lp) * (0.05 + 0.25 * (1 - t / 0.45))
                return lp * 1.6 * envelope(t, 0.45, attack: 0.05, release: 0.3)
            }
        case .boom:
            var lp = 0.0
            out = (0..<Int(0.9 * sampleRate)).map { i in
                let t = Double(i) / sampleRate
                lp += (white() - lp) * 0.06
                let rumble = sin(2 * .pi * (55 - 20 * t) * t)
                return (lp * 1.4 + rumble * 0.6) * envelope(t, 0.9, attack: 0.004, release: 0.8)
            }
        case .sizzle:
            var hp = 0.0, prev = 0.0
            out = (0..<Int(1.0 * sampleRate)).map { i in
                let t = Double(i) / sampleRate
                let n = white()
                hp = 0.92 * (hp + n - prev)
                prev = n
                let crackle = rng.next() % 400 == 0 ? white() * 3 : 0
                return (hp * 0.5 + crackle) * envelope(t, 1.0, attack: 0.08, release: 0.5)
            }
        case .pop:
            out = tone(seconds: 0.12, harmonics: [1, 0.4]) { t, d in (600 + 900 * (t / d), envelope(t, d, attack: 0.002, release: 0.08)) }
        case .beam:
            out = tone(seconds: 1.1, harmonics: [1, 0.5, 0.25]) { t, d in
                (300 + 700 * (t / d) + sin(t * 2 * .pi * 9) * 20, envelope(t, d, attack: 0.2, release: 0.4) * 0.6)
            }
        }
        let peak = out.map(abs).max() ?? 1
        let gain = peak > 0 ? 0.8 / peak : 0
        return out.map { Float($0 * gain) }
    }

    /// Additive tone with a time-varying pitch and amplitude.
    private static func tone(seconds: Double, harmonics: [Double],
                             _ shape: (Double, Double) -> (frequency: Double, amplitude: Double)) -> [Double] {
        var phase = 0.0
        return (0..<Int(seconds * sampleRate)).map { i in
            let t = Double(i) / sampleRate
            let (f, a) = shape(t, seconds)
            phase += 2 * .pi * f / sampleRate
            var s = 0.0
            for (h, weight) in harmonics.enumerated() { s += sin(phase * Double(h + 1)) * weight }
            return s * a
        }
    }

    private static func envelope(_ t: Double, _ d: Double, attack: Double, release: Double) -> Double {
        if t < attack { return t / attack }
        if t > d - release { return max(0, (d - t) / release) }
        return 1
    }

    /// 16-bit mono PCM WAV file data.
    public static func wav(_ samples: [Float]) -> Data {
        var data = Data()
        func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
        let rate = UInt32(sampleRate), bytes = UInt32(samples.count * 2)
        data.append(contentsOf: Array("RIFF".utf8)); u32(36 + bytes)
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8)); u32(16); u16(1); u16(1); u32(rate); u32(rate * 2); u16(2); u16(16)
        data.append(contentsOf: Array("data".utf8)); u32(bytes)
        for s in samples { u16(UInt16(bitPattern: Int16(max(-1, min(1, s)) * 32_767))) }
        return data
    }
}
