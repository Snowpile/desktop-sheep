import Foundation

/// What the pet is currently doing.
public enum Behavior: String, CaseIterable, Codable, Sendable {
    case stand, walk, run, sit, sleep, eat, call, fall, dragged
    /// Arrivals (see `EntryStyle`), and the dazed moment after a meteor landing.
    case parachute, meteor, jetpack, impact
    /// The grand finale: a short countdown, then the pet leaves for good.
    case countdown, finale

    /// Behaviors that happen while standing on something.
    public var isGrounded: Bool {
        switch self {
        case .fall, .dragged, .parachute, .meteor, .jetpack, .countdown, .finale: return false
        default: return true
        }
    }

    /// True while arriving in style.
    public var isEntry: Bool { self == .parachute || self == .meteor || self == .jetpack }
}

public enum Facing: Sendable {
    case left, right

    public var sign: Double { self == .right ? 1 : -1 }
    public var flipped: Facing { self == .right ? .left : .right }
}

/// Tunable constants. Units are points and seconds.
public struct PetConfig: Sendable {
    public var gravity: Double = 1800
    public var maxFallSpeed: Double = 1600
    public var walkSpeed: Double = 32
    public var runSpeed: Double = 95
    /// Half the sheep's body width, used to turn around before poking off a screen edge.
    public var halfWidth: Double = 26
    /// Sprite height, used to keep the sheep below the top of the screen.
    public var height: Double = 64
    /// How far (up or down) the sheep snaps onto a nearby surface, e.g. when a window moves a little.
    public var snapDistance: Double = 6
    /// Impacts faster than this make the sheep bleat in surprise when it lands.
    public var startleSpeed: Double = 900
    public var parachuteSpeed: Double = 70
    public var meteorSpeed: Double = 650
    public var jetpackSpeed: Double = 170
    /// Multiplies walk and run speed (user setting).
    public var speedMultiplier: Double = 1
    /// Behaviors the state machine may pick. `stand` is always allowed.
    public var enabledBehaviors: Set<Behavior> = Set(Behavior.allCases)

    public init() {}
}

/// Physics plus a random behavior state machine for one sheep.
///
/// Position (`x`, `y`) is the bottom-center of the sprite (between the hooves) in global
/// AppKit screen coordinates. Rendering lives elsewhere; this type is pure and testable.
public struct Pet: Sendable {
    public var x: Double
    public var y: Double
    public var vx: Double = 0
    public var vy: Double = 0
    public var facing: Facing
    public private(set) var behavior: Behavior
    public private(set) var timeInBehavior: Double = 0
    public private(set) var behaviorDuration: Double
    /// Drives sprite animation; runs faster for walking and running at higher speeds.
    public private(set) var animationTime: Double = 0
    public var config: PetConfig
    public var animal: Animal
    /// 0..<1, desynchronizes animation details (like blinking) between pets.
    public var phase: Double = 0
    public private(set) var finaleStyle: FinaleStyle = .vanish
    /// True once the finale has finished; the pet should be removed.
    public private(set) var isGone = false
    /// Where a jetpack arrival is heading.
    private var targetX: Double = 0

    public init(x: Double, y: Double, animal: Animal = .sheep, facing: Facing = .right, behavior: Behavior = .fall,
                duration: Double = 2, config: PetConfig = PetConfig()) {
        self.animal = animal
        self.x = x
        self.y = y
        self.facing = facing
        self.behavior = behavior
        self.behaviorDuration = duration
        self.config = config
    }

    /// A new pet arriving on a random screen in the given style.
    public static func spawn<R: RandomNumberGenerator>(in world: World, rng: inout R, animal: Animal = .sheep,
                                                       entry: EntryStyle = .drop,
                                                       config: PetConfig = PetConfig()) -> Pet {
        var pet = Pet(x: 0, y: 0, animal: animal, facing: Bool.random(using: &rng) ? .left : .right, config: config)
        pet.phase = Double.random(in: 0..<1, using: &rng)
        pet.enter(in: world, style: entry, rng: &rng)
        return pet
    }

    /// Places the pet off- or on-screen and starts its arrival.
    public mutating func enter<R: RandomNumberGenerator>(in world: World, style: EntryStyle, rng: inout R) {
        guard let screen = world.screens.randomElement(using: &rng) else { return }
        let margin = min(config.halfWidth + 30, screen.width / 2)
        let landingX = Double.random(in: (screen.minX + margin)...(screen.maxX - margin), using: &rng)
        switch style.resolved(using: &rng) {
        case .drop, .random:
            x = landingX
            y = screen.maxY - config.height
            startFalling(vx: 0, vy: 0)
        case .parachute:
            x = landingX
            y = screen.maxY - config.height
            vx = 0
            vy = -config.parachuteSpeed
            setBehavior(.parachute, duration: .infinity)
        case .meteor:
            // Start above the screen, aimed so it comes down at `landingX`.
            let startY = screen.maxY + 40
            vx = (Bool.random(using: &rng) ? 1 : -1) * config.meteorSpeed * 0.45
            vy = -config.meteorSpeed
            x = landingX - vx * (startY - screen.minY) / config.meteorSpeed
            y = startY
            facing = vx > 0 ? .right : .left
            setBehavior(.meteor, duration: .infinity)
        case .jetpack:
            let fromLeft = Bool.random(using: &rng)
            x = fromLeft ? screen.minX - 60 : screen.maxX + 60
            y = screen.minY + screen.height * Double.random(in: 0.45...0.8, using: &rng)
            targetX = landingX
            facing = fromLeft ? .right : .left
            vx = facing.sign * config.jetpackSpeed
            vy = -config.jetpackSpeed * 0.15
            setBehavior(.jetpack, duration: .infinity)
        }
    }

    // MARK: - Simulation

    public mutating func step<R: RandomNumberGenerator>(dt: Double, world: World, rng: inout R) {
        guard dt > 0, !world.screens.isEmpty else { return }
        timeInBehavior += dt
        animationTime += (behavior == .walk || behavior == .run) ? dt * config.speedMultiplier : dt

        switch behavior {
        case .dragged:
            return
        case .fall:
            integrateFall(dt: dt, world: world, rng: &rng)
        case .parachute, .meteor, .jetpack:
            integrateEntry(dt: dt, world: world, rng: &rng)
        case .countdown:
            if timeInBehavior >= behaviorDuration {
                setBehavior(.finale, duration: PetArt.finaleDuration(finaleStyle))
            }
        case .finale:
            stepFinale(dt: dt, world: world)
        default:
            guard let surface = nearestSupport(world: world) else {
                startFalling(vx: movingSpeed * facing.sign * 0.5, vy: 0)
                return
            }
            y = surface.y
            if behavior == .walk || behavior == .run {
                move(dt: dt, world: world)
            }
            if behavior.isGrounded && timeInBehavior >= behaviorDuration {
                chooseNextBehavior(rng: &rng)
            }
        }
    }

    /// Forces a behavior (used by the state machine, tests and the UI).
    public mutating func setBehavior(_ newBehavior: Behavior, duration: Double) {
        behavior = newBehavior
        behaviorDuration = duration
        timeInBehavior = 0
        animationTime = 0
    }

    /// Updates tunables; stops the current behavior if it was just disabled.
    public mutating func apply(_ newConfig: PetConfig) {
        config = newConfig
        if behavior.isGrounded, behavior != .stand, !config.enabledBehaviors.contains(behavior) {
            setBehavior(.stand, duration: 1)
        }
    }

    // MARK: - Finale

    /// Starts the countdown to this pet's finale. Every pet given the same call at the same
    /// moment goes off together.
    public mutating func beginFinale(style: FinaleStyle) {
        guard behavior != .countdown && behavior != .finale else { return }
        var rng = SeededGenerator(seed: UInt64(phase * 1_000_000))
        finaleStyle = style.resolved(using: &rng)
        vx = 0
        vy = 0
        setBehavior(.countdown, duration: PetArt.countdownSeconds)
    }

    private mutating func stepFinale(dt: Double, world: World) {
        switch finaleStyle {
        case .balloons:
            y += 70 * dt
            x += sin(timeInBehavior * 2) * 12 * dt
        case .beamUp where timeInBehavior > 0.6:
            y += 60 * (timeInBehavior - 0.6) * dt * 2
        default:
            break
        }
        let top = world.screens.map(\.maxY).max() ?? 0
        if timeInBehavior >= behaviorDuration || y > top + 20 { isGone = true }
    }

    // MARK: - Dragging

    public mutating func beginDrag() {
        guard behavior != .countdown && behavior != .finale else { return }
        vx = 0
        vy = 0
        setBehavior(.dragged, duration: .infinity)
    }

    /// Moves the sheep to follow the mouse and remembers the motion so a release can throw it.
    public mutating func drag(toX newX: Double, y newY: Double, dt: Double) {
        guard behavior == .dragged else { return }
        if dt > 0 {
            // Smooth the throw velocity so one jittery mouse event doesn't dominate.
            vx = vx * 0.5 + ((newX - x) / dt) * 0.5
            vy = vy * 0.5 + ((newY - y) / dt) * 0.5
        }
        if abs(newX - x) > 0.5 { facing = newX > x ? .right : .left }
        x = newX
        y = newY
    }

    public mutating func endDrag() {
        guard behavior == .dragged else { return }
        let limit = 1400.0
        startFalling(vx: min(max(vx, -limit), limit), vy: min(max(vy, -limit), limit))
    }

    // MARK: - Internals

    private var movingSpeed: Double {
        let base: Double
        switch behavior {
        case .walk: base = config.walkSpeed
        case .run: base = config.runSpeed
        default: return 0
        }
        return base * config.speedMultiplier * gaitFactor
    }

    /// Hopping animals only move while airborne; the factor keeps the average speed the same.
    private var gaitFactor: Double {
        guard animal.hops else { return 1 }
        let frames = PetArt.frames(for: behavior, animal: animal)
        let airborne = Double(frames.filter { $0.lift > 0 }.count) / Double(frames.count)
        return pose.lift > 0 ? 1 / max(airborne, 0.1) : 0
    }

    /// The current animation frame.
    public var pose: Pose {
        PetArt.pose(for: behavior, animal: animal, time: animationTime, phase: phase, finale: finaleStyle)
    }

    private func nearestSupport(world: World) -> Platform? {
        world.platforms
            .filter { $0.spans(x) && abs($0.y - y) <= config.snapDistance }
            .min { abs($0.y - y) < abs($1.y - y) }
    }

    private mutating func move(dt: Double, world: World) {
        let dir = facing.sign
        let newX = x + dir * movingSpeed * dt
        let leadingEdge = newX + dir * config.halfWidth
        // Turn around rather than walk off the usable area of the displays. A neighbouring
        // display at the same height lets the sheep wander across.
        guard world.screen(containingX: leadingEdge, y: y + 1) != nil else {
            facing = facing.flipped
            return
        }
        x = newX
        // Walking past the end of a window edge: the next step finds no support and falls.
    }

    private mutating func startFalling(vx: Double, vy: Double) {
        self.vx = vx
        self.vy = vy
        setBehavior(.fall, duration: .infinity)
    }

    private mutating func integrateFall<R: RandomNumberGenerator>(dt: Double, world: World, rng: inout R) {
        vy = max(vy - config.gravity * dt, -config.maxFallSpeed)
        var newX = x + vx * dt
        var newY = y + vy * dt

        // Keep inside the display we're over (bounce off its sides and ceiling), unless the
        // new position is already over a neighbouring display.
        let current = world.screen(containingX: x, y: max(y, nearestScreen(world).minY)) ?? nearestScreen(world)
        if world.screen(containingX: newX, y: max(newY, current.minY)) == nil {
            let lo = current.minX + config.halfWidth
            let hi = current.maxX - config.halfWidth
            if newX < lo || newX > hi {
                newX = min(max(newX, lo), hi)
                vx = -vx * 0.4
                facing = vx >= 0 ? .right : .left
            }
        }
        let ceiling = current.maxY - config.height
        if newY > ceiling {
            newY = ceiling
            vy = min(vy, 0)
        }

        if vy <= 0 {
            if let landing = landingPlatform(world: world, x: newX, fromY: y, toY: newY) {
                let impact = -vy
                x = newX
                y = landing.y
                vx = 0
                vy = 0
                if impact > config.startleSpeed {
                    setBehavior(.call, duration: 1.2)
                } else {
                    setBehavior(.stand, duration: Double.random(in: 0.4...1.2, using: &rng))
                }
                return
            }
        }

        x = newX
        y = newY

        // Fell out of every display (e.g. a monitor was unplugged): drop in from the top again.
        let lowestFloor = world.screens.map(\.minY).min() ?? 0
        if y < lowestFloor - 200 || world.screen(containingX: x, y: max(y, lowestFloor)) == nil && y < lowestFloor {
            respawn(in: world, rng: &rng)
        }
    }

    /// The highest platform crossed while moving down from `fromY` to `toY` at `x`.
    private func landingPlatform(world: World, x: Double, fromY: Double, toY: Double) -> Platform? {
        world.platforms
            .filter { $0.spans(x) && $0.y <= fromY + 0.5 && $0.y >= toY }
            .max { $0.y < $1.y }
    }

    private mutating func integrateEntry<R: RandomNumberGenerator>(dt: Double, world: World, rng: inout R) {
        switch behavior {
        case .parachute:
            // Drift down, swaying gently.
            vx = sin(timeInBehavior * 1.6) * 28
            vy = -config.parachuteSpeed
        case .jetpack:
            if abs(targetX - x) < 6 || (targetX - x) * facing.sign < 0 {
                // Arrived over the landing spot: hover straight down.
                vx = 0
                vy = -config.jetpackSpeed * 0.6
            }
        default:
            break // meteors fly straight
        }
        let newX = x + vx * dt
        var newY = y + vy * dt
        if behavior != .meteor, let screen = world.screen(containingX: newX, y: max(newY, 0)) {
            newY = min(newY, screen.maxY - config.height)
        }
        // Only land once actually over a display (jetpacks and meteors start outside).
        if world.screen(containingX: newX, y: max(newY, world.screens.map(\.minY).min() ?? 0)) != nil,
           let landing = landingPlatform(world: world, x: newX, fromY: y, toY: newY) {
            x = newX
            y = landing.y
            let wasMeteor = behavior == .meteor
            vx = 0
            vy = 0
            if wasMeteor {
                setBehavior(.impact, duration: Self.durationRange(for: .impact).lowerBound)
            } else {
                setBehavior(.stand, duration: Double.random(in: 0.6...1.4, using: &rng))
            }
            return
        }
        x = newX
        y = newY
        let lowestFloor = world.screens.map(\.minY).min() ?? 0
        if y < lowestFloor - 200 || timeInBehavior > 30 { respawn(in: world, rng: &rng) }
    }

    private func nearestScreen(_ world: World) -> Rect {
        world.screens.min { distance(to: $0) < distance(to: $1) } ?? Rect(x: 0, y: 0, width: 800, height: 600)
    }

    private func distance(to r: Rect) -> Double {
        let dx = max(r.minX - x, 0, x - r.maxX)
        let dy = max(r.minY - y, 0, y - r.maxY)
        return dx * dx + dy * dy
    }

    /// Drops the sheep from near the top of a random screen.
    public mutating func respawn<R: RandomNumberGenerator>(in world: World, rng: inout R) {
        guard let screen = world.screens.randomElement(using: &rng) else { return }
        let margin = min(config.halfWidth + 10, screen.width / 2)
        x = Double.random(in: (screen.minX + margin)...(screen.maxX - margin), using: &rng)
        y = screen.maxY - config.height
        startFalling(vx: 0, vy: 0)
    }

    // MARK: - State machine

    /// Weighted next behaviors for each grounded behavior.
    static let transitions: [Behavior: [(Behavior, Double)]] = [
        .stand: [(.walk, 40), (.run, 8), (.sit, 12), (.eat, 16), (.call, 9), (.stand, 5)],
        .walk: [(.stand, 25), (.walk, 15), (.run, 10), (.eat, 20), (.sit, 15), (.call, 8)],
        .run: [(.walk, 50), (.stand, 40), (.call, 10)],
        .sit: [(.sleep, 35), (.stand, 30), (.walk, 20), (.call, 15)],
        .sleep: [(.sit, 50), (.stand, 50)],
        .eat: [(.stand, 35), (.walk, 40), (.eat, 15), (.call, 10)],
        .call: [(.stand, 45), (.walk, 45), (.run, 10)],
        .impact: [(.stand, 70), (.call, 30)],
    ]

    /// Allowed successors of a grounded behavior.
    public static func successors(of behavior: Behavior) -> [Behavior] {
        (transitions[behavior] ?? []).map(\.0)
    }

    /// How long a behavior lasts, in seconds.
    public static func durationRange(for behavior: Behavior) -> ClosedRange<Double> {
        switch behavior {
        case .stand: return 1...3
        case .walk: return 3...9
        case .run: return 1.5...3.5
        case .sit: return 3...8
        case .sleep: return 6...16
        case .eat: return 3...6
        case .call: return 1.2...1.2
        case .impact: return 1.6...1.6
        case .fall, .dragged, .parachute, .meteor, .jetpack, .countdown, .finale: return .infinity ... .infinity
        }
    }

    mutating func chooseNextBehavior<R: RandomNumberGenerator>(rng: inout R) {
        var options = (Self.transitions[behavior] ?? []).filter {
            $0.0 == .stand || config.enabledBehaviors.contains($0.0)
        }
        if options.isEmpty { options = [(.stand, 1)] }
        let total = options.reduce(0) { $0 + $1.1 }
        var pick = Double.random(in: 0..<total, using: &rng)
        var next = options[0].0
        for (candidate, weight) in options {
            if pick < weight { next = candidate; break }
            pick -= weight
        }
        // Sometimes wander off the other way.
        if next == .walk || next == .run, Double.random(in: 0..<1, using: &rng) < 0.3 {
            facing = facing.flipped
        }
        let range = Self.durationRange(for: next)
        setBehavior(next, duration: range.lowerBound == range.upperBound
                    ? range.lowerBound
                    : Double.random(in: range, using: &rng))
    }
}

/// Small deterministic generator (SplitMix64) so tests and replays are reproducible.
public struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) { state = seed }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
