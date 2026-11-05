import Foundation

/// Props and effects drawn around the pet, in body-space coordinates (negative rows reach
/// into the headroom above the pet).
extension PetArt {
    static func drawGearBehind(_ c: inout PixelCanvas, _ gear: Pose.Gear) {
        switch gear {
        case let .parachute(sway):
            drawParachute(&c, sway: sway)
        case let .meteor(frame):
            drawFlameTrail(&c, frame: frame)
        case let .jetpack(frame):
            drawJetpack(&c, frame: frame)
        case .none, .impact:
            break
        }
    }

    static func drawGearInFront(_ c: inout PixelCanvas, _ gear: Pose.Gear) {
        if case let .impact(frame) = gear { drawImpact(&c, frame: frame) }
        if case let .jetpack(frame) = gear { drawJetFlame(&c, frame: frame) }
    }

    /// Straight pixel line (Bresenham).
    static func line(_ c: inout PixelCanvas, from a: (Int, Int), to b: (Int, Int), _ color: UInt8) {
        var (x, y) = a
        let dx = abs(b.0 - x), dy = -abs(b.1 - y)
        let sx = x < b.0 ? 1 : -1, sy = y < b.1 ? 1 : -1
        var err = dx + dy
        while true {
            c[x, y] = color
            if x == b.0 && y == b.1 { return }
            let e2 = 2 * err
            if e2 >= dy { err += dy; x += sx }
            if e2 <= dx { err += dx; y += sy }
        }
    }

    /// Striped canopy above the pet with three strings down to its back.
    private static func drawParachute(_ c: inout PixelCanvas, sway: Int) {
        let cx = 17 + sway, top = -15, bottom = -6
        for (from, to) in [((cx - 13, bottom), (10, 15)), ((cx, bottom), (16, 13)), ((cx + 13, bottom), (22, 14))] {
            line(&c, from: from, to: to, 1)
        }
        for y in top...bottom {
            let t = Double(y - bottom) / Double(top - bottom) // 0 at rim, 1 at top
            let half = Int((14 * (1 - t * t)).squareRoot() * 3.75)
            for x in (cx - half)...(cx + half) {
                let edge = x == cx - half || x == cx + half || y == top
                let band = ((x - cx + 15) / 5) % 2 == 0
                c[x, y] = edge ? 1 : (band ? 21 : 14)
            }
        }
        // Scalloped rim.
        for x in stride(from: cx - 13, through: cx + 13, by: 2) { c[x, bottom + 1] = 1 }
    }

    /// Fire trailing up and behind a falling meteor pet.
    private static func drawFlameTrail(_ c: inout PixelCanvas, frame: Int) {
        let f = frame % 3
        let blobs: [(Int, Int, Int)] = [(12, 14, 9), (5, 7, 7), (0, 1, 5), (-3, -5, 3), (-5, -10, 2)]
        for (i, (x, y, r)) in blobs.enumerated() {
            let wobble = (i + f) % 3 - 1
            c.disc(cx: x + wobble, cy: y - wobble, r: r + (f == 1 ? 1 : 0), 28)
            if r > 2 { c.disc(cx: x + wobble + 1, cy: y - wobble + 1, r: r - 2, 27) }
            if r > 4 { c.disc(cx: x + wobble + 2, cy: y - wobble + 2, r: r - 4, 26) }
        }
        // Sparks.
        for (x, y) in [(-6 + f, 2 - f), (2 - f, -8 + f), (9 + f, 2 - f * 2)] { c[x, y] = 26 }
    }

    /// A little pack on the back.
    private static func drawJetpack(_ c: inout PixelCanvas, frame: Int) {
        c.fill(x: 5, y: 6, width: 7, height: 9, 1)
        c.fill(x: 6, y: 7, width: 5, height: 7, 31)
        c.fill(x: 6, y: 9, width: 5, height: 1, 21)
        c.fill(x: 4, y: 12, width: 2, height: 3, 1) // nozzle
    }

    /// Exhaust flame streaming back and down from the nozzle.
    private static func drawJetFlame(_ c: inout PixelCanvas, frame: Int) {
        let len = frame == 0 ? 7 : 10
        for i in 0..<len {
            let w = max(3 - i / 3, 1)
            let color: UInt8 = i < 2 ? 26 : (i < 5 ? 27 : 28)
            c.fill(x: 3 - i, y: 13 + i / 3 - w / 2, width: 1, height: w, color)
        }
    }

    /// Dust puffs spreading along the ground, a crack, and circling stars.
    private static func drawImpact(_ c: inout PixelCanvas, frame: Int) {
        let g = ground
        if frame < 5 {
            let spread = frame * 2
            for (x, r) in [(2 - spread, 2 + frame / 2), (32 + spread, 2 + frame / 2), (-2 - spread, 1), (36 + spread, 1)] {
                c.disc(cx: x, cy: g - r + 1, r: r, frame < 3 ? 29 : 30)
            }
        }
        line(&c, from: (6, g), to: (28, g), 33)
        let stars = [(0, -1), (1, 0), (0, 1), (-1, 0)]
        for i in 0..<3 {
            let angle = Double(frame) * 0.8 + Double(i) * 2.1
            let sx = 28 + Int((cos(angle) * 6).rounded()), sy = 8 + Int((sin(angle) * 2).rounded())
            c[sx, sy] = 26
            for (dx, dy) in stars { c[sx + dx, sy + dy] = 26 }
        }
    }
}
