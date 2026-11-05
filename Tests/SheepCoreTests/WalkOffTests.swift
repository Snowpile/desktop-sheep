import Testing
@testable import SheepCore

@Suite struct WalkOffTests {
    let left = Rect(x: 0, y: 50, width: 1000, height: 700)

    private func walker(at x: Double, facing: Facing, walkOff: Bool) -> Pet {
        var config = PetConfig()
        config.walkOffScreen = walkOff
        return Pet(x: x, y: 50, facing: facing, behavior: .walk, duration: 1000, config: config)
    }

    private func walk(_ pet: inout Pet, in world: World, seconds: Double) {
        var rng = SeededGenerator(seed: 1)
        for _ in 0..<Int(seconds * 60) where !pet.isGone { pet.step(dt: 1.0 / 60, world: world, rng: &rng) }
    }

    @Test func walksOffAndDisappearsWhenEnabled() {
        var pet = walker(at: 950, facing: .right, walkOff: true)
        walk(&pet, in: World(screens: [left]), seconds: 10)
        #expect(pet.exit == .walkedOff)
        #expect(pet.x > left.maxX)
    }

    @Test func turnsAroundWhenDisabled() {
        var pet = walker(at: 950, facing: .right, walkOff: false)
        walk(&pet, in: World(screens: [left]), seconds: 10)
        #expect(!pet.isGone)
        #expect(pet.facing == .left)
    }

    @Test func doesNotLeaveTowardsAnotherDisplay() {
        // A second display to the right whose usable area starts higher: turn, don't leave.
        let right = Rect(x: 1000, y: 120, width: 800, height: 630)
        var pet = walker(at: 950, facing: .right, walkOff: true)
        walk(&pet, in: World(screens: [left, right]), seconds: 5)
        #expect(!pet.isGone)
        #expect(!pet.isLeaving)
    }

    @Test func keepsWalkingOnceLeaving() {
        var pet = walker(at: 970, facing: .right, walkOff: true)
        var rng = SeededGenerator(seed: 2)
        let world = World(screens: [left])
        while !pet.isLeaving { pet.step(dt: 1.0 / 60, world: world, rng: &rng) }
        pet.setBehaviorForTesting(duration: 0) // would normally pick a new behavior
        for _ in 0..<30 { pet.step(dt: 1.0 / 60, world: world, rng: &rng) }
        #expect(pet.behavior == .walk)
        #expect(pet.y == 50) // no falling past the floor's end
    }

    @Test func grabbingCancelsLeaving() {
        var pet = walker(at: 970, facing: .right, walkOff: true)
        var rng = SeededGenerator(seed: 3)
        let world = World(screens: [left])
        while !pet.isLeaving { pet.step(dt: 1.0 / 60, world: world, rng: &rng) }
        pet.beginDrag()
        #expect(!pet.isLeaving)
    }

    @Test func settingFlowsIntoConfig() {
        var s = PetSettings()
        s.walkOffScreen = true
        var config = PetConfig()
        s.apply(to: &config)
        #expect(config.walkOffScreen)
    }
}

extension Pet {
    /// Expires the current behavior so the next step would normally choose another.
    mutating func setBehaviorForTesting(duration: Double) { setBehavior(behavior, duration: duration) }
}
