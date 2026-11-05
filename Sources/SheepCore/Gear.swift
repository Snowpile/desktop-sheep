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
        case let .dirt(frame):
            drawDirt(&c, frame: frame)
        case .none, .impact, .countdown, .hearts, .butterfly, .scuffle, .grip, .alert:
            break
        }
    }

    static func drawGearInFront(_ c: inout PixelCanvas, _ gear: Pose.Gear) {
        if case let .impact(frame) = gear { drawImpact(&c, frame: frame) }
        if case let .jetpack(frame) = gear { drawJetFlame(&c, frame: frame) }
        switch gear {
        case let .countdown(n): drawCountdown(&c, digit: n)
        case let .hearts(f): drawHearts(&c, frame: f)
        case let .butterfly(f): drawButterfly(&c, frame: f)
        case let .scuffle(f): drawScuffle(&c, frame: f)
        case .grip: drawGrip(&c)
        case .alert: drawAlert(&c)
        default: break
        }
    }

    static func heart(_ c: inout PixelCanvas, x: Int, y: Int, _ color: UInt8 = 6) {
        c.plot([(x, y), (x + 2, y), (x - 1, y + 1), (x, y + 1), (x + 1, y + 1), (x + 2, y + 1),
                (x + 3, y + 1), (x, y + 2), (x + 1, y + 2), (x + 2, y + 2), (x + 1, y + 3)], color)
    }

    private static func drawHearts(_ c: inout PixelCanvas, frame f: Int) {
        heart(&c, x: 30, y: 6 - f)
        if f >= 2 { heart(&c, x: 35, y: 2 - (f - 2)) }
    }

    /// Dirt clods thrown back between the hind legs, and a growing mound in front.
    private static func drawDirt(_ c: inout PixelCanvas, frame f: Int) {
        let clods = [(-1, 24), (-3, 20), (-5, 17), (-2, 15), (-6, 22)]
        for (i, (x, y)) in clods.enumerated() where (i + f) % 2 == 0 {
            c.fill(x: x - f % 2, y: y - f % 3, width: 2, height: 2, i % 2 == 0 ? 35 : 36)
        }
        c.fill(x: 29, y: ground - 1, width: 6, height: 2, 36)
        c.fill(x: 30, y: ground - 2, width: 4, height: 1, 35)
    }

    /// A butterfly fluttering just ahead of the pet's nose.
    private static func drawButterfly(_ c: inout PixelCanvas, frame f: Int) {
        let bob = [0, -2, -3, -2, 0, 1, 2, 1][f % 8]
        let x = 38 + (f % 4 < 2 ? 0 : 1), y = 6 + bob
        let open = f % 2 == 0
        c.fill(x: x, y: y, width: 1, height: 3, 1)
        if open {
            c.fill(x: x - 3, y: y - 1, width: 3, height: 2, 22)
            c.fill(x: x + 1, y: y - 1, width: 3, height: 2, 22)
            c.plot([(x - 2, y + 1), (x - 1, y + 2), (x + 2, y + 1), (x + 1, y + 2)], 26)
        } else {
            c.fill(x: x - 1, y: y - 2, width: 1, height: 3, 22)
            c.fill(x: x + 1, y: y - 2, width: 1, height: 3, 22)
        }
    }

    /// A tumbling dust cloud with stars in front of the face.
    private static func drawScuffle(_ c: inout PixelCanvas, frame f: Int) {
        c.disc(cx: 38, cy: 24 - f % 2, r: 3 + f % 2, 30)
        c.disc(cx: 39, cy: 24 - f % 2, r: 2 + f % 2, 29)
        let star = [(0, -1), (-1, 0), (0, 0), (1, 0), (0, 1)]
        let spots = [(36, 18), (41, 20), (38, 29)]
        let s = spots[f % 3]
        c.plot(star.map { ($0.0 + s.0, $0.1 + s.1) }, 26)
    }

    /// A red "!" over the head.
    private static func drawAlert(_ c: inout PixelCanvas) {
        c.fill(x: 30, y: 0, width: 4, height: 9, 1)
        c.fill(x: 30, y: 10, width: 4, height: 4, 1)
        c.fill(x: 31, y: 1, width: 2, height: 7, 21)
        c.fill(x: 31, y: 11, width: 2, height: 2, 21)
    }

    /// Front paws hooked over the edge the pet hangs from.
    private static func drawGrip(_ c: inout PixelCanvas) {
        for x in [21, 28] {
            c.fill(x: x, y: 9, width: 3, height: 2, 1)
            c.fill(x: x + 1, y: 11, width: 1, height: 3, 1)
        }
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
