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
    /// Props and effects drawn around the whole pet (parachute, flames…).
    public var gear: Gear = .none
    public var finale: FinaleLook = .none
    /// Explicit rest posture for folded legs (`auto` = sitting).
    public var posture: Posture = .auto
    public enum Posture: Hashable, Sendable { case auto, sitting, lying }
    /// Seasonal decoration (hat, pumpkin).
    public var seasonal: Seasonal = .none
    /// Quarter turns of the whole pet: 1 = head up (climbing), 2 = upside down, 3 = head down.
    public var rotation = 0

    public enum Gear: Hashable, Sendable {
        case none
        case parachute(sway: Int)
        case meteor(Int)
        case jetpack(Int)
        case impact(Int)
        case countdown(Int)
        case hearts(Int)
        case dirt(Int)
        case butterfly(Int)
        case scuffle(Int)
        case grip
        case alert
    }

    public init() {}
}

/// Original pixel-art pets, drawn from simple shapes at runtime. They face right; mirror for left.
public enum PetArt {
    /// Full sprite size, including room for effects above the pet.
    public static let width = 80
    public static let height = 80
    /// Effects and props are drawn on 48x48 indexed layers (pet "body space" 40x32 at this
    /// origin, ground on its row 31) and scaled onto the sprite.
    static let layerSize = 48
    static let bodyOrigin = (x: 4, y: 16)

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
        (0xFF, 0xE0, 0x5A, 255), // 26 flame yellow
        (0xFF, 0x8C, 0x2A, 255), // 27 flame orange
        (0xDE, 0x3E, 0x26, 255), // 28 flame red
        (0xE2, 0xDF, 0xE6, 255), // 29 smoke light
        (0xA6, 0xA1, 0xAD, 255), // 30 smoke dark
        (0x86, 0x8C, 0x98, 255), // 31 metal
        (0x5A, 0x54, 0x5C, 255), // 32 ash
        (0x33, 0x2E, 0x36, 255), // 33 char
        (0xFF, 0xF2, 0x9A, 90),  // 34 tractor beam (translucent)
        (0x8A, 0x5A, 0x36, 255), // 35 dirt
        (0x5E, 0x3B, 0x22, 255), // 36 dark dirt
        (0xFF, 0xE0, 0x5A, 170), // 37 tractor beam edge (translucent)
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
        case .parachute: return 1.5
        case .meteor, .jetpack: return 12
        case .impact: return 5
        case .countdown: return 1
        case .finale: return 10
        case .climb: return 6
        case .hang: return 2
        case .tumble: return 6.7
        case .dig: return 6
        case .butterfly: return 8
        case .yawn: return 2.5
        case .nuzzle: return 3
        case .chase, .flee: return 14
        case .follow: return 8
        case .playFight: return 8
        case .ride: return 2
        case .startled: return 8
        case .chaseCursor, .fetchTreat: return 14
        }
    }

    public static func frames(for behavior: Behavior, animal: Animal = .sheep,
                              finale: FinaleStyle = .vanish) -> [Pose] {
        if behavior == .finale { return finaleFrames(finale) }
        if animal.hops, [.walk, .follow, .butterfly].contains(behavior) {
            return withGear(hopFrames(height: 4), behavior == .butterfly ? { .butterfly($0) } : nil)
        }
        if animal.hops, [.run, .chase, .flee, .chaseCursor, .fetchTreat].contains(behavior) { return hopFrames(height: 8) }
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
        case .parachute: return [-1, 0, 1, 0].map(parachutePose)
        case .meteor: return (0..<3).map(meteorPose)
        case .jetpack: return (0..<2).map(jetpackPose)
        case .impact: return (0..<8).map(impactPose)
        case .countdown: return countdownFrames
        case .finale: return finaleFrames(finale)
        case .climb: return walkFrames.map { var p = $0; p.rotation = 1; p.shadow = false; p.earUp = true; return p }
        case .hang: return hangFrames
        case .tumble: return tumbleFrames
        case .dig: return digFrames
        case .butterfly: return withGear(walkFrames.map { var p = $0; p.headDY -= 1; p.eyes = .happy; return p }) { .butterfly($0) }
        case .yawn: return yawnFrames
        case .nuzzle: return nuzzleFrames
        case .chase: return runFrames.map { var p = $0; p.eyes = .happy; return p }
        case .flee: return runFrames.map { var p = $0; p.eyes = .wide; p.mouthOpen = true; return p }
        case .follow: return walkFrames
        case .playFight: return playFightFrames
        case .startled: return [0, 4, 6, 4, 2, 0].map { lift in
            make { $0.lift = lift; $0.eyes = .wide; $0.mouthOpen = true; $0.earUp = true; $0.legs = lift > 0 ? .spread : Pose().legs; $0.gear = .alert }
        }
        case .chaseCursor, .fetchTreat: return runFrames.map { var p = $0; p.eyes = .happy; return p }
        case .ride: return sitFrames.map { var p = $0; p.shadow = false; p.eyes = $0.earUp ? .happy : .open; return p }
        }
    }

    /// The pose to show `time` seconds into a behavior. `phase` (0..<1) desynchronizes
    /// blinking between pets.
    public static func pose(for behavior: Behavior, animal: Animal = .sheep, time: Double, phase: Double = 0,
                            finale: FinaleStyle = .vanish) -> Pose {
        let all = frames(for: behavior, animal: animal, finale: finale)
        let fps = behavior == .finale ? finaleFramesPerSecond(finale) : framesPerSecond(behavior)
        let index = Int(max(time, 0) * fps)
        // Countdowns and finales play once and hold their last frame.
        let once = behavior == .finale || behavior == .countdown
        var pose = all[once ? min(index, all.count - 1) : index % all.count]
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
            $0.posture = .lying
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

    /// Adds per-frame gear to a list of frames.
    private static func withGear(_ frames: [Pose], _ gear: ((Int) -> Pose.Gear)?) -> [Pose] {
        guard let gear else { return frames }
        return frames.enumerated().map { i, p in var q = p; q.gear = gear(i); return q }
    }


    private static let hangFrames: [Pose] = [-1, 1].map { w in
        make {
            $0.legs = .dangling(wiggle: w)
            $0.eyes = .wide
            $0.earUp = true
            $0.headDY = -2
            $0.bodyDY = 1
            $0.tailDY = w > 0 ? -1 : 0
            $0.shadow = false
            $0.gear = .grip
        }
    }

    /// Curled up and rolling forward (head goes down first), then upright again.
    private static let tumbleFrames: [Pose] = [0, 3, 2, 1, 0, 3, 2, 1].map { r in
        make {
            $0.legs = .folded
            $0.posture = .lying
            $0.bodyDY = 2
            $0.headDY = 2
            $0.eyes = .closed
            $0.rotation = r
            $0.shadow = r == 0
        }
    }

    /// Front paws scrabbling, dirt flying out behind.
    private static let digFrames: [Pose] = (0..<4).map { i in
        make {
            $0.legs = .standing(dx: [0, 0, i % 2 == 0 ? 1 : -1, i % 2 == 0 ? -1 : 1], lifted: [false, false, i % 2 == 0, i % 2 == 1])
            $0.headDY = 5
            $0.headDX = 1
            $0.bodyDY = 1
            $0.eyes = .happy
            $0.tailDY = i % 2 == 0 ? -1 : 0
            $0.gear = .dirt(i)
        }
    }

    private static let yawnFrames: [Pose] = (0..<4).map { i in
        make {
            $0.headDY = -1 - min(i, 2) / 2
            $0.eyes = .closed
            $0.mouthOpen = i > 0
            $0.earUp = false
        }
    }

    private static let nuzzleFrames: [Pose] = (0..<4).map { i in
        make {
            $0.headDX = 1
            $0.headDY = i % 2 == 0 ? 1 : 2
            $0.eyes = .happy
            $0.tailDY = i % 2 == 0 ? -1 : 0
            $0.gear = .hearts(i)
        }
    }

    /// Hopping about face to face, with a dust cloud between.
    private static let playFightFrames: [Pose] = [0, 3, 5, 2].enumerated().map { i, lift in
        make {
            $0.lift = lift
            $0.legs = lift > 0 ? .spread : .standing(dx: [0, 0, 0, 0], lifted: [false, false, false, false])
            $0.eyes = i % 2 == 0 ? .wide : .happy
            $0.mouthOpen = i % 2 == 0
            $0.earUp = true
            $0.gear = .scuffle(i)
        }
    }

    private static func parachutePose(_ sway: Int) -> Pose {
        make {
            $0.legs = .dangling(wiggle: sway)
            $0.eyes = .happy
            $0.earUp = true
            $0.shadow = false
            $0.gear = .parachute(sway: sway)
        }
    }

    private static func meteorPose(_ frame: Int) -> Pose {
        make {
            $0.legs = .spread
            $0.eyes = .wide
            $0.mouthOpen = true
            $0.earUp = true
            $0.shadow = false
            $0.gear = .meteor(frame)
        }
    }

    private static func jetpackPose(_ frame: Int) -> Pose {
        make {
            $0.legs = .dangling(wiggle: frame == 0 ? -1 : 1)
            $0.eyes = .happy
            $0.earUp = true
            $0.tailDY = -1
            $0.shadow = false
            $0.gear = .jetpack(frame)
        }
    }

    /// Dazed after a meteor landing: dust settles, stars circle.
    private static func impactPose(_ frame: Int) -> Pose {
        make {
            $0.legs = .folded
            $0.posture = .lying
            $0.bodyDY = frame < 2 ? 4 - frame : 2
            $0.headDY = 3
            $0.eyes = .closed
            $0.gear = .impact(frame)
        }
    }

    // MARK: Effect layers

    /// Ground row of the 48x48 effect layers' body space (see `bodyOrigin`).
    static let ground = 31
}
