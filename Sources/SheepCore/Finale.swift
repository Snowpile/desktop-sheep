import Foundation

/// How every pet leaves the stage in a grand finale.
public enum FinaleStyle: String, CaseIterable, Codable, Sendable {
    case burn, explode, vanish, balloons, beamUp, shrink, random

    public var title: String {
        switch self {
        case .burn: return "Burn to Ash"
        case .explode: return "Explode"
        case .vanish: return "Vanish in a Puff"
        case .balloons: return "Float Away on Balloons"
        case .beamUp: return "Beam Up"
        case .shrink: return "Shrink to Nothing"
        case .random: return "Surprise Me"
        }
    }

    /// Short description for the confirmation alert, e.g. "burn to ash".
    public var phrase: String {
        switch self {
        case .burn: return "burn to a little pile of ash"
        case .explode: return "pop into confetti"
        case .vanish: return "vanish in a puff of smoke"
        case .balloons: return "float away on balloons"
        case .beamUp: return "get beamed up"
        case .shrink: return "shrink to nothing"
        case .random: return "go out in a surprise finale"
        }
    }

    public static let concrete: [FinaleStyle] = [.burn, .explode, .vanish, .balloons, .beamUp, .shrink]

    public func resolved<R: RandomNumberGenerator>(using rng: inout R) -> FinaleStyle {
        self == .random ? Self.concrete.randomElement(using: &rng)! : self
    }
}

extension Pose {
    /// Finale transformations applied to the whole sprite.
    public enum FinaleLook: Hashable, Sendable {
        case none
        case burning(Int)
        case charred(Int)
        case ashPile(Int)
        case flash
        case debris(Int)
        case poof(Int)
        case balloons(Int)
        case beam(Int)
        case shrink(Int)
    }
}

extension PetArt {
    static let countdownSeconds = 3.0

    static func finaleFramesPerSecond(_ style: FinaleStyle) -> Double {
        switch style {
        case .burn: return 5
        case .explode, .vanish: return 10
        case .balloons: return 3
        case .beamUp: return 6
        case .shrink: return 8
        case .random: return 10
        }
    }

    /// Seconds from the end of the countdown until the pet is gone.
    public static func finaleDuration(_ style: FinaleStyle) -> Double {
        Double(finaleFrames(style).count) / finaleFramesPerSecond(style)
    }

    /// Countdown: "3", "2", "1" over a worried pet.
    static let countdownFrames: [Pose] = (0..<3).map { i in
        var p = Pose()
        p.eyes = .wide
        p.earUp = i == 2
        p.gear = .countdown(3 - i)
        return p
    }

    static func finaleFrames(_ style: FinaleStyle) -> [Pose] {
        func look(_ l: Pose.FinaleLook, eyes: Pose.Eyes = .wide, legs: Pose.Legs? = nil, shadow: Bool = true) -> Pose {
            var p = Pose()
            p.finale = l
            p.eyes = eyes
            p.mouthOpen = eyes == .wide
            p.shadow = shadow
            if let legs { p.legs = legs }
            return p
        }
        switch style {
        case .burn:
            return (0..<5).map { look(.burning($0)) }
                + (0..<3).map { look(.charred($0), eyes: .closed) }
                + (0..<8).map { look(.ashPile($0 / 2), shadow: false) }
        case .explode:
            return [look(.flash), look(.flash)] + (0..<12).map { look(.debris($0), shadow: false) }
        case .vanish:
            return (0..<12).map { look(.poof($0), shadow: $0 < 2) }
        case .balloons:
            return (0..<24).map { look(.balloons($0 % 2), eyes: .happy, legs: .dangling(wiggle: $0 % 2 == 0 ? -1 : 1), shadow: false) }
        case .beamUp:
            return (0..<15).map { look(.beam($0), eyes: .happy, legs: .dangling(wiggle: 0), shadow: false) }
        case .shrink, .random:
            return (0..<13).map { look(.shrink($0), eyes: .closed, shadow: $0 < 8) }
        }
    }

    /// Whether the pet itself is drawn in this finale frame.
    static func showsPet(_ look: Pose.FinaleLook) -> Bool {
        switch look {
        case .ashPile, .debris: return false
        case let .poof(f): return f < 2
        case let .shrink(f): return f < 12
        default: return true
        }
    }

    static func drawFinaleBehind(_ c: inout PixelCanvas, _ look: Pose.FinaleLook) {
        switch look {
        case let .balloons(f): drawBalloons(&c, bob: f)
        case let .beam(f): drawBeam(&c, frame: f)
        default: break
        }
    }

    /// Finale effects drawn over the pet on the effect layer (absolute layer coordinates).
    static func drawFinaleFront(_ c: inout PixelCanvas, _ look: Pose.FinaleLook) {
        c.originX = 0
        c.originY = 0
        switch look {
        case let .burning(f): drawBodyFire(&c, frame: f)
        case let .charred(f): drawSmokeWisps(&c, frame: f)
        case let .ashPile(f): drawAshPile(&c, frame: f)
        case let .debris(f): drawDebris(&c, frame: f)
        case let .poof(f): drawPoof(&c, frame: f)
        case let .beam(f): drawBeam(&c, frame: f, front: true)
        case let .shrink(f) where f >= 9: drawSparkle(&c, frame: f - 9)
        default: break
        }
    }

    /// Finale changes to the pet itself: charring, a white flash, dissolving, shrinking.
    static func applyFinaleColors(_ c: inout ColorCanvas, _ look: Pose.FinaleLook) {
        switch look {
        case let .charred(f):
            let ash = ColorCanvas.pack(paletteRGB(32)), char = ColorCanvas.pack(paletteRGB(33))
            c.recolorSolid { x, y in (x + y + f) % 4 == 0 ? ash : char }
        case .flash:
            c.recolorSolid { _, _ in ColorCanvas.pack(RGB(0xFFFFFF)) }
            c.outlineSolid(ColorCanvas.pack(paletteRGB(26)))
        case let .beam(f):
            // Dissolve the pet in a pattern that fills in over time.
            let cut = f - 4
            if cut > 0 { c.clearSolid { x, y in (x * 3 + y * 5) % 10 < cut } }
        case let .shrink(f):
            c.shrink(scale: max(1 - Double(f) / 11, 0), aroundX: Double(width) / 2, bottom: Double(groundRow))
        default:
            break
        }
    }

    /// Flames licking up from the pet's body (absolute coordinates: body is rows ~26-47).
    private static func drawBodyFire(_ c: inout PixelCanvas, frame f: Int) {
        let grow = min(f + 1, 4)
        for (i, base) in [9, 14, 19, 24, 29, 34].enumerated() {
            let h = 4 + grow * 2 + (i + f) % 3 * 2
            let top = 36 - h
            for y in top...36 {
                let t = Double(y - top) / Double(h)
                let w = Int((t * 2.5).rounded())
                let color: UInt8 = t < 0.35 ? 28 : (t < 0.7 ? 27 : 26)
                for x in (base - w)...(base + w) where (x + y + f) % 7 != 0 { c[x, y] = color }
            }
        }
    }

    private static func drawSmokeWisps(_ c: inout PixelCanvas, frame f: Int) {
        for (i, x) in [14, 22, 30].enumerated() {
            for k in 0..<4 { c[x + (k + i + f) % 2, 24 - k * 2 - f] = 30 }
        }
    }

    private static func drawAshPile(_ c: inout PixelCanvas, frame f: Int) {
        let g = c.height - 1
        // The pile shrinks as the wind takes it; flakes drift off to the right.
        let width = max(16 - f * 5, 0)
        if width > 0 {
            for row in 0..<3 {
                let w = width - row * 4
                guard w > 0 else { continue }
                for x in (22 - w / 2)...(22 + w / 2) { c[x, g - row] = (x + row) % 3 == 0 ? 33 : 32 }
            }
        }
        for k in 0..<(4 + f * 3) {
            let x = 24 + k * 2 + f * 4, y = g - 2 - (k * 7 + f * 3) % 9
            c[x, y] = k % 2 == 0 ? 32 : 30
        }
    }

    private static func drawDebris(_ c: inout PixelCanvas, frame f: Int) {
        let center = (x: 22.0, y: 36.0)
        let colors: [UInt8] = [21, 26, 7, 9, 6, 27, 23, 2]
        let r = Double(f) * 2.6 + 2
        for k in 0..<20 {
            let angle = Double(k) * 0.9 + Double(k % 3) * 0.4
            let speed = 0.6 + Double(k % 5) * 0.15
            let x = center.x + cos(angle) * r * speed
            let y = center.y - sin(angle) * r * speed + Double(f * f) * 0.12 // a little gravity
            let size = f < 6 ? 2 : 1
            c.pixelsFill(x: Int(x), y: Int(y), size: size, colors[k % colors.count])
        }
    }

    private static func drawPoof(_ c: inout PixelCanvas, frame f: Int) {
        let center = (x: 20, y: 36)
        let r = min(3 + f * 2, 13)
        let puffs = [(-6, 2), (6, 2), (0, -4), (-3, -1), (4, -2), (0, 4)]
        for (i, (dx, dy)) in puffs.enumerated() {
            let pr = max(r - 4 - (f > 6 ? (f - 6) * 2 : 0) + i % 2, 0)
            guard pr > 0 else { continue }
            let x = center.x + dx * (1 + f / 4), y = center.y + dy * (1 + f / 4) - f / 2
            c.pixelsDisc(cx: x, cy: y, r: pr + 1, 30)
            c.pixelsDisc(cx: x, cy: y, r: pr, 29)
        }
        if f >= 8 { // thinning out
            for y in 0..<c.height { for x in 0..<c.width where (x + y * 2 + f) % (14 - f) == 0 {
                c.pixels[y * c.width + x] = 0
            } }
        }
    }

    private static func drawBalloons(_ c: inout PixelCanvas, bob: Int) {
        // Body-space coordinates (origin set by caller); strings meet at the pet's back.
        let knot = (16, 12)
        let balloons: [(Int, Int, UInt8)] = [(8, -12, 21), (17, -15, 23), (26, -11, 26)]
        for (bx, by, color) in balloons {
            let y = by + (bx == 17 ? bob : -bob)
            PetArt.line(&c, from: (bx, y + 4), to: knot, 1)
            c.ellipse(cx: bx, cy: y, rx: 3, ry: 4, 1)
            c.ellipse(cx: bx, cy: y, rx: 2, ry: 3, color)
            c[bx - 1, y - 2] = 5
            c[bx, y + 5] = 1
        }
    }

    private static func drawBeam(_ c: inout PixelCanvas, frame f: Int, front: Bool = false) {
        let w = min(4 + f * 2, 16)
        for y in 0..<c.height {
            for x in (24 - w)...(24 + w) where x >= 0 && x < c.width {
                let edge = x == 24 - w || x == 24 + w
                if front {
                    // A few sparkles drifting up through the beam around the pet.
                    if y >= 18 && c.pixel(x, y) == 0 && (x * 5 + y * 3 + f * 7) % 23 == 0 { c.pixels[y * c.width + x] = 26 }
                } else {
                    c.pixels[y * c.width + x] = edge ? 37 : 34
                }
            }
        }
    }


    private static func drawSparkle(_ c: inout PixelCanvas, frame f: Int) {
        let r = 1 + f
        let cx = 24, cy = 44
        for i in -r...r { c.pixelsSet(cx + i, cy, 26); c.pixelsSet(cx, cy + i, 26) }
        c.pixelsSet(cx, cy, 5)
    }

    /// 3x5 digits for the countdown.
    static let digits: [Int: [String]] = [
        1: [".#.", "##.", ".#.", ".#.", "###"],
        2: ["##.", "..#", ".#.", "#..", "###"],
        3: ["##.", "..#", ".#.", "..#", "##."],
    ]

    /// A big outlined digit floating over the pet's head.
    static func drawCountdown(_ c: inout PixelCanvas, digit: Int) {
        guard let rows = digits[digit] else { return }
        let ox = 13, oy = -10 // body space, in the headroom
        var shape = Set<[Int]>()
        for (y, row) in rows.enumerated() {
            for (x, ch) in row.enumerated() where ch == "#" {
                for dy in 0..<2 { for dx in 0..<2 { shape.insert([ox + x * 2 + dx, oy + y * 2 + dy]) } }
            }
        }
        for p in shape { for (dx, dy) in [(-1, 0), (1, 0), (0, -1), (0, 1)] where !shape.contains([p[0] + dx, p[1] + dy]) {
            c[p[0] + dx, p[1] + dy] = 1
        } }
        for p in shape { c[p[0], p[1]] = digit == 1 ? 28 : 5 }
    }
}

extension PixelCanvas {
    /// Absolute-coordinate helpers (ignore the drawing origin).
    mutating func pixelsSet(_ x: Int, _ y: Int, _ color: UInt8) {
        if x >= 0 && y >= 0 && x < width && y < height { pixels[y * width + x] = color }
    }

    mutating func pixelsFill(x: Int, y: Int, size: Int, _ color: UInt8) {
        for dy in 0..<size { for dx in 0..<size { pixelsSet(x + dx, y + dy, color) } }
    }

    mutating func pixelsDisc(cx: Int, cy: Int, r: Int, _ color: UInt8) {
        for y in (cy - r)...(cy + r) { for x in (cx - r)...(cx + r) where (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r + r / 2 {
            pixelsSet(x, y, color)
        } }
    }
}
