import Testing
@testable import SheepCore

@Suite struct PeekAndMenuBarTests {
    let screen = Rect(x: 0, y: 0, width: 1600, height: 875)

    @Test func ducksBehindAWindowSideAndPeeksOut() {
        let window = Rect(x: 800, y: 0, width: 500, height: 600)
        let world = World(screens: [screen], windows: [window])
        var pet = Pet(x: 700, y: 0, facing: .right, behavior: .walk, duration: 100)
        pet.config.peekChance = 1
        pet.config.climbChance = 0
        var rng = SeededGenerator(seed: 1)
        for _ in 0..<(60 * 10) where pet.behavior != .peek { pet.step(dt: 1.0 / 60, world: world, rng: &rng) }
        #expect(pet.behavior == .peek)
        #expect(pet.peekEdge == window.minX)
        #expect(pet.peekHidesRight) // the window is to the right
        #expect(pet.facing == .left) // looking back out
        #expect(pet.x > window.minX)
        // When done peeking it walks out and is no longer clipped.
        for _ in 0..<(60 * 8) where pet.behavior == .peek { pet.step(dt: 1.0 / 60, world: world, rng: &rng) }
        #expect(pet.peekEdge == nil)
    }

    @Test func noPeekingWhenDisabledOrWindowTooShort() {
        let short = Rect(x: 800, y: 0, width: 500, height: 30)
        var pet = Pet(x: 700, y: 0, facing: .right, behavior: .walk, duration: 100)
        pet.config.peekChance = 1
        var rng = SeededGenerator(seed: 2)
        for _ in 0..<(60 * 6) { pet.step(dt: 1.0 / 60, world: World(screens: [screen], windows: [short]), rng: &rng) }
        #expect(pet.behavior != .peek)
        var off = Pet(x: 700, y: 0, facing: .right, behavior: .walk, duration: 100)
        off.config.peekChance = 1
        off.config.enabledBehaviors.remove(.peek)
        let tall = Rect(x: 800, y: 0, width: 500, height: 600)
        for _ in 0..<(60 * 6) { off.step(dt: 1.0 / 60, world: World(screens: [screen], windows: [tall]), rng: &rng) }
        #expect(off.behavior != .peek)
    }

    @Test func climbsUpToNapOnTheMenuBar() {
        var world = World(screens: [screen])
        world.menuBars = [Rect(x: 0, y: screen.maxY, width: 1600, height: 25)]
        var pet = Pet(x: 1500, y: 0, facing: .right, behavior: .walk, duration: 1000)
        pet.config.climbChance = 1
        pet.config.menuNapChance = 1
        var rng = SeededGenerator(seed: 3)
        for _ in 0..<(60 * 60) where pet.behavior != .menuNap { pet.step(dt: 1.0 / 60, world: world, rng: &rng) }
        #expect(pet.behavior == .menuNap)
        #expect(pet.y == screen.maxY - 6)
        #expect(pet.x < screen.maxX)
        #expect(pet.facing == .left)
        // Eventually wakes up and drops back down to the floor.
        for _ in 0..<(60 * 40) where !(pet.behavior.isGrounded && pet.y == 0) { pet.step(dt: 1.0 / 60, world: world, rng: &rng) }
        #expect(pet.y == 0)
    }

    @Test func noMenuBarNoNap() {
        var pet = Pet(x: 1500, y: 0, facing: .right, behavior: .walk, duration: 1000)
        pet.config.climbChance = 1
        pet.config.menuNapChance = 1
        var rng = SeededGenerator(seed: 4)
        var sawNap = false
        for _ in 0..<(60 * 60) {
            pet.step(dt: 1.0 / 60, world: World(screens: [screen]), rng: &rng)
            if pet.behavior == .menuNap { sawNap = true }
        }
        #expect(!sawNap)
    }
}
