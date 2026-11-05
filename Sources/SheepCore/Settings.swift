/// How a new pet arrives on the desktop.
public enum EntryStyle: String, CaseIterable, Codable, Sendable {
    case drop, parachute, meteor, jetpack, random

    public var title: String {
        switch self {
        case .drop: return "Drop from the top"
        case .parachute: return "Parachute"
        case .meteor: return "Flaming meteor"
        case .jetpack: return "Jetpack"
        case .random: return "Surprise me"
        }
    }

    /// `random` picks one of the others.
    public func resolved<R: RandomNumberGenerator>(using rng: inout R) -> EntryStyle {
        guard self == .random else { return self }
        return [EntryStyle.drop, .parachute, .meteor, .jetpack].randomElement(using: &rng)!
    }
}

/// User preferences. Stored as JSON; unknown or missing keys fall back to defaults so
/// preferences survive app updates that add new settings.
public struct PetSettings: Codable, Equatable, Sendable {
    public static let maxPets = 20
    public static let speedRange: ClosedRange<Double> = 0.25...3

    /// Idle behaviors the user can switch off. Standing can't be disabled.
    public static let toggleableBehaviors: [Behavior] = [.walk, .run, .sit, .sleep, .eat, .call]

    public var petCount = 1
    public var animal: AnimalChoice = .only(.sheep)
    public var entryStyle: EntryStyle = .drop
    public var finaleStyle: FinaleStyle = .random
    public var walkOnWindows = true
    /// Pets may walk off the edge of the screen and disappear.
    public var walkOffScreen = false
    /// After a pet walks off, sometimes a new one shows up a little later.
    public var newPetAfterWalkOff = true
    /// Stored as the disabled set so behaviors added in later versions start enabled.
    public var disabledBehaviors: Set<Behavior> = []
    /// Multiplies walking and running speed.
    public var speed = 1.0

    public init() {}

    public var enabledBehaviors: Set<Behavior> {
        Set(Behavior.allCases).subtracting(disabledBehaviors)
    }

    public func isEnabled(_ behavior: Behavior) -> Bool { !disabledBehaviors.contains(behavior) }

    public mutating func setEnabled(_ behavior: Behavior, _ enabled: Bool) {
        if enabled { disabledBehaviors.remove(behavior) } else { disabledBehaviors.insert(behavior) }
    }

    /// Values forced into their valid ranges.
    public func clamped() -> PetSettings {
        var s = self
        s.petCount = min(max(petCount, 0), Self.maxPets)
        s.speed = min(max(speed.isFinite ? speed : 1, Self.speedRange.lowerBound), Self.speedRange.upperBound)
        s.disabledBehaviors = disabledBehaviors.intersection(Self.toggleableBehaviors)
        return s
    }

    /// Applies the settings that affect simulation to a sheep config.
    public func apply(to config: inout PetConfig) {
        config.speedMultiplier = speed
        config.enabledBehaviors = enabledBehaviors
        config.walkOffScreen = walkOffScreen
    }

    private enum CodingKeys: String, CodingKey {
        case petCount, animal, entryStyle, finaleStyle, walkOnWindows, walkOffScreen, newPetAfterWalkOff, disabledBehaviors, speed
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = PetSettings()
        petCount = (try? c.decodeIfPresent(Int.self, forKey: .petCount)) ?? d.petCount
        animal = (try? c.decodeIfPresent(AnimalChoice.self, forKey: .animal)) ?? d.animal
        entryStyle = (try? c.decodeIfPresent(EntryStyle.self, forKey: .entryStyle)) ?? d.entryStyle
        finaleStyle = (try? c.decodeIfPresent(FinaleStyle.self, forKey: .finaleStyle)) ?? d.finaleStyle
        walkOnWindows = (try? c.decodeIfPresent(Bool.self, forKey: .walkOnWindows)) ?? d.walkOnWindows
        walkOffScreen = (try? c.decodeIfPresent(Bool.self, forKey: .walkOffScreen)) ?? d.walkOffScreen
        newPetAfterWalkOff = (try? c.decodeIfPresent(Bool.self, forKey: .newPetAfterWalkOff)) ?? d.newPetAfterWalkOff
        // Decode names one by one so a behavior removed in a later version doesn't drop the rest.
        let names = (try? c.decodeIfPresent([String].self, forKey: .disabledBehaviors)) ?? []
        disabledBehaviors = Set(names.map { $0 == "bleat" ? "call" : $0 }.compactMap(Behavior.init(rawValue:)))
        speed = (try? c.decodeIfPresent(Double.self, forKey: .speed)) ?? d.speed
        self = clamped()
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(petCount, forKey: .petCount)
        try c.encode(animal, forKey: .animal)
        try c.encode(entryStyle, forKey: .entryStyle)
        try c.encode(finaleStyle, forKey: .finaleStyle)
        try c.encode(walkOnWindows, forKey: .walkOnWindows)
        try c.encode(walkOffScreen, forKey: .walkOffScreen)
        try c.encode(newPetAfterWalkOff, forKey: .newPetAfterWalkOff)
        try c.encode(disabledBehaviors.map(\.rawValue).sorted(), forKey: .disabledBehaviors)
        try c.encode(speed, forKey: .speed)
    }
}
