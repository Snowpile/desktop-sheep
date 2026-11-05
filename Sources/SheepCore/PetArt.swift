/// An indexed-color pixel image. Index 0 is transparent; see `PetArt.palette`.
///
/// Drawing goes through an origin offset so a pet can be drawn in its own 40x32 "body space"
/// while effects (parachutes, flames, z's) extend above and around it.
public struct PixelCanvas: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public internal(set) var pixels: [UInt8]
    var originX = 0
    var originY = 0

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.pixels = Array(repeating: 0, count: width * height)
    }

    /// Absolute pixel access, row 0 at the top.
    public func pixel(_ x: Int, _ y: Int) -> UInt8 {
        (x >= 0 && y >= 0 && x < width && y < height) ? pixels[y * width + x] : 0
    }

    /// Pixel access relative to the current drawing origin.
    public subscript(x: Int, y: Int) -> UInt8 {
        get { pixel(x + originX, y + originY) }
        set {
            let ax = x + originX, ay = y + originY
            if ax >= 0 && ay >= 0 && ax < width && ay < height { pixels[ay * width + ax] = newValue }
        }
    }

    public var isBlank: Bool { pixels.allSatisfy { $0 == 0 } }

    mutating func fill(x: Int, y: Int, width w: Int, height h: Int, _ color: UInt8) {
        guard w > 0, h > 0 else { return }
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

    /// Filled ellipse with radii `rx`, `ry`.
    mutating func ellipse(cx: Int, cy: Int, rx: Int, ry: Int, _ color: UInt8) {
        guard rx > 0, ry > 0 else { return }
        for yy in (cy - ry)...(cy + ry) {
            for xx in (cx - rx)...(cx + rx) {
                let nx = Double(xx - cx) / (Double(rx) + 0.5), ny = Double(yy - cy) / (Double(ry) + 0.5)
                if nx * nx + ny * ny <= 1 { self[xx, yy] = color }
            }
        }
    }

    mutating func plot(_ points: [(Int, Int)], _ color: UInt8) {
        for (x, y) in points { self[x, y] = color }
    }
}

/// How the pet looks in one animation frame.
public struct Pose: Hashable, Sendable {
    public enum Legs: Hashable, Sendable {
        /// Per-leg foot offsets (back-far, back-near, front-far, front-near) and which legs are lifted.
        case standing(dx: [Int], lifted: [Bool])
        case folded
        case spread
        case dangling(wiggle: Int)
    }
    public enum Eyes: Hashable, Sendable { case open, closed, wide, happy }
    public enum Effect: Hashable, Sendable { case none, zzz(Int), call(Int), food(Int) }

    public var legs: Legs = .standing(dx: [0, 0, 0, 0], lifted: [false, false, false, false])
    public var bodyDY = 0
    public var headDX = 0
    public var headDY = 0
    public var eyes: Eyes = .open
    public var mouthOpen = false
    /// Ear raised (flick) instead of resting.
    public var earUp = false
    /// Tail offset in pixels (wag).
    public var tailDY = 0
    /// Whole pet raised off the ground by this many pixels (hops); the shadow stays put.
    public var lift = 0
    /// Soft shadow on the ground (only while standing on something).
    public var shadow = true
    public var effect: Effect = .none

    public init() {}
}

/// Original pixel-art pets, drawn from simple shapes at runtime. They face right; mirror for left.
public enum PetArt {
    /// Full sprite size, including room for effects above the pet.
    public static let width = 48
    public static let height = 48
    /// Where the pet's 40x32 body space sits inside the sprite (its bottom row is the sprite's bottom).
    public static let bodyOrigin = (x: 4, y: 16)
    public static let bodyWidth = 40
    public static let bodyHeight = 32

    /// RGBA colors for each palette index.
    public static let palette: [(r: UInt8, g: UInt8, b: UInt8, a: UInt8)] = [
        (0, 0, 0, 0),            // 0 transparent
        (0x2A, 0x24, 0x30, 255), // 1 outline / hooves
        (0xF4, 0xF0, 0xE6, 255), // 2 wool
        (0xD6, 0xCE, 0xBE, 255), // 3 wool shadow
        (0x4B, 0x42, 0x50, 255), // 4 face and legs
        (0xFF, 0xFF, 0xFF, 255), // 5 eye shine / wool highlight
        (0xF1, 0x9C, 0xAB, 255), // 6 pink (ear, mouth, blush)
        (0x6A, 0xBF, 0x4B, 255), // 7 grass
        (0x3F, 0x8A, 0x35, 255), // 8 dark grass
        (0x9C, 0xC4, 0xFF, 255), // 9 dream blue
        (0x10, 0x10, 0x18, 70),  // 10 ground shadow (translucent)
        (0x6E, 0x63, 0x73, 255), // 11 face highlight
        (0xE9, 0x9A, 0x4E, 255), // 12 cat orange
        (0xBF, 0x6A, 0x2C, 255), // 13 cat stripes
        (0xFB, 0xEC, 0xD5, 255), // 14 cream
        (0xB9, 0x82, 0x4C, 255), // 15 dog brown
        (0x6F, 0x48, 0x2B, 255), // 16 dog dark brown
        (0xC4, 0xBE, 0xCA, 255), // 17 bunny gray
        (0x93, 0x8B, 0x9C, 255), // 18 bunny dark gray
        (0xC8, 0x52, 0x2B, 255), // 19 red panda rust
        (0x4A, 0x22, 0x18, 255), // 20 red panda dark
        (0xD8, 0x3C, 0x4A, 255), // 21 collar red
        (0xF0, 0x84, 0x22, 255), // 22 carrot orange
        (0x7F, 0xB7, 0xD9, 255), // 23 fish blue
        (0xF2, 0xE6, 0xCC, 255), // 24 bone
        (0xE8, 0xB0, 0x7A, 255), // 25 tail ring tan
    ]

    /// Fully opaque palette indices (used for hit testing; the shadow doesn't count).
    public static func isSolid(_ index: UInt8) -> Bool {
        Int(index) < palette.count && palette[Int(index)].a == 255
    }

    // MARK: Animation

    /// Frames per second for each behavior's animation.
    public static func framesPerSecond(_ behavior: Behavior) -> Double {
        switch behavior {
        case .walk: return 8
        case .run: return 14
        case .sleep: return 1.5
        case .eat: return 4
        case .call: return 4
        case .dragged: return 6
        case .stand, .sit: return 2
        case .fall: return 1
        }
    }

    public static func frames(for behavior: Behavior, animal: Animal = .sheep) -> [Pose] {
        if animal.hops, behavior == .walk { return hopFrames(height: 4) }
        if animal.hops, behavior == .run { return hopFrames(height: 8) }
        switch behavior {
        case .stand: return standFrames
        case .walk: return walkFrames
        case .run: return runFrames
        case .sit: return sitFrames
        case .sleep: return sleepFrames
        case .eat: return eatFrames
        case .call: return bleatFrames
        case .fall: return [fallPose]
        case .dragged: return [draggedPose(-1), draggedPose(1)]
        }
    }

    /// The pose to show `time` seconds into a behavior. `phase` (0..<1) desynchronizes
    /// blinking between pets.
    public static func pose(for behavior: Behavior, animal: Animal = .sheep, time: Double, phase: Double = 0) -> Pose {
        let all = frames(for: behavior, animal: animal)
        var pose = all[Int(max(time, 0) * framesPerSecond(behavior)) % all.count]
        if pose.eyes == .open && isBlinking(time: time, phase: phase) { pose.eyes = .closed }
        return pose
    }

    /// Blinks for 0.15 s every 3.7 s.
    public static func isBlinking(time: Double, phase: Double) -> Bool {
        (max(time, 0) + phase * 3.7).truncatingRemainder(dividingBy: 3.7) > 3.55
    }

    /// A bunny hop: crouch, spring up, land. Movement happens only while `lift > 0`.
    private static func hopFrames(height: Int) -> [Pose] {
        let lifts = [0, height / 2, height, height, height / 2, 0]
        return lifts.enumerated().map { i, lift in
            make {
                $0.lift = lift
                $0.legs = lift > 0 ? .spread : .standing(dx: [0, 0, 0, 0], lifted: [false, false, false, false])
                $0.bodyDY = i == 0 ? 1 : 0
                $0.earUp = lift > 0
                $0.tailDY = lift > 0 ? -1 : 0
            }
        }
    }

    private static func make(_ change: (inout Pose) -> Void) -> Pose {
        var p = Pose()
        change(&p)
        return p
    }

    /// Mostly still; an ear flick and tail twitch now and then.
    private static let standFrames: [Pose] = {
        var frames = Array(repeating: Pose(), count: 6)
        frames[3].earUp = true
        frames[4].tailDY = -1
        return frames
    }()

    private static let walkFrames: [Pose] = {
        // Diagonal leg pairs swing together: (back-far, front-near) and (back-near, front-far).
        let steps: [([Int], [Bool], Int)] = [
            ([1, -1, -1, 1], [false, false, false, false], 0),
            ([1, -1, -1, 1], [false, true, true, false], 0),
            ([0, 0, 0, 0], [true, false, false, true], -1),
            ([-1, 1, 1, -1], [false, false, false, false], 0),
            ([-1, 1, 1, -1], [true, false, false, true], 0),
            ([0, 0, 0, 0], [false, true, true, false], -1),
        ]
        return steps.enumerated().map { i, step in
            make {
                $0.legs = .standing(dx: step.0, lifted: step.1)
                $0.bodyDY = step.2
                $0.headDY = step.2 + (i % 3 == 1 ? 1 : 0)
                $0.tailDY = i % 2 == 0 ? 0 : -1
            }
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
            make {
                $0.legs = .standing(dx: dx, lifted: lifted)
                $0.bodyDY = bob
                $0.headDY = bob + 1
                $0.headDX = 1
                $0.earUp = true
                $0.tailDY = -1
            }
        }
    }()

    private static let sitFrames: [Pose] = (0..<6).map { i in
        make {
            $0.legs = .folded
            $0.bodyDY = 4
            $0.headDY = 3
            $0.earUp = i == 4
        }
    }

    /// Slow breathing (body rises and falls) with drifting z's.
    private static let sleepFrames: [Pose] = (0..<4).map { i in
        make {
            $0.legs = .folded
            $0.bodyDY = i % 2 == 0 ? 4 : 3
            $0.headDY = 6
            $0.headDX = -1
            $0.eyes = .closed
            $0.effect = .zzz(i)
        }
    }

    /// Head down, chewing.
    private static let eatFrames: [Pose] = (0..<4).map { i in
        make {
            $0.headDY = i == 3 ? 6 : 7
            $0.headDX = 1
            $0.mouthOpen = i == 1
            $0.effect = .food(i)
            $0.tailDY = i == 2 ? -1 : 0
        }
    }

    private static let bleatFrames: [Pose] = [
        make { $0.headDY = 0 },
        make { $0.headDY = -1; $0.earUp = true },
        make { $0.headDY = -2; $0.mouthOpen = true; $0.eyes = .happy; $0.earUp = true; $0.effect = .call(0) },
        make { $0.headDY = -2; $0.mouthOpen = true; $0.eyes = .happy; $0.earUp = true; $0.effect = .call(1) },
        make { $0.headDY = -2; $0.mouthOpen = true; $0.eyes = .happy; $0.earUp = true; $0.effect = .call(2) },
    ]

    private static let fallPose = make {
        $0.legs = .spread
        $0.eyes = .wide
        $0.mouthOpen = true
        $0.earUp = true
        $0.shadow = false
    }

    private static func draggedPose(_ wiggle: Int) -> Pose {
        make {
            $0.legs = .dangling(wiggle: wiggle)
            $0.eyes = .wide
            $0.bodyDY = -1
            $0.headDY = -1
            $0.earUp = wiggle > 0
            $0.tailDY = wiggle > 0 ? -1 : 0
            $0.shadow = false
        }
    }

    // MARK: Drawing (body space: 40x32, ground on row 31)

    static let ground = 31
    private static let legX = [8, 11, 21, 24]

    public static func render(_ pose: Pose, animal: Animal = .sheep) -> PixelCanvas {
        var c = PixelCanvas(width: width, height: height)
        c.originX = bodyOrigin.x
        c.originY = bodyOrigin.y
        if pose.shadow { c.fill(x: 4, y: ground, width: 28, height: 1, 10) }
        c.originY -= pose.lift
        if animal == .sheep { renderSheep(&c, pose) } else { renderCritter(&c, pose, animal) }
        c.originX = 0
        c.originY = 0
        return c
    }

    private static func renderSheep(_ c: inout PixelCanvas, _ pose: Pose) {
        let by = pose.bodyDY
        let hx = pose.headDX + 2, hy = pose.headDY // head pokes out in front of the wool

        if pose.legs != .folded { drawLegs(&c, pose.legs, bodyDY: by) }

        // Tail: a small wool puff at the back.
        c.disc(cx: 4, cy: 19 + by + pose.tailDY, r: 2, 2)

        // Wool body: a cloud of overlapping puffs.
        let puffs: [(Int, Int, Int)] = [
            (12, 19, 5), (17, 17, 5), (22, 18, 5), (13, 23, 4), (19, 23, 4), (25, 21, 4), (8, 21, 4), (24, 23, 3),
        ]
        for (x, y, r) in puffs { c.disc(cx: x, cy: y + by, r: r, 2) }
        // Shadowed belly and a few curls.
        for y in 0..<bodyHeight {
            for x in 0..<bodyWidth where c[x, y] == 2 {
                if y >= 24 + by || (x * 7 + y * 3) % 13 == 0 { c[x, y] = 3 }
            }
        }

        // Neck puff joining head to body, then the face, then a wool tuft on top.
        c.disc(cx: 26, cy: 16 + by + min(hy, 3), r: 3, 2)
        drawFace(&c, dx: hx, dy: hy)
        c.disc(cx: 28 + hx, cy: 13 + hy, r: 2, 2)
        c[30 + hx, 13 + hy] = 2

        outlineWool(&c)
        highlightWool(&c)
        if pose.legs == .folded { drawLegs(&c, pose.legs, bodyDY: by) }

        drawEar(&c, up: pose.earUp, hx: hx, hy: hy)
        drawEyes(&c, pose.eyes, hx: hx, hy: hy)
        c[28 + hx, 20 + hy] = 6 // blush
        c[31 + hx, 19 + hy] = 1 // nostril
        if pose.mouthOpen {
            c.plot([(29 + hx, 21 + hy), (30 + hx, 21 + hy), (30 + hx, 22 + hy)], 6)
        }

        drawEffect(&c, pose.effect, animal: .sheep, callX: 33 + hx, callY: 21 + hy, foodX: 30 + hx)
    }

    private static func drawFace(_ c: inout PixelCanvas, dx: Int, dy: Int) {
        let rows: [(Int, Int, Int)] = [ // (row, fromX, toX)
            (14, 27, 30), (15, 26, 31), (16, 26, 31), (17, 26, 31), (18, 26, 31),
            (19, 26, 32), (20, 27, 32), (21, 27, 31), (22, 28, 30),
        ]
        for (row, from, to) in rows {
            for x in from...to { c[x + dx, row + dy] = 4 }
        }
        // A lighter muzzle gives the face some shape.
        c.plot([(31 + dx, 20 + dy), (32 + dx, 20 + dy), (31 + dx, 21 + dy)], 11)
    }

    private static func drawEar(_ c: inout PixelCanvas, up: Bool, hx: Int, hy: Int) {
        if up {
            c.plot([(24 + hx, 15 + hy), (25 + hx, 15 + hy), (23 + hx, 14 + hy), (25 + hx, 16 + hy)], 4)
            c.plot([(24 + hx, 16 + hy)], 6)
        } else {
            c.plot([(24 + hx, 17 + hy), (25 + hx, 17 + hy), (23 + hx, 17 + hy), (22 + hx, 18 + hy)], 4)
            c.plot([(24 + hx, 18 + hy), (25 + hx, 18 + hy)], 6)
        }
    }

    private static func drawEyes(_ c: inout PixelCanvas, _ eyes: Pose.Eyes, hx: Int, hy: Int) {
        switch eyes {
        case .open:
            c.plot([(29 + hx, 16 + hy), (29 + hx, 17 + hy)], 5)
            c[30 + hx, 17 + hy] = 1
        case .wide:
            c.plot([(29 + hx, 16 + hy), (29 + hx, 17 + hy), (30 + hx, 16 + hy), (30 + hx, 17 + hy)], 5)
            c[30 + hx, 17 + hy] = 1
        case .closed:
            c.plot([(28 + hx, 17 + hy), (29 + hx, 17 + hy), (30 + hx, 17 + hy)], 11)
        case .happy:
            c.plot([(28 + hx, 17 + hy), (29 + hx, 16 + hy), (30 + hx, 17 + hy)], 11)
        }
    }

    static func drawLegs(_ c: inout PixelCanvas, _ legs: Pose.Legs, bodyDY: Int,
                         near: UInt8 = 4, far: UInt8 = 1, paw: UInt8 = 1) {
        let top = 25 + bodyDY
        switch legs {
        case let .standing(dx, lifted):
            for i in 0..<4 {
                let color = i % 2 == 0 ? far : near // far legs darker
                let bottom = ground - (lifted[i] ? 1 : 0)
                for y in top...bottom {
                    let shift = y > top + 2 ? dx[i] : 0
                    c.fill(x: legX[i] + shift, y: y, width: 2, height: 1, color)
                }
                c.fill(x: legX[i] + dx[i], y: bottom, width: 2, height: 1, paw) // hoof
            }
        case .folded:
            // Front hooves tucked under the chest; back legs hidden by wool.
            c.fill(x: 21, y: ground - 1, width: 3, height: 2, far)
            c.fill(x: 24, y: ground - 1, width: 3, height: 2, near)
            c.fill(x: 26, y: ground, width: 1, height: 1, paw)
        case .spread:
            for i in 0..<4 {
                let out = i < 2 ? -1 : 1
                let color = i % 2 == 0 ? far : near
                for step in 0..<5 {
                    c.fill(x: legX[i] + out * (step / 2), y: top + step, width: 2, height: 1, color)
                }
                c.fill(x: legX[i] + out * 2, y: top + 5, width: 2, height: 1, paw)
            }
        case let .dangling(wiggle):
            for i in 0..<4 {
                let color = i % 2 == 0 ? far : near
                let w = i % 2 == 0 ? wiggle : -wiggle
                for y in top...ground {
                    c.fill(x: legX[i] + (y > top + 3 ? w : 0), y: y, width: 2, height: 1, color)
                }
                c.fill(x: legX[i] + w, y: ground, width: 2, height: 1, paw)
            }
        }
    }

    /// Draws a dark outline around wool wherever it meets transparency or shadow.
    private static func outlineWool(_ c: inout PixelCanvas) {
        let source = c
        for y in 0..<height {
            for x in 0..<width where source.pixel(x, y) == 0 || source.pixel(x, y) == 10 {
                let neighbors = [source.pixel(x - 1, y), source.pixel(x + 1, y), source.pixel(x, y - 1), source.pixel(x, y + 1)]
                if neighbors.contains(where: { $0 == 2 || $0 == 3 }) { c.pixels[y * width + x] = 1 }
            }
        }
    }

    /// Bright pixels just under the outline along the top of each wool bump, as if lit from above.
    private static func highlightWool(_ c: inout PixelCanvas) {
        let source = c
        for y in 1..<height {
            for x in 0..<width where source.pixel(x, y) == 2 && source.pixel(x, y - 1) == 1 && x % 3 != 0 {
                c.pixels[y * width + x] = 5
            }
        }
    }

    /// Pixels of a letter "z" in an n-by-n box.
    static func zShape(_ n: Int) -> [(Int, Int)] {
        var points: [(Int, Int)] = []
        for i in 0..<n { points += [(i, 0), (i, n - 1)] }
        for i in 1..<(n - 1) { points.append((n - 1 - i, i)) }
        return points
    }

    /// Draws effects shared by all animals. `callX/Y` is just in front of the mouth; `foodX` is
    /// where food sits on the ground.
    static func drawEffect(_ c: inout PixelCanvas, _ effect: Pose.Effect, animal: Animal,
                           callX mx: Int, callY mouthY: Int, foodX: Int) {
        switch effect {
        case .none:
            break
        case let .zzz(frame):
            // Up to three z's, rising and growing; they bob one pixel each frame.
            let spots = [(33, 9, 3), (36, 3, 4), (38, -4, 5)]
            for (i, spot) in spots.enumerated() where i <= frame % 4 {
                let rise = frame % 2
                c.plot(zShape(spot.2).map { ($0.0 + spot.0, $0.1 + spot.1 - rise) }, 9)
            }
        case let .call(frame) where animal != .sheep:
            drawCall(&c, animal, frame: frame, x: mx, y: mouthY)
        case let .call(frame):
            c.plot([(mx, mouthY - 2), (mx + 1, mouthY - 1), (mx + 1, mouthY), (mx, mouthY + 1)], 1)
            if frame >= 1 {
                c.plot([(mx + 2, mouthY - 4), (mx + 3, mouthY - 3), (mx + 4, mouthY - 2), (mx + 4, mouthY - 1),
                        (mx + 4, mouthY), (mx + 3, mouthY + 1), (mx + 2, mouthY + 2)], 1)
            }
            if frame >= 2 {
                c.plot([(mx + 5, mouthY - 6), (mx + 6, mouthY - 5), (mx + 7, mouthY - 3), (mx + 7, mouthY - 2),
                        (mx + 7, mouthY - 1), (mx + 7, mouthY), (mx + 6, mouthY + 2), (mx + 5, mouthY + 3)], 1)
            }
        case let .food(frame) where animal != .sheep:
            drawFood(&c, animal, frame: frame, x: foodX)
        case let .food(frame):
            // Tufts in front of the mouth; one blade gets shorter as it's nibbled.
            let blades: [(Int, Int, UInt8)] = [
                (31, 3, 8), (32, 5, 7), (33, 4, 8), (34, frame % 2 == 0 ? 6 : 4, 7), (35, 3, 8), (37, 2, 7), (38, 3, 8),
            ]
            for (x, h, color) in blades {
                for y in (ground - h + 1)...ground { c[x + foodX - 31, y] = color }
            }
        }
    }
}
