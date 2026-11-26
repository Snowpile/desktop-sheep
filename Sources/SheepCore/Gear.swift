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
        case .none, .impact, .countdown, .hearts, .butterfly, .scuffle, .grip, .alert, .dirt:
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
        case .alert: drawAlert(&c)
        case let .dirt(f): drawDirt(&c, frame: f)
        default: break
        }
    }

    static func heart(_ c: inout PixelCanvas, x: Int, y: Int, _ color: UInt8 = 6) {
        c.plot([(x, y), (x + 2, y), (x - 1, y + 1), (x, y + 1), (x + 1, y + 1), (x + 2, y + 1),
                (x + 3, y + 1), (x, y + 2), (x + 1, y + 2), (x + 2, y + 2), (x + 1, y + 3)], color)
    }

    /// Hearts rising from between the two pets, red with a pink shine.
    private static func drawHearts(_ c: inout PixelCanvas, frame f: Int) {
        for (x, y) in [(33, -1 - f)] + (f >= 2 ? [(38, -4 - (f - 2))] : []) {
            heart(&c, x: x, y: y, 21)
            c[x, y] = 6
        }
    }

    /// Dirt clods thrown back between the hind legs, and a growing mound in front.
    private static func drawDirt(_ c: inout PixelCanvas, frame f: Int) {
        // Clods spray up from the front paws and arc back over the pet, further along every frame.
        for i in 0..<5 {
            let t = Double((f + i) % 5) / 4 // 0 = leaving the paws, 1 = landing behind
            let x = 30 - Int(t * 34), y = ground - 3 - Int(sin(t * .pi) * 30)
            let big = i % 2 == 0
            c.fill(x: x, y: y, width: big ? 2 : 1, height: big ? 2 : 1, big ? 36 : 35)
        }
        // A dark hole under the front paws with a mound piling up beside it.
        c.fill(x: 29, y: ground, width: 7, height: 1, 36)
        let pile = 2 + f % 2
        c.ellipse(cx: 37, cy: ground, rx: 3, ry: pile, 35)
        c.fill(x: 36, y: ground - pile, width: 2, height: 1, 36)
    }

    /// A butterfly fluttering just ahead of the pet's nose.
    /// A butterfly looping just ahead of and above the pet's nose.
    private static func drawButterfly(_ c: inout PixelCanvas, frame f: Int) {
        let path = [(36, 6), (38, 4), (40, 3), (41, 5), (40, 7), (38, 8), (36, 9), (35, 7)]
        let (x, y) = path[f % path.count]
        // Body and antennae.
        c.fill(x: x, y: y - 1, width: 1, height: 4, 1)
        c.plot([(x - 1, y - 3), (x + 1, y - 3), (x - 1, y - 2), (x + 1, y - 2)].enumerated().filter { $0.offset < 2 || f % 2 == 0 }.map(\.element), 1)
        if f % 2 == 0 {
            // Wings open: big orange forewings with a yellow spot, small hindwings.
            for side in [-1, 1] {
                let near = side < 0 ? x - 3 : x + 1
                c.fill(x: near, y: y - 2, width: 3, height: 3, 22)
                c.plot([(side < 0 ? x - 3 : x + 3, y - 2)], 28)
                c[side < 0 ? x - 2 : x + 2, y - 1] = 26
                c.fill(x: side < 0 ? x - 2 : x + 1, y: y + 1, width: 2, height: 2, 28)
            }
        } else {
            // Wings folded up together.
            c.fill(x: x - 2, y: y - 3, width: 2, height: 3, 22)
            c.fill(x: x + 1, y: y - 3, width: 2, height: 3, 22)
            c.plot([(x - 1, y), (x + 1, y)], 28)
        }
    }

    /// A tumbling dust cloud with stars in front of the face.
    private static func drawScuffle(_ c: inout PixelCanvas, frame f: Int) {
        // A cartoon dust cloud of overlapping puffs that churns from frame to frame.
        let puffs = [(35, 24, 3), (40, 22, 4), (44, 25, 3), (39, 27, 3)]
        var cloud = PixelCanvas(width: c.width, height: c.height)
        cloud.originX = c.originX; cloud.originY = c.originY
        for (i, (x, y, r)) in puffs.enumerated() {
            cloud.disc(cx: x + (i + f) % 2, cy: y - (i + f + 1) % 2, r: r, 29)
        }
        for y in -20..<40 { for x in -10..<50 where cloud[x, y] != 0 {
            let edge = [cloud[x - 1, y], cloud[x + 1, y], cloud[x, y - 1], cloud[x, y + 1]].contains(0)
            let lower = cloud[x, y + 2] == 0
            c[x, y] = edge ? 30 : (lower ? 29 : 5)
        } }
        // Stars and a flailing paw popping out of the cloud.
        let star = [(0, -1), (-1, 0), (0, 0), (1, 0), (0, 1)]
        let s = [(34, 18), (45, 19), (41, 30)][f % 3]
        c.plot(star.map { ($0.0 + s.0, $0.1 + s.1) }, 26)
        let paw = [(46, 21), (33, 27), (43, 17), (37, 30)][f % 4]
        c.fill(x: paw.0, y: paw.1, width: 2, height: 2, 1)
    }

    /// A red "!" over the head.
    /// A small red "!" over the head with shock lines bursting out around it.
    private static func drawAlert(_ c: inout PixelCanvas) {
        let top = -9
        c.fill(x: 31, y: top, width: 3, height: 7, 1)
        c.fill(x: 31, y: top + 8, width: 3, height: 3, 1)
        c.fill(x: 32, y: top + 1, width: 1, height: 5, 21)
        c[32, top + 9] = 21
        for (from, to) in [((27, top + 2), (28, top + 4)), ((37, top + 2), (36, top + 4)), ((26, top + 7), (28, top + 7)), ((38, top + 7), (36, top + 7))] {
            line(&c, from: from, to: to, 1)
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
