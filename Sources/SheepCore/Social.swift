/// Pets noticing each other: stacking on backs, bumping, nuzzling, chase and tag,
/// follow-the-leader, play-fights and contagious yawns. Pure functions over a list of pets so
/// the rules can be unit tested.
public enum Social {
    /// Height of a pet's back above its feet, in points (where another pet can sit).
    public static let backHeight: Double = 30

    /// The world as one pet sees it: other pets' backs become surfaces to land on.
    public static func world(_ base: World, for index: Int, in pets: [Pet]) -> World {
        guard pets.indices.contains(index), pets[index].config.enabledBehaviors.contains(.ride) else { return base }
        var w = base
        let hw = pets[index].config.halfWidth
        w.extraPlatforms = pets.indices.compactMap { j in
            let other = pets[j]
            guard j != index, other.behavior.isGrounded, other.behavior != .tumble, other.ridingID != pets[index].id else { return nil }
            return Platform(y: other.y + backHeight, minX: other.x - hw * 0.6, maxX: other.x + hw * 0.6)
        }
        return w
    }

    public static func interact<R: RandomNumberGenerator>(_ pets: inout [Pet], dt: Double, rng: inout R) {
        guard dt > 0 else { return }
        updateRiders(&pets, rng: &rng)
        updateOngoing(&pets, rng: &rng)
        startNew(&pets, dt: dt, rng: &rng)
    }

    // MARK: Riding

    private static func updateRiders<R: RandomNumberGenerator>(_ pets: inout [Pet], rng: inout R) {
        for i in pets.indices {
            var pet = pets[i]
            let hw = pet.config.halfWidth
            if pet.ridingID == nil, pet.behavior.isGrounded, !pet.behavior.isMoving,
               pet.config.enabledBehaviors.contains(.ride),
               let host = pets.first(where: { $0.id != pet.id && $0.behavior.isGrounded && $0.ridingID != pet.id
                   && abs(pet.y - ($0.y + backHeight)) < 1 && abs(pet.x - $0.x) <= hw * 0.6 }) {
                pet.ridingID = host.id
                pet.rideOffset = pet.x - host.x
                pet.setBehavior(.ride, duration: Double.random(in: Pet.durationRange(for: .ride), using: &rng))
            }
            if let hostID = pet.ridingID {
                if let host = pets.first(where: { $0.id == hostID }), host.behavior.isGrounded, host.behavior != .tumble {
                    if pet.behavior.isMoving {
                        pet.hopOff()
                    } else if pet.behavior.isGrounded {
                        pet.x = host.x + pet.rideOffset
                        pet.y = host.y + backHeight
                    }
                } else {
                    pet.ridingID = nil // host moved off, fell or was picked up: tumble down too
                    if pet.behavior.isGrounded { pet.startFalling(vx: 0, vy: 0) }
                }
            }
            pets[i] = pet
        }
    }

    // MARK: Ongoing interactions

    private static func updateOngoing<R: RandomNumberGenerator>(_ pets: inout [Pet], rng: inout R) {
        for i in pets.indices where pets[i].behavior.isSocial && pets[i].behavior != .ride {
            var pet = pets[i]
            guard let partner = pets.first(where: { $0.id == pet.partnerID }), sameSurface(pet, partner) else {
                pet.partnerID = nil
                pet.setBehavior(.stand, duration: 1)
                pets[i] = pet
                continue
            }
            let towards: Facing = partner.x >= pet.x ? .right : .left
            let d = abs(partner.x - pet.x)
            let hw = pet.config.halfWidth
            switch pet.behavior {
            case .nuzzle, .playFight:
                pet.facing = towards
            case .chase:
                pet.facing = towards
                if d < hw * 1.2 {
                    // Tag! Sometimes the roles swap, otherwise both celebrate.
                    let j = pets.firstIndex { $0.id == partner.id }!
                    if Bool.random(using: &rng) {
                        start(&pets[j], .chase, partner: pet.id, rng: &rng)
                        start(&pet, .flee, partner: partner.id, rng: &rng)
                    } else {
                        pet.partnerID = nil
                        pet.setBehavior(.call, duration: 1.2)
                        pets[j].partnerID = nil
                        pets[j].setBehavior(.call, duration: 1.2)
                    }
                }
            case .flee:
                if pet.timeInBehavior > 0.3 { pet.facing = towards.flipped }
            case .follow:
                guard partner.behavior == .walk || partner.behavior == .follow, d < hw * 12 else {
                    pet.partnerID = nil
                    pet.setBehavior(.stand, duration: 1)
                    break
                }
                pet.facing = partner.facing
                let behind = (partner.x - pet.x) * partner.facing.sign
                let gap = hw * 2.4
                pet.pace = behind <= 0 ? 0 : min(max(behind / gap, 0), 1.6)
            default:
                break
            }
            pets[i] = pet
        }
    }

    // MARK: Starting interactions

    private static func startNew<R: RandomNumberGenerator>(_ pets: inout [Pet], dt: Double, rng: inout R) {
        for i in pets.indices {
            for j in pets.indices where j != i {
                let a = pets[i], b = pets[j]
                guard sameSurface(a, b), a.partnerID == nil, a.ridingID == nil, b.ridingID == nil, !a.isLeaving else { continue }
                let d = abs(a.x - b.x)
                let hw = a.config.halfWidth
                let aFacesB = (b.x - a.x) * a.facing.sign > 0
                let bFacesA = (a.x - b.x) * b.facing.sign > 0
                let justStarted = { (p: Pet) in p.timeInBehavior <= dt * 1.5 }

                // Two walkers meeting head-on: bump and turn, or stop for a nuzzle.
                if i < j, isWalking(a), isWalking(b), aFacesB, bFacesA, d < hw * 2 {
                    if enabled(.nuzzle, a, b), Double.random(in: 0..<1, using: &rng) < 0.35 {
                        start(&pets[i], .nuzzle, partner: b.id, rng: &rng)
                        start(&pets[j], .nuzzle, partner: a.id, rng: &rng)
                    } else {
                        pets[i].facing = pets[i].facing.flipped
                        pets[j].facing = pets[j].facing.flipped
                    }
                    continue
                }
                // A pet that starts running may go after a nearby friend.
                if a.behavior == .run, justStarted(a), d < 420, b.partnerID == nil, b.behavior.isGrounded,
                   !b.behavior.isMoving || b.behavior == .walk, enabled(.chase, a, b),
                   Double.random(in: 0..<1, using: &rng) < 0.45 {
                    start(&pets[i], .chase, partner: b.id, rng: &rng)
                    start(&pets[j], .flee, partner: a.id, rng: &rng)
                    continue
                }
                // Walking behind another walker going the same way: fall into line.
                if a.behavior == .walk, b.behavior == .walk || b.behavior == .follow, a.facing == b.facing, aFacesB,
                   d < hw * 7, b.partnerID != a.id, enabled(.follow, a, a),
                   Double.random(in: 0..<1, using: &rng) < 0.4 * dt {
                    start(&pets[i], .follow, partner: b.id, rng: &rng)
                    continue
                }
                // Two idle pets close together sometimes start play-fighting.
                if i < j, a.behavior == .stand, b.behavior == .stand, d < hw * 3, enabled(.playFight, a, b),
                   Double.random(in: 0..<1, using: &rng) < 0.25 * dt {
                    start(&pets[i], .playFight, partner: b.id, rng: &rng)
                    start(&pets[j], .playFight, partner: a.id, rng: &rng)
                    continue
                }
            }
        }
        // Yawns (and dozing off) are contagious.
        for j in pets.indices where (pets[j].behavior == .yawn || pets[j].behavior == .sleep) && pets[j].timeInBehavior <= dt * 1.5 {
            for i in pets.indices where i != j && [.stand, .sit, .eat].contains(pets[i].behavior)
                && pets[i].partnerID == nil && abs(pets[i].x - pets[j].x) < 360 && abs(pets[i].y - pets[j].y) < 200
                && pets[i].config.enabledBehaviors.contains(.yawn) && Double.random(in: 0..<1, using: &rng) < 0.5 {
                pets[i].setBehavior(.yawn, duration: Pet.durationRange(for: .yawn).lowerBound)
            }
        }
    }

    // MARK: Helpers

    private static func sameSurface(_ a: Pet, _ b: Pet) -> Bool {
        a.behavior.isGrounded && b.behavior.isGrounded && abs(a.y - b.y) < 2
    }

    private static func isWalking(_ p: Pet) -> Bool { p.behavior == .walk || p.behavior == .run }

    private static func enabled(_ behavior: Behavior, _ a: Pet, _ b: Pet) -> Bool {
        a.config.enabledBehaviors.contains(behavior) && b.config.enabledBehaviors.contains(behavior)
    }

    static func start<R: RandomNumberGenerator>(_ pet: inout Pet, _ behavior: Behavior, partner: UInt64, rng: inout R) {
        pet.partnerID = partner
        pet.pace = 1
        let range = Pet.durationRange(for: behavior)
        pet.setBehavior(behavior, duration: Double.random(in: range, using: &rng))
    }
}
