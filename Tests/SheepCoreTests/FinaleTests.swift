import Foundation
import Testing
@testable import SheepCore

@Suite struct FinaleTests {
    let world = World(screens: [Rect(x: 0, y: 0, width: 1200, height: 800)])

    private func runUntilGone(_ pets: inout [Pet], limit: Double = 20) -> [Double] {
        var rng = SeededGenerator(seed: 1)
        var goneAt = Array(repeating: -1.0, count: pets.count)
        var t = 0.0
        while t < limit && goneAt.contains(-1) {
            t += 1.0 / 60
            for i in pets.indices {
                pets[i].step(dt: 1.0 / 60, world: world, rng: &rng)
                if pets[i].isGone && goneAt[i] < 0 { goneAt[i] = t }
            }
        }
        return goneAt
    }

    @Test(arguments: FinaleStyle.concrete)
    func everyStyleCountsDownThenRemovesThePet(_ style: FinaleStyle) {
        var pets = [Pet(x: 300, y: 0, behavior: .walk, duration: 100)]
        pets[0].beginFinale(style: style)
        #expect(pets[0].behavior == .countdown)
        #expect(pets[0].finaleStyle == style)
        let goneAt = runUntilGone(&pets)
        #expect(goneAt[0] > PetArt.countdownSeconds)
        #expect(goneAt[0] <= PetArt.countdownSeconds + PetArt.finaleDuration(style) + 0.1)
    }

    @Test func allPetsGoAtTheSameMoment() {
        var pets = (0..<5).map { i in Pet(x: Double(100 + i * 200), y: 0, animal: Animal.allCases[i], behavior: .stand, duration: 100) }
        for i in pets.indices { pets[i].beginFinale(style: .explode) }
        var rng = SeededGenerator(seed: 2)
        for _ in 0..<Int(PetArt.countdownSeconds * 60 + 2) {
            for i in pets.indices { pets[i].step(dt: 1.0 / 60, world: world, rng: &rng) }
        }
        #expect(pets.allSatisfy { $0.behavior == .finale })
        let goneAt = runUntilGone(&pets)
        #expect(Set(goneAt).count == 1)
    }

    @Test func cannotBeDraggedOrRestartedDuringFinale() {
        var pet = Pet(x: 300, y: 0, behavior: .stand, duration: 100)
        pet.beginFinale(style: .vanish)
        pet.beginDrag()
        #expect(pet.behavior == .countdown)
        pet.beginFinale(style: .burn)
        #expect(pet.finaleStyle == .vanish)
    }

    @Test func randomResolvesToAConcreteStyle() {
        for seed in 0..<20 {
            var pet = Pet(x: 300, y: 0, behavior: .stand, duration: 100)
            pet.phase = Double(seed) / 20
            pet.beginFinale(style: .random)
            #expect(FinaleStyle.concrete.contains(pet.finaleStyle))
        }
    }

    @Test(arguments: FinaleStyle.concrete)
    func finaleFramesRenderAndEndEmptyOrTiny(_ style: FinaleStyle) {
        let frames = PetArt.frames(for: .finale, finale: style)
        #expect(!frames.isEmpty)
        let first = PetArt.render(frames[0])
        let last = PetArt.render(frames[frames.count - 1])
        #expect(first != last || style == .balloons)
        if style != .balloons {
            let solid = last.pixels.filter { PetArt.isSolid($0) }.count
            let before = PetArt.render(Pose()).pixels.filter { PetArt.isSolid($0) }.count
            #expect(solid < before / 3, "\(style) leaves too much behind")
        }
    }

    @Test func countdownShowsThreeTwoOne() {
        let digits = (0..<3).map { PetArt.pose(for: .countdown, time: Double($0) + 0.5).gear }
        #expect(digits == [.countdown(3), .countdown(2), .countdown(1)])
        // Holds the last digit rather than looping.
        #expect(PetArt.pose(for: .countdown, time: 10).gear == .countdown(1))
    }

    @Test func finaleSettingRoundTrips() throws {
        var s = PetSettings()
        s.finaleStyle = .balloons
        #expect(try JSONDecoder().decode(PetSettings.self, from: JSONEncoder().encode(s)).finaleStyle == .balloons)
    }
}
