import Testing
@testable import SheepCore

@Suite struct EntryTests {
    let screen = Rect(x: 0, y: 80, width: 1400, height: 800)
    var world: World { World(screens: [screen]) }

    private func arrive(_ style: EntryStyle, seed: UInt64, seconds: Double = 20) -> (Pet, [Behavior]) {
        var rng = SeededGenerator(seed: seed)
        var pet = Pet.spawn(in: world, rng: &rng, entry: style)
        var seen = [pet.behavior]
        for _ in 0..<Int(seconds * 60) {
            pet.step(dt: 1.0 / 60, world: world, rng: &rng)
            if seen.last != pet.behavior { seen.append(pet.behavior) }
        }
        return (pet, seen)
    }

    @Test(arguments: [EntryStyle.drop, .parachute, .meteor, .jetpack, .random])
    func everyStyleLandsOnScreen(_ style: EntryStyle) {
        for seed in UInt64(1)...20 {
            let (pet, seen) = arrive(style, seed: seed)
            // Landed (it may be off climbing by now), and still on the screen.
            #expect(seen.contains { $0.isGrounded }, "\(style) seed \(seed)")
            #expect(!seen.last!.isEntry, "\(style) seed \(seed)")
            #expect(screen.contains(x: pet.x, y: pet.y), "\(style) seed \(seed)")
        }
    }

    @Test func parachuteDriftsDownSlowly() {
        var rng = SeededGenerator(seed: 3)
        var pet = Pet.spawn(in: world, rng: &rng, entry: .parachute)
        #expect(pet.behavior == .parachute)
        let startY = pet.y
        for _ in 0..<60 { pet.step(dt: 1.0 / 60, world: world, rng: &rng) }
        #expect(abs((startY - pet.y) - pet.config.parachuteSpeed) < 1)
    }

    @Test func meteorStartsAboveTheScreenAndLandsDazed() {
        let (_, seen) = arrive(.meteor, seed: 4)
        #expect(seen.first == .meteor)
        #expect(seen.dropFirst().first == .impact)
        var rng = SeededGenerator(seed: 4)
        let pet = Pet.spawn(in: world, rng: &rng, entry: .meteor)
        #expect(pet.y > screen.maxY)
    }

    @Test func jetpackFliesInFromTheSide() {
        var rng = SeededGenerator(seed: 5)
        let pet = Pet.spawn(in: world, rng: &rng, entry: .jetpack)
        #expect(pet.behavior == .jetpack)
        #expect(pet.x < screen.minX || pet.x > screen.maxX)
        #expect((pet.x < screen.minX) == (pet.facing == .right))
        let (landed, seen) = arrive(.jetpack, seed: 5)
        #expect(seen.contains(.stand) || landed.behavior.isGrounded)
    }

    @Test func randomPicksVariousStyles() {
        var rng = SeededGenerator(seed: 6)
        let styles = Set((0..<100).map { _ in EntryStyle.random.resolved(using: &rng) })
        #expect(styles == [.drop, .parachute, .meteor, .jetpack])
    }

    @Test func entriesCanBeGrabbedMidAir() {
        var rng = SeededGenerator(seed: 7)
        var pet = Pet.spawn(in: world, rng: &rng, entry: .parachute)
        pet.beginDrag()
        pet.drag(toX: 300, y: 500, dt: 0.1)
        pet.endDrag()
        #expect(pet.behavior == .fall)
    }

    @Test func entryArtHasGear() {
        for b in [Behavior.parachute, .meteor, .jetpack, .impact] {
            for pose in PetArt.frames(for: b) {
                #expect(pose.gear != .none)
                let withGear = PetArt.render(pose)
                var plain = pose
                plain.gear = .none
                #expect(withGear != PetArt.render(plain), "\(b)")
            }
        }
    }
}
