import Testing
@testable import SheepCore

/// Steps a flock the same way the app does: each pet sees the others' backs, then `Social` runs.
func simulate(_ pets: inout [Pet], in world: World, seconds: Double, seed: UInt64 = 1,
              until done: ([Pet]) -> Bool = { _ in false }) {
    var rng = SeededGenerator(seed: seed)
    for _ in 0..<Int(seconds * 60) {
        for i in pets.indices { pets[i].step(dt: 1.0 / 60, world: Social.world(world, for: i, in: pets), rng: &rng) }
        Social.interact(&pets, dt: 1.0 / 60, rng: &rng)
        if done(pets) { return }
    }
}

private let screen = Rect(x: 0, y: 0, width: 1600, height: 900)

private func pet(_ x: Double, _ behavior: Behavior = .walk, facing: Facing = .right, id: UInt64,
                 y: Double = 0, setup: (inout PetConfig) -> Void = { _ in }) -> Pet {
    var config = PetConfig()
    setup(&config)
    var p = Pet(x: x, y: y, facing: facing, behavior: behavior, duration: 1000, config: config)
    p.id = id
    return p
}

@Suite struct ClimbingTests {
    let window = Rect(x: 600, y: 0, width: 500, height: 400)
    var world: World {
        World(screens: [screen], windowTops: World.windowTops(frontToBack: [window], screens: [screen], headroom: 64),
              windows: [window])
    }

    @Test func climbsAWindowSideOntoItsTop() {
        var pets = [pet(540, id: 1) { $0.climbChance = 1 }]
        var sawClimb = false
        simulate(&pets, in: world, seconds: 30) { p in
            if p[0].behavior == .climb { sawClimb = true }
            return sawClimb && p[0].behavior.isGrounded
        }
        #expect(sawClimb)
        #expect(pets[0].y == window.maxY)
        #expect(pets[0].x > window.minX)
    }

    @Test func climbingSpritePutsFeetOnTheWall() {
        var pets = [pet(540, id: 1) { $0.climbChance = 1 }]
        simulate(&pets, in: world, seconds: 5) { $0[0].behavior == .climb }
        #expect(pets[0].behavior == .climb)
        let scale = 1.5
        let origin = pets[0].spriteOrigin(width: Double(PetArt.width) * scale, height: Double(PetArt.height) * scale)
        #expect(origin.x + Double(PetArt.climbFootColumn + 1) * scale == window.minX)
        // The rotated art really has its feet in that column.
        let c = PetArt.render(pets[0].pose)
        #expect((0..<c.height).contains { PetArt.isSolid(c[PetArt.climbFootColumn, $0]) })
        #expect(!(0..<c.height).contains { PetArt.isSolid(c[PetArt.climbFootColumn + 4, $0]) })
    }

    @Test func fallsWhenTheWindowGoesAway() {
        var pets = [pet(540, id: 1) { $0.climbChance = 1 }]
        simulate(&pets, in: world, seconds: 8) { $0[0].behavior == .climb && $0[0].y > 60 }
        #expect(pets[0].behavior == .climb)
        simulate(&pets, in: World(screens: [screen]), seconds: 0.1)
        #expect(pets[0].behavior == .fall)
    }

    @Test func climbsTheScreenSideThenDropsBackDown() {
        var pets = [pet(1500, id: 1) { $0.climbChance = 1 }]
        var maxY = 0.0
        simulate(&pets, in: World(screens: [screen]), seconds: 60) { p in
            maxY = max(maxY, p[0].y)
            return maxY > 100 && p[0].behavior.isGrounded
        }
        #expect(maxY > 100)
        #expect(pets[0].y == 0)
        #expect(pets[0].facing == .left)
    }

    @Test func hangsFromAWindowEdgeThenDrops() {
        var pets = [pet(1090, id: 1, y: window.maxY) { $0.hangChance = 1; $0.climbChance = 0 }]
        var sawHang = false
        simulate(&pets, in: world, seconds: 12) { p in
            if p[0].behavior == .hang { sawHang = true }
            return sawHang && p[0].y == 0
        }
        #expect(sawHang)
        #expect(pets[0].y == 0)
    }

    @Test func tumbleRollsForwardAndSlowsDown() {
        var pets = [pet(400, .tumble, id: 1)]
        pets[0].setBehavior(.tumble, duration: 1.2)
        simulate(&pets, in: World(screens: [screen]), seconds: 0.6)
        let mid = pets[0].x
        simulate(&pets, in: World(screens: [screen]), seconds: 0.6)
        #expect(mid > 400)
        #expect(pets[0].x - mid < mid - 400)
        #expect(Set(PetArt.frames(for: .tumble).map(\.rotation)) == [0, 1, 2, 3])
    }
}

@Suite struct SocialTests {
    let world = World(screens: [screen])

    @Test func walkersMeetingHeadOnTurnAround() {
        var pets = [pet(500, id: 1) { $0.enabledBehaviors.remove(.nuzzle) },
                    pet(560, facing: .left, id: 2) { $0.enabledBehaviors.remove(.nuzzle) }]
        simulate(&pets, in: world, seconds: 0.2)
        #expect(pets[0].facing == .left && pets[1].facing == .right)
    }

    @Test func walkersSometimesNuzzleInstead() {
        let nuzzled = (UInt64(1)...30).contains { seed in
            var pets = [pet(500, id: 1), pet(560, facing: .left, id: 2)]
            simulate(&pets, in: world, seconds: 0.2, seed: seed)
            return pets.allSatisfy { $0.behavior == .nuzzle }
        }
        #expect(nuzzled)
    }

    @Test func runnerChasesAndTags() {
        var outcome = Set<Behavior>()
        for seed in UInt64(1)...30 {
            var pets = [pet(400, .run, id: 1), pet(700, .stand, id: 2)]
            pets[0].setBehavior(.run, duration: 3)
            simulate(&pets, in: world, seconds: 0.05, seed: seed)
            guard pets[0].behavior == .chase else { continue }
            #expect(pets[1].behavior == .flee)
            #expect(pets[0].partnerID == 2 && pets[1].partnerID == 1)
            simulate(&pets, in: world, seconds: 10, seed: seed) { !$0[0].behavior.isSocial }
            outcome.insert(pets[0].behavior)
        }
        #expect(!outcome.isEmpty)
    }

    @Test func followerKeepsBehindTheLeader() {
        var pets = [pet(400, id: 1), pet(520, id: 2)]
        simulate(&pets, in: world, seconds: 30) { $0[0].behavior == .follow }
        #expect(pets[0].behavior == .follow)
        #expect(pets[0].partnerID == 2)
        simulate(&pets, in: world, seconds: 3)
        if pets[0].behavior == .follow && pets[1].behavior == .walk {
            #expect(pets[1].x > pets[0].x)
        }
    }

    @Test func petsStackUpAndRideAlong() {
        var host = pet(600, .stand, id: 1)
        host.setBehavior(.stand, duration: 100)
        var rider = pet(600, .fall, id: 2, y: 300)
        rider.setBehavior(.fall, duration: .infinity)
        var pets = [host, rider]
        simulate(&pets, in: world, seconds: 1)
        #expect(pets[1].behavior == .ride)
        #expect(pets[1].ridingID == 1)
        #expect(pets[1].y == Social.backHeight)
        let offset = pets[1].x - pets[0].x
        // The host walks off with the rider on board.
        pets[0].setBehavior(.walk, duration: 100)
        pets[1].setBehavior(.ride, duration: 100)
        simulate(&pets, in: world, seconds: 1)
        #expect(pets[0].x > 600)
        #expect(abs((pets[1].x - pets[0].x) - offset) < 0.001)
        // Picking up the host drops the rider.
        pets[0].beginDrag()
        simulate(&pets, in: world, seconds: 0.05)
        #expect(pets[1].ridingID == nil)
        #expect(pets[1].behavior == .fall)
    }

    @Test func noStackingWhenDisabled() {
        var pets = [pet(600, .stand, id: 1), pet(600, .fall, id: 2, y: 300) { $0.enabledBehaviors.remove(.ride) }]
        pets[1].setBehavior(.fall, duration: .infinity)
        simulate(&pets, in: world, seconds: 1)
        #expect(pets[1].y == 0)
        #expect(pets[1].ridingID == nil)
    }

    @Test func yawnsAreContagious() {
        let caught = (UInt64(1)...20).contains { seed in
            var pets = [pet(500, .stand, id: 1), pet(650, .sit, id: 2)]
            pets[0].setBehavior(.yawn, duration: 1.6)
            pets[1].setBehavior(.sit, duration: 100)
            simulate(&pets, in: world, seconds: 0.05, seed: seed)
            return pets[1].behavior == .yawn
        }
        #expect(caught)
    }

    @Test func idleNeighboursPlayFight() {
        var pets = [pet(500, .stand, id: 1), pet(560, .stand, id: 2)]
        pets[0].setBehavior(.stand, duration: 1000)
        pets[1].setBehavior(.stand, duration: 1000)
        simulate(&pets, in: world, seconds: 60) { $0[0].behavior == .playFight }
        simulate(&pets, in: world, seconds: 0.05)
        #expect(pets[0].behavior == .playFight && pets[1].behavior == .playFight)
        #expect(pets[0].facing == .right && pets[1].facing == .left)
    }

    @Test func disabledSocialBehaviorsNeverHappen() {
        var settings = PetSettings()
        for b in [Behavior.nuzzle, .chase, .follow, .playFight, .ride, .yawn] { settings.setEnabled(b, false) }
        var config = PetConfig()
        settings.apply(to: &config)
        var pets = (0..<6).map { i -> Pet in
            var p = Pet(x: Double(200 + i * 80), y: 0, facing: i % 2 == 0 ? .right : .left, behavior: .walk, duration: 2, config: config)
            p.id = UInt64(i + 1)
            return p
        }
        var seen = Set<Behavior>()
        var rng = SeededGenerator(seed: 11)
        for _ in 0..<(60 * 120) {
            for i in pets.indices { pets[i].step(dt: 1.0 / 60, world: Social.world(world, for: i, in: pets), rng: &rng) }
            Social.interact(&pets, dt: 1.0 / 60, rng: &rng)
            pets.forEach { seen.insert($0.behavior) }
        }
        #expect(seen.isDisjoint(with: [.nuzzle, .chase, .flee, .follow, .playFight, .ride, .yawn]))
    }

    @Test func busyFlockStaysOnScreen() {
        var pets = (0..<8).map { i -> Pet in
            var p = Pet(x: Double(150 + i * 170), y: 0, animal: Animal.allCases[i % 5],
                        facing: i % 2 == 0 ? .right : .left, behavior: .walk, duration: 1)
            p.id = UInt64(i + 1)
            return p
        }
        let window = Rect(x: 500, y: 0, width: 400, height: 300)
        let w = World(screens: [screen], windowTops: World.windowTops(frontToBack: [window], screens: [screen], headroom: 64),
                      windows: [window])
        var rng = SeededGenerator(seed: 21)
        for _ in 0..<(60 * 180) {
            for i in pets.indices { pets[i].step(dt: 1.0 / 60, world: Social.world(w, for: i, in: pets), rng: &rng) }
            Social.interact(&pets, dt: 1.0 / 60, rng: &rng)
            for p in pets {
                #expect(p.x >= screen.minX - 1 && p.x <= screen.maxX + 1)
                #expect(p.y >= screen.minY - 1 && p.y <= screen.maxY)
            }
        }
    }
}
