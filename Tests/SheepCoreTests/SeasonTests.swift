import Testing
@testable import SheepCore

@Suite struct SeasonTests {
    @Test func monthsAndHours() {
        #expect(Seasonal.forMonth(12) == .santaHat)
        #expect(Seasonal.forMonth(10) == .pumpkin)
        #expect(Seasonal.forMonth(7) == .none)
        #expect(DayPart.forHour(23) == .night && DayPart.forHour(3) == .night)
        #expect(DayPart.forHour(7) == .morning)
        #expect(DayPart.forHour(13) == .day)
        #expect(DayPart.forHour(19) == .evening)
    }

    private func share(of behaviors: Set<Behavior>, dayPart: DayPart) -> Double {
        var pet = Pet(x: 500, y: 0, behavior: .stand, duration: 0.5)
        pet.config.dayPart = dayPart
        let world = World(screens: [Rect(x: 0, y: 0, width: 1000, height: 700)])
        var rng = SeededGenerator(seed: 8)
        var hits = 0, total = 0
        for _ in 0..<(60 * 60 * 30) {
            pet.step(dt: 1.0 / 60, world: world, rng: &rng)
            total += 1
            if behaviors.contains(pet.behavior) { hits += 1 }
        }
        return Double(hits) / Double(total)
    }

    @Test func sleepierAtNightLivelierInTheMorning() {
        let nightSleep = share(of: [.sleep], dayPart: .night)
        let daySleep = share(of: [.sleep], dayPart: .day)
        let morningSleep = share(of: [.sleep], dayPart: .morning)
        #expect(nightSleep > daySleep * 1.5)
        #expect(morningSleep < daySleep)
        #expect(share(of: [.run], dayPart: .morning) > share(of: [.run], dayPart: .night))
    }

    @Test func settingsControlTimeAndSeason() {
        var s = PetSettings()
        var config = PetConfig()
        s.apply(to: &config, hour: 2, month: 12)
        #expect(config.dayPart == .night && config.seasonal == .santaHat)
        s.timeOfDay = false
        s.seasonalTouches = false
        s.apply(to: &config, hour: 2, month: 12)
        #expect(config.dayPart == .day && config.seasonal == .none)
    }

    @Test func petPoseCarriesTheSeasonAndTheArtShowsIt() {
        var pet = Pet(x: 0, y: 0, behavior: .stand, duration: 10)
        pet.config.seasonal = .santaHat
        #expect(pet.pose.seasonal == .santaHat)
        let plain = PetArt.render(Pose())
        var hatted = Pose()
        hatted.seasonal = .santaHat
        #expect(PetArt.render(hatted) != plain)
        var sitting = PetArt.frames(for: .sit)[0]
        let sitPlain = PetArt.render(sitting)
        sitting.seasonal = .pumpkin
        #expect(PetArt.render(sitting) != sitPlain)
        // No pumpkin while just standing around.
        var standing = Pose()
        standing.seasonal = .pumpkin
        #expect(PetArt.render(standing) == plain)
    }
}
