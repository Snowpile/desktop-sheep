/// An indexed-color pixel image. Index 0 is transparent; see `SheepArt.palette`.
public struct PixelCanvas: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public private(set) var pixels: [UInt8]

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.pixels = Array(repeating: 0, count: width * height)
    }

    /// Row 0 is the top of the image.
    public subscript(x: Int, y: Int) -> UInt8 {
        get { (x >= 0 && y >= 0 && x < width && y < height) ? pixels[y * width + x] : 0 }
        set { if x >= 0 && y >= 0 && x < width && y < height { pixels[y * width + x] = newValue } }
    }

    public var isBlank: Bool { pixels.allSatisfy { $0 == 0 } }

    mutating func fill(x: Int, y: Int, width w: Int, height h: Int, _ color: UInt8) {
        for yy in y..<(y + h) { for xx in x..<(x + w) { self[xx, yy] = color } }
    }

    mutating func disc(cx: Int, cy: Int, r: Int, _ color: UInt8) {
        for yy in (cy - r)...(cy + r) {
            for xx in (cx - r)...(cx + r) {
                let dx = xx - cx, dy = yy - cy
                if dx * dx + dy * dy <= r * r + r / 2 { self[xx, yy] = color }
            }
        }
    }

    mutating func plot(_ points: [(Int, Int)], _ color: UInt8) {
        for (x, y) in points { self[x, y] = color }
    }
}

/// How the sheep looks in one animation frame.
public struct Pose: Hashable, Sendable {
    public enum Legs: Hashable, Sendable {
        /// Per-leg foot offsets (back-far, back-near, front-far, front-near) and which legs are lifted.
        case standing(dx: [Int], lifted: [Bool])
        case folded
        case spread
        case dangling(wiggle: Int)
    }
    public enum Eyes: Hashable, Sendable { case open, closed, wide }
    public enum Effect: Hashable, Sendable { case none, zzz(Int), bleat(Int), grass(Int) }

    public var legs: Legs = .standing(dx: [0, 0, 0, 0], lifted: [false, false, false, false])
    public var bodyDY = 0
    public var headDX = 0
    public var headDY = 0
    public var eyes: Eyes = .open
    public var mouthOpen = false
    public var effect: Effect = .none

    public init() {}
}

/// Original pixel-art sheep, drawn from simple shapes at runtime. Faces right; mirror for left.
public enum SheepArt {
    public static let width = 40
    public static let height = 32

    /// RGBA colors for each palette index.
    public static let palette: [(r: UInt8, g: UInt8, b: UInt8, a: UInt8)] = [
        (0, 0, 0, 0),            // 0 transparent
        (0x2A, 0x24, 0x30, 255), // 1 outline / hooves
        (0xF7, 0xF4, 0xEC, 255), // 2 wool
        (0xD9, 0xD2, 0xC3, 255), // 3 wool shadow
        (0x4B, 0x42, 0x50, 255), // 4 face and legs
        (0xFF, 0xFF, 0xFF, 255), // 5 eye
        (0xF1, 0x9C, 0xAB, 255), // 6 pink (ear, mouth)
        (0x6A, 0xBF, 0x4B, 255), // 7 grass
        (0x3F, 0x8A, 0x35, 255), // 8 dark grass
        (0x9C, 0xC4, 0xFF, 255), // 9 dream blue
    ]

    // MARK: Animation

    /// Frames per second for each behavior's animation.
    public static func framesPerSecond(_ behavior: Behavior) -> Double {
        switch behavior {
        case .walk: return 6
        case .run: return 12
        case .sleep: return 1.2
        case .eat: return 3
        case .bleat: return 2.5
        case .dragged: return 5
        default: return 1
        }
    }

    public static func frames(for behavior: Behavior) -> [Pose] {
        switch behavior {
        case .stand: return [Pose()]
        case .walk: return walkFrames
        case .run: return runFrames
        case .sit: return [sitPose(effect: .none, sleeping: false)]
        case .sleep: return [sitPose(effect: .zzz(0), sleeping: true), sitPose(effect: .zzz(1), sleeping: true)]
        case .eat: return [eatPose(0), eatPose(1)]
        case .bleat: return [bleatPose(0), bleatPose(1), bleatPose(2)]
        case .fall: return [fallPose]
        case .dragged: return [draggedPose(0), draggedPose(1)]
        }
    }

    public static func pose(for behavior: Behavior, time: Double) -> Pose {
        let all = frames(for: behavior)
        let index = Int(max(time, 0) * framesPerSecond(behavior)) % all.count
        return all[index]
    }

    private static let walkFrames: [Pose] = {
        // Diagonal leg pairs swing together: (back-far, front-near) and (back-near, front-far).
        let steps: [([Int], [Bool], Int)] = [
            ([1, -1, -1, 1], [false, false, false, false], 0),
            ([0, 0, 0, 0], [true, false, false, true], -1),
            ([-1, 1, 1, -1], [false, false, false, false], 0),
            ([0, 0, 0, 0], [false, true, true, false], -1),
        ]
        return steps.map { dx, lifted, bob in
            var p = Pose()
            p.legs = .standing(dx: dx, lifted: lifted)
            p.bodyDY = bob
            p.headDY = bob
            return p
        }
    }()

    private static let runFrames: [Pose] = {
        let steps: [([Int], [Bool], Int)] = [
            ([-2, -2, 2, 2], [false, false, false, false], 0),
            ([-1, -1, 1, 1], [true, true, true, true], -2),
            ([1, 1, -1, -1], [false, false, false, false], -1),
            ([0, 0, 0, 0], [true, true, false, false], -1),
        ]
        return steps.map { dx, lifted, bob in
            var p = Pose()
            p.legs = .standing(dx: dx, lifted: lifted)
            p.bodyDY = bob
            p.headDY = bob + 1
            p.headDX = 1
            return p
        }
    }()

    private static func sitPose(effect: Pose.Effect, sleeping: Bool) -> Pose {
        var p = Pose()
        p.legs = .folded
        p.bodyDY = 4
        p.headDY = sleeping ? 6 : 3
        p.headDX = sleeping ? -1 : 0
        p.eyes = sleeping ? .closed : .open
        p.effect = effect
        return p
    }

    private static func eatPose(_ frame: Int) -> Pose {
        var p = Pose()
        p.headDY = 7
        p.headDX = 1
        p.mouthOpen = frame == 1
        p.effect = .grass(frame)
        return p
    }

    private static func bleatPose(_ frame: Int) -> Pose {
        var p = Pose()
        p.headDY = -1
        p.mouthOpen = frame > 0
        p.effect = frame > 0 ? .bleat(frame - 1) : .none
        return p
    }

    private static let fallPose: Pose = {
        var p = Pose()
        p.legs = .spread
        p.eyes = .wide
        p.mouthOpen = true
        return p
    }()

    private static func draggedPose(_ frame: Int) -> Pose {
        var p = Pose()
        p.legs = .dangling(wiggle: frame == 0 ? -1 : 1)
        p.eyes = .wide
        p.bodyDY = -1
        p.headDY = -1
        return p
    }

    // MARK: Drawing

    private static let ground = 31
    private static let legX = [8, 11, 21, 24]

    public static func render(_ pose: Pose) -> PixelCanvas {
        var c = PixelCanvas(width: width, height: height)
        let by = pose.bodyDY
        let hx = pose.headDX + 2, hy = pose.headDY // head pokes out in front of the wool

        if pose.legs != .folded { drawLegs(&c, pose.legs, bodyDY: by) }

        // Wool body: a cloud of overlapping puffs.
        let puffs: [(Int, Int, Int)] = [
            (12, 19, 5), (17, 17, 5), (22, 18, 5), (13, 23, 4), (19, 23, 4), (25, 21, 4), (8, 21, 4), (24, 23, 3),
        ]
        for (x, y, r) in puffs { c.disc(cx: x, cy: y + by, r: r, 2) }
        // Shadowed belly and a few curls.
        for y in 0..<height {
            for x in 0..<width where c[x, y] == 2 {
                if y >= 24 + by || (x * 7 + y * 3) % 13 == 0 { c[x, y] = 3 }
            }
        }

        // Neck puff joining head to body, then the face, then a wool tuft on top.
        c.disc(cx: 26, cy: 16 + by + min(hy, 3), r: 3, 2)
        drawFace(&c, dx: hx, dy: hy)
        c.disc(cx: 28 + hx, cy: 13 + hy, r: 2, 2)
        c[30 + hx, 13 + hy] = 2

        outlineWool(&c)
        if pose.legs == .folded { drawLegs(&c, pose.legs, bodyDY: by) }

        // Ear (sticks out behind the head), eye and mouth.
        c.plot([(24 + hx, 17 + hy), (25 + hx, 17 + hy), (23 + hx, 17 + hy)], 4)
        c.plot([(24 + hx, 18 + hy), (25 + hx, 18 + hy)], 6)
        switch pose.eyes {
        case .open:
            c[29 + hx, 17 + hy] = 5
        case .wide:
            c.plot([(29 + hx, 16 + hy), (29 + hx, 17 + hy), (30 + hx, 17 + hy)], 5)
            c[30 + hx, 16 + hy] = 1
        case .closed:
            c.plot([(28 + hx, 18 + hy), (29 + hx, 18 + hy)], 3)
        }
        c[31 + hx, 19 + hy] = 1 // nostril
        if pose.mouthOpen {
            c.plot([(29 + hx, 21 + hy), (30 + hx, 21 + hy), (30 + hx, 22 + hy)], 6)
        }

        drawEffect(&c, pose.effect, headDX: hx, headDY: hy)
        return c
    }

    private static func drawFace(_ c: inout PixelCanvas, dx: Int, dy: Int) {
        let rows: [(Int, Int, Int)] = [ // (row, fromX, toX)
            (14, 27, 30), (15, 26, 31), (16, 26, 31), (17, 26, 31), (18, 26, 31),
            (19, 26, 32), (20, 27, 32), (21, 27, 31), (22, 28, 30),
        ]
        for (row, from, to) in rows {
            for x in from...to { c[x + dx, row + dy] = 4 }
        }
    }

    private static func drawLegs(_ c: inout PixelCanvas, _ legs: Pose.Legs, bodyDY: Int) {
        let top = 25 + bodyDY
        switch legs {
        case let .standing(dx, lifted):
            for i in 0..<4 {
                let color: UInt8 = i % 2 == 0 ? 1 : 4 // far legs darker
                let bottom = ground - (lifted[i] ? 1 : 0)
                for y in top...bottom {
                    let shift = y > top + 2 ? dx[i] : 0
                    c.fill(x: legX[i] + shift, y: y, width: 2, height: 1, color)
                }
                c.fill(x: legX[i] + dx[i], y: bottom, width: 2, height: 1, 1) // hoof
            }
        case .folded:
            // Front hooves tucked under the chest; back legs hidden by wool.
            c.fill(x: 21, y: ground - 1, width: 3, height: 2, 1)
            c.fill(x: 24, y: ground - 1, width: 3, height: 2, 4)
            c.fill(x: 26, y: ground, width: 1, height: 1, 1)
        case .spread:
            for i in 0..<4 {
                let out = i < 2 ? -1 : 1
                let color: UInt8 = i % 2 == 0 ? 1 : 4
                for step in 0..<5 {
                    c.fill(x: legX[i] + out * (step / 2), y: top + step, width: 2, height: 1, color)
                }
                c.fill(x: legX[i] + out * 2, y: top + 5, width: 2, height: 1, 1)
            }
        case let .dangling(wiggle):
            for i in 0..<4 {
                let color: UInt8 = i % 2 == 0 ? 1 : 4
                let w = i % 2 == 0 ? wiggle : -wiggle
                for y in top...(ground) {
                    c.fill(x: legX[i] + (y > top + 3 ? w : 0), y: y, width: 2, height: 1, color)
                }
                c.fill(x: legX[i] + w, y: ground, width: 2, height: 1, 1)
            }
        }
    }

    /// Draws a dark outline around wool wherever it meets transparency.
    private static func outlineWool(_ c: inout PixelCanvas) {
        let source = c
        for y in 0..<c.height {
            for x in 0..<c.width where source[x, y] == 0 {
                let neighbors = [source[x - 1, y], source[x + 1, y], source[x, y - 1], source[x, y + 1]]
                if neighbors.contains(where: { $0 == 2 || $0 == 3 }) { c[x, y] = 1 }
            }
        }
    }

    /// Pixels of a letter "z" in an n-by-n box.
    private static func zShape(_ n: Int) -> [(Int, Int)] {
        var points: [(Int, Int)] = []
        for i in 0..<n { points += [(i, 0), (i, n - 1)] }
        for i in 1..<(n - 1) { points.append((n - 1 - i, i)) }
        return points
    }

    private static func drawEffect(_ c: inout PixelCanvas, _ effect: Pose.Effect, headDX hx: Int, headDY hy: Int) {
        switch effect {
        case .none:
            break
        case let .zzz(frame):
            // A small z, and a bigger one drifting up on alternate frames.
            let small = zShape(4), big = zShape(5)
            let (sx, sy) = frame == 0 ? (31, 10) : (32, 8)
            c.plot(small.map { ($0.0 + sx, $0.1 + sy) }, 9)
            if frame == 1 { c.plot(big.map { ($0.0 + 35, $0.1 + 1) }, 9) }
        case let .bleat(frame):
            let mouthY = 21 + hy, mx = 33 + hx
            c.plot([(mx, mouthY - 2), (mx + 1, mouthY - 1), (mx + 1, mouthY), (mx, mouthY + 1)], 1)
            if frame >= 1 {
                c.plot([(mx + 2, mouthY - 4), (mx + 3, mouthY - 3), (mx + 4, mouthY - 2), (mx + 4, mouthY - 1),
                        (mx + 4, mouthY), (mx + 3, mouthY + 1), (mx + 2, mouthY + 2)], 1)
            }
        case let .grass(frame):
            // Tufts in front of the mouth; one blade gets shorter as it's nibbled.
            let base = ground
            let blades: [(Int, Int, UInt8)] = [(31, 3, 8), (32, 5, 7), (33, 4, 8), (34, frame == 0 ? 6 : 3, 7), (35, 3, 8), (37, 2, 7)]
            for (x, h, color) in blades {
                for y in (base - h + 1)...base { c[x + hx - 1, y] = color }
            }
        }
    }
}
