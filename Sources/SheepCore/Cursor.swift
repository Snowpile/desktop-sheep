/// The mouse cursor as pets see it, in global screen coordinates.
public struct CursorInput: Sendable {
    public var x: Double
    public var y: Double
    /// Speed in points per second.
    public var speed: Double

    public init(x: Double, y: Double, speed: Double) {
        self.x = x
        self.y = y
        self.speed = speed
    }
}

/// A treat dropped on the desktop. Falls onto the nearest surface; a pet runs over and eats it.
public struct Treat: Sendable {
    public let id: Int
    public var x: Double
    public var y: Double
    public var vy: Double = 0
    public var landed = false
    /// Set once eaten; remove it.
    public var eaten = false
    /// Seconds since it landed (uneaten treats disappear after a while).
    public var age: Double = 0

    public init(id: Int, x: Double, y: Double) {
        self.id = id
        self.x = x
        self.y = y
    }
}

/// Pets noticing the cursor (looking at it, chasing it, getting startled) and treats.
public enum Cursor {
    /// Cursor speeds above this close to a pet startle it.
    public static let startleSpeed = 1800.0

    public static func react<R: RandomNumberGenerator>(_ pets: inout [Pet], cursor: CursorInput, dt: Double, rng: inout R) {
        for i in pets.indices {
            var pet = pets[i]
            guard pet.behavior.isGrounded, pet.ridingID == nil, pet.partnerID == nil, pet.treatID == nil, !pet.isLeaving else { continue }
            let dx = cursor.x - pet.x, dy = cursor.y - (pet.y + 20)
            let near = abs(dx) < 140 && abs(dy) < 110
            let towards: Facing = dx >= 0 ? .right : .left
            let enabled = pet.config.enabledBehaviors

            if pet.behavior == .chaseCursor {
                pet.facing = towards
                pet.pace = abs(dx) < 12 ? 0 : 1
                if abs(dx) < 12 && abs(dy) < 160 { pet.setBehavior(.call, duration: 1.2) } // caught it!
            } else if near, cursor.speed > startleSpeed, enabled.contains(.startled), pet.behavior != .startled,
                      pet.behavior != .sleep || cursor.speed > startleSpeed * 1.5 {
                // Whoosh! Jump, then run away from the cursor.
                pet.facing = towards.flipped
                pet.setBehavior(.startled, duration: Pet.durationRange(for: .startled).lowerBound)
            } else if [.stand, .walk, .sit].contains(pet.behavior), abs(dx) < 700, abs(dy) < 300,
                      enabled.contains(.chaseCursor), Double.random(in: 0..<1, using: &rng) < 0.012 * dt {
                pet.facing = towards
                pet.pace = 1
                pet.setBehavior(.chaseCursor, duration: Double.random(in: Pet.durationRange(for: .chaseCursor), using: &rng))
            } else if [.stand, .sit, .eat].contains(pet.behavior), abs(dx) < 260, abs(dy) < 200, abs(dx) > 8 {
                pet.facing = towards // keep an eye on it
            }
            if pet.behavior == .startled && pet.timeInBehavior + dt >= pet.behaviorDuration {
                pet.facing = towards.flipped
            }
            pets[i] = pet
        }
    }

    /// Moves treats, sends the nearest free pet to each one and lets it eat.
    public static func step<R: RandomNumberGenerator>(_ treats: inout [Treat], pets: inout [Pet], world: World,
                                                       dt: Double, rng: inout R) {
        for t in treats.indices where !treats[t].eaten {
            var treat = treats[t]
            if !treat.landed {
                treat.vy -= 1800 * dt
                let newY = treat.y + treat.vy * dt
                if let p = world.platforms.filter({ $0.spans(treat.x) && $0.y <= treat.y + 0.5 && $0.y >= newY }).max(by: { $0.y < $1.y }) {
                    treat.y = p.y
                    treat.landed = true
                } else {
                    treat.y = newY
                    if newY < (world.screens.map(\.minY).min() ?? 0) - 100 { treat.eaten = true }
                }
            } else {
                treat.age += dt
                if treat.age > 90 { treat.eaten = true } // nobody wanted it
            }
            treats[t] = treat
        }

        // Pets going for a treat steer towards it and eat when they get there.
        for i in pets.indices {
            guard let id = pets[i].treatID else { continue }
            guard let t = treats.firstIndex(where: { $0.id == id && !$0.eaten }) else { pets[i].treatID = nil; continue }
            var pet = pets[i]
            let treat = treats[t]
            if pet.behavior == .fetchTreat, abs(pet.y - treat.y) < 2 {
                let dx = treat.x - pet.x
                let mouth = pet.config.halfWidth * 0.9
                pet.facing = dx >= 0 ? .right : .left
                if abs(abs(dx) - mouth) < 6 || abs(dx) < mouth {
                    pet.pace = 0
                    pet.setBehavior(.eat, duration: 2.5)
                } else {
                    pet.pace = 1
                }
            } else if pet.behavior == .eat, pet.timeInBehavior + dt >= pet.behaviorDuration {
                treats[t].eaten = true
                pet.treatID = nil
            } else if pet.behavior != .eat {
                pet.treatID = nil // got distracted (picked up, fell, …)
            }
            pets[i] = pet
        }

        // Assign landed, unclaimed treats to the closest available pet on the same surface.
        for treat in treats where treat.landed && !treat.eaten && !pets.contains(where: { $0.treatID == treat.id }) {
            let candidates = pets.indices.filter { i in
                let p = pets[i]
                return p.treatID == nil && p.behavior.isGrounded && p.ridingID == nil && !p.isLeaving
                    && abs(p.y - treat.y) < 2 && abs(p.x - treat.x) < 900
            }
            guard let best = candidates.min(by: { abs(pets[$0].x - treat.x) < abs(pets[$1].x - treat.x) }) else { continue }
            pets[best].treatID = treat.id
            pets[best].partnerID = nil
            pets[best].pace = 1
            pets[best].facing = treat.x >= pets[best].x ? .right : .left
            pets[best].setBehavior(.fetchTreat, duration: Pet.durationRange(for: .fetchTreat).lowerBound)
        }
        treats.removeAll { $0.eaten }
    }
}

extension PetArt {
    /// A little bone-shaped biscuit, 12x8.
    public static func treatSprite() -> PixelCanvas {
        var c = PixelCanvas(width: 12, height: 8)
        let rows = [
            ".##......##.",
            "#bb#....#bb#",
            "#bbb####bbb#",
            ".#bbbbbbbb#.",
            ".#bbbbbbbb#.",
            "#bbb####bbb#",
            "#bb#....#bb#",
            ".##......##.",
        ]
        for (y, row) in rows.enumerated() {
            for (x, ch) in row.enumerated() {
                if ch == "#" { c[x, y] = 1 } else if ch == "b" { c[x, y] = y < 3 ? 24 : 25 }
            }
        }
        return c
    }
}
