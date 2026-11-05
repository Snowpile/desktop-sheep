import Foundation
import Testing
@testable import SheepCore

@Suite struct AnimalTests {
    @Test func everyAnimalRendersEveryFrame() {
        for animal in Animal.allCases {
            for behavior in Behavior.allCases where behavior != .finale {
                for pose in PetArt.frames(for: behavior, animal: animal) {
                    let c = PetArt.render(pose, animal: animal)
                    #expect(!c.isBlank, "\(animal) \(behavior)")
                    // Something solid on the bottom row unless the pet is in the air.
                    if pose.lift == 0 && pose.shadow && ![.run, .chase, .flee, .chaseCursor, .fetchTreat].contains(behavior) { // gallops have an airborne frame
                        #expect((0..<c.width).contains { c.isSolid($0, PetArt.groundRow - 1) }, "\(animal) \(behavior)")
                    }
                }
            }
        }
    }

    @Test func animalsLookDifferent() {
        let renders = Animal.allCases.map { PetArt.render(Pose(), animal: $0) }
        #expect(Set(renders.map(\.pixels)).count == Animal.allCases.count)
    }

    @Test func callAndFoodEffectsDrawSomethingExtra() {
        for animal in Animal.allCases {
            var plain = Pose()
            plain.headDY = -2
            var calling = plain
            calling.effect = .call(2)
            #expect(PetArt.render(calling, animal: animal) != PetArt.render(plain, animal: animal), "\(animal)")
            var eating = Pose()
            eating.headDY = 7
            var withFood = eating
            withFood.effect = .food(0)
            #expect(PetArt.render(withFood, animal: animal) != PetArt.render(eating, animal: animal), "\(animal)")
        }
    }

    @Test func bunnyHopsInsteadOfWalking() {
        let world = World(screens: [Rect(x: 0, y: 0, width: 10_000, height: 700)])
        var bunny = Pet(x: 1000, y: 0, animal: .bunny, facing: .right, behavior: .walk, duration: 100)
        var sheep = Pet(x: 1000, y: 0, animal: .sheep, facing: .right, behavior: .walk, duration: 100)
        var rng = SeededGenerator(seed: 1)
        var stillFrames = 0
        for _ in 0..<(60 * 6) {
            let before = bunny.x
            bunny.step(dt: 1.0 / 60, world: world, rng: &rng)
            sheep.step(dt: 1.0 / 60, world: world, rng: &rng)
            if bunny.x == before { stillFrames += 1 }
        }
        #expect(stillFrames > 30) // pauses between hops
        // Same average speed as walking, within 15%.
        #expect(abs((bunny.x - 1000) / (sheep.x - 1000) - 1) < 0.15)
        #expect(PetArt.frames(for: .walk, animal: .bunny).contains { $0.lift > 0 })
        #expect(!PetArt.frames(for: .walk, animal: .sheep).contains { $0.lift > 0 })
    }

    @Test func animalChoiceRoundTripsAndMixedVaries() throws {
        for choice in AnimalChoice.all {
            let data = try JSONEncoder().encode([choice])
            #expect(try JSONDecoder().decode([AnimalChoice].self, from: data) == [choice])
        }
        var rng = SeededGenerator(seed: 9)
        let picks = Set((0..<200).map { _ in AnimalChoice.mixed.pick(using: &rng) })
        #expect(picks == Set(Animal.allCases))
        #expect(AnimalChoice.only(.cat).pick(using: &rng) == .cat)
    }

    @Test func settingsKeepAnimalAndUpgradeOldBleatToggle() throws {
        var s = PetSettings()
        s.animal = .only(.redPanda)
        let back = try JSONDecoder().decode(PetSettings.self, from: JSONEncoder().encode(s))
        #expect(back.animal == .only(.redPanda))
        let old = #"{"disabledBehaviors": ["bleat"], "animal": "dinosaur"}"#
        let upgraded = try JSONDecoder().decode(PetSettings.self, from: Data(old.utf8))
        #expect(upgraded.disabledBehaviors == [.call])
        #expect(upgraded.animal == .only(.sheep))
    }
}
