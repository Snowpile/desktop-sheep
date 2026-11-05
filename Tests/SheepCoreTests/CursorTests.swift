import Testing
@testable import SheepCore

@Suite struct CursorTests {
    let world = World(screens: [Rect(x: 0, y: 0, width: 1600, height: 900)])

    private func pet(_ x: Double, _ b: Behavior = .stand, facing: Facing = .right) -> Pet {
        var p = Pet(x: x, y: 0, facing: facing, behavior: b, duration: 100)
        p.id = 1
        return p
    }

    private func run(_ pets: inout [Pet], cursor: CursorInput, seconds: Double, treats: inout [Treat], seed: UInt64 = 1) {
        var rng = SeededGenerator(seed: seed)
        for _ in 0..<Int(seconds * 60) {
            for i in pets.indices { pets[i].step(dt: 1.0 / 60, world: world, rng: &rng) }
            Cursor.react(&pets, cursor: cursor, dt: 1.0 / 60, rng: &rng)
            Cursor.step(&treats, pets: &pets, world: world, dt: 1.0 / 60, rng: &rng)
        }
    }

    @Test func idlePetsLookAtTheCursor() {
        var pets = [pet(500, .sit, facing: .right)]
        var treats: [Treat] = []
        run(&pets, cursor: CursorInput(x: 380, y: 40, speed: 0), seconds: 0.1, treats: &treats)
        #expect(pets[0].facing == .left)
    }

    @Test func fastCursorNearbyStartlesThenTheyRunAway() {
        var pets = [pet(500)]
        var treats: [Treat] = []
        run(&pets, cursor: CursorInput(x: 540, y: 30, speed: 4000), seconds: 0.05, treats: &treats)
        #expect(pets[0].behavior == .startled)
        #expect(pets[0].facing == .left)
        run(&pets, cursor: CursorInput(x: 540, y: 30, speed: 0), seconds: 0.8, treats: &treats)
        #expect(pets[0].behavior == .run || pets[0].behavior == .stand)
        #expect(pets[0].facing == .left)
    }

    @Test func slowCursorDoesNotStartle() {
        var pets = [pet(500)]
        var treats: [Treat] = []
        run(&pets, cursor: CursorInput(x: 540, y: 30, speed: 300), seconds: 0.5, treats: &treats)
        #expect(pets[0].behavior != .startled)
    }

    @Test func sometimesChasesTheCursorAndCatchesIt() {
        var pets = [pet(300)]
        var treats: [Treat] = []
        var rng = SeededGenerator(seed: 4)
        var chased = false
        for _ in 0..<(60 * 600) where !chased {
            pets[0].step(dt: 1.0 / 60, world: world, rng: &rng)
            Cursor.react(&pets, cursor: CursorInput(x: 700, y: 20, speed: 0), dt: 1.0 / 60, rng: &rng)
            chased = pets[0].behavior == .chaseCursor
        }
        #expect(chased)
        #expect(pets[0].facing == .right)
        run(&pets, cursor: CursorInput(x: pets[0].x + 150, y: 20, speed: 0), seconds: 4, treats: &treats)
        #expect(pets[0].behavior != .chaseCursor || pets[0].x > 300)
    }

    @Test func disabledReactionsDoNothing() {
        var p = pet(500)
        p.config.enabledBehaviors.subtract([.startled, .chaseCursor])
        var pets = [p]
        var treats: [Treat] = []
        run(&pets, cursor: CursorInput(x: 540, y: 30, speed: 5000), seconds: 30, treats: &treats)
        #expect(pets[0].behavior != .startled && pets[0].behavior != .chaseCursor)
    }

    @Test func treatFallsAndTheNearestPetRunsOverToEatIt() {
        var near = pet(700), far = pet(1400)
        far.id = 2
        var pets = [near, far]
        var treats = [Treat(id: 1, x: 900, y: 400)]
        run(&pets, cursor: CursorInput(x: -1000, y: -1000, speed: 0), seconds: 1.0, treats: &treats)
        #expect(treats.first?.landed == true)
        #expect(pets[0].treatID == 1)
        #expect(pets[0].behavior == .fetchTreat)
        #expect(pets[1].treatID == nil)
        run(&pets, cursor: CursorInput(x: -1000, y: -1000, speed: 0), seconds: 8, treats: &treats)
        #expect(treats.isEmpty)
        #expect(abs(pets[0].x - 900) < 40)
        near = pets[0]
        #expect(near.treatID == nil)
    }

    @Test func treatLandsOnAWindow() {
        let window = Rect(x: 800, y: 0, width: 300, height: 300)
        let w = World(screens: world.screens, windowTops: World.windowTops(frontToBack: [window], screens: world.screens, headroom: 64))
        var treats = [Treat(id: 1, x: 900, y: 600)]
        var pets: [Pet] = []
        var rng = SeededGenerator(seed: 1)
        for _ in 0..<60 { Cursor.step(&treats, pets: &pets, world: w, dt: 1.0 / 60, rng: &rng) }
        #expect(treats[0].landed && treats[0].y == 300)
    }

    @Test func treatSpriteDraws() {
        #expect(!PetArt.treatSprite().isBlank)
    }
}
