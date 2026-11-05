import Foundation
import Testing
@testable import SheepCore

@Suite struct SettingsTests {
    @Test func roundTripsThroughJSON() throws {
        var s = PetSettings()
        s.petCount = 4
        s.walkOnWindows = false
        s.speed = 1.5
        s.setEnabled(.sleep, false)
        let data = try JSONEncoder().encode(s)
        #expect(try JSONDecoder().decode(PetSettings.self, from: data) == s)
    }

    @Test func missingAndUnknownKeysFallBackToDefaults() throws {
        let json = #"{"petCount": 3, "futureSetting": true, "disabledBehaviors": ["sleep", "teleport"]}"#
        let s = try JSONDecoder().decode(PetSettings.self, from: Data(json.utf8))
        #expect(s.petCount == 3)
        #expect(s.walkOnWindows == PetSettings().walkOnWindows)
        #expect(s.speed == 1)
        #expect(s.disabledBehaviors == [.sleep])
    }

    @Test func clampsOutOfRangeValues() throws {
        let json = #"{"petCount": 500, "speed": 99}"#
        let s = try JSONDecoder().decode(PetSettings.self, from: Data(json.utf8))
        #expect(s.petCount == PetSettings.maxPets)
        #expect(s.speed == PetSettings.speedRange.upperBound)
        var t = PetSettings()
        t.petCount = -3
        t.setEnabled(.fall, false) // not user-toggleable
        #expect(t.clamped().petCount == 0)
        #expect(t.clamped().disabledBehaviors.isEmpty)
    }

    @Test func disabledBehaviorsAreNeverChosen() {
        var settings = PetSettings()
        for b in [Behavior.run, .sleep, .eat, .bleat] { settings.setEnabled(b, false) }
        var config = SheepConfig()
        settings.apply(to: &config)
        let world = World(screens: [Rect(x: 0, y: 0, width: 1000, height: 700)])
        var sheep = Sheep(x: 500, y: 0, behavior: .stand, duration: 0.1, config: config)
        var rng = SeededGenerator(seed: 5)
        var seen = Set<Behavior>()
        for _ in 0..<(60 * 60 * 10) {
            sheep.step(dt: 1.0 / 60, world: world, rng: &rng)
            seen.insert(sheep.behavior)
        }
        #expect(seen.isDisjoint(with: [.run, .sleep, .eat, .bleat]))
        #expect(seen.contains(.walk) && seen.contains(.sit))
    }

    @Test func disablingCurrentBehaviorStopsIt() {
        var sheep = Sheep(x: 500, y: 0, behavior: .eat, duration: 100)
        var config = sheep.config
        config.enabledBehaviors.remove(.eat)
        sheep.apply(config)
        #expect(sheep.behavior == .stand)
    }

    @Test func speedMultiplierMakesWalkingFaster() {
        let world = World(screens: [Rect(x: 0, y: 0, width: 5000, height: 700)])
        var slow = Sheep(x: 1000, y: 0, facing: .right, behavior: .walk, duration: 100)
        var fast = slow
        var config = fast.config
        config.speedMultiplier = 2
        fast.apply(config)
        var rng = SeededGenerator(seed: 1)
        for _ in 0..<60 {
            slow.step(dt: 1.0 / 60, world: world, rng: &rng)
            fast.step(dt: 1.0 / 60, world: world, rng: &rng)
        }
        #expect(abs((fast.x - 1000) - 2 * (slow.x - 1000)) < 0.001)
    }
}
