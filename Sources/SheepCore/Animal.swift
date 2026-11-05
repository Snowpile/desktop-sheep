/// The kinds of pet. Every animal supports the same behaviors, with its own flavor.
public enum Animal: String, CaseIterable, Codable, Sendable {
    case sheep, cat, dog, bunny, redPanda

    public var title: String {
        switch self {
        case .sheep: return "Sheep"
        case .cat: return "Cat"
        case .dog: return "Dog"
        case .bunny: return "Bunny"
        case .redPanda: return "Red Panda"
        }
    }

    /// What the `call` behavior is for this animal.
    public var callName: String {
        switch self {
        case .sheep: return "bleat"
        case .cat: return "meow"
        case .dog: return "bark"
        case .bunny: return "squeak"
        case .redPanda: return "chirp"
        }
    }

    /// What it eats during the `eat` behavior.
    public var foodName: String {
        switch self {
        case .sheep: return "grass"
        case .cat: return "fish"
        case .dog: return "a bone"
        case .bunny: return "a carrot"
        case .redPanda: return "bamboo"
        }
    }

    /// Bunnies hop: they only move forward while in the air.
    public var hops: Bool { self == .bunny }
}

/// Which animal new pets should be.
public enum AnimalChoice: Codable, Hashable, Sendable {
    case only(Animal)
    /// Each new pet is a random animal.
    case mixed

    public static let all: [AnimalChoice] = Animal.allCases.map { .only($0) } + [.mixed]

    public var title: String {
        switch self {
        case let .only(animal): return animal.title
        case .mixed: return "Mixed"
        }
    }

    public func pick<R: RandomNumberGenerator>(using rng: inout R) -> Animal {
        switch self {
        case let .only(animal): return animal
        case .mixed: return Animal.allCases.randomElement(using: &rng)!
        }
    }

    /// Stored as a single string: an animal's raw value or "mixed".
    public var storageValue: String {
        switch self {
        case let .only(animal): return animal.rawValue
        case .mixed: return "mixed"
        }
    }

    public init?(storageValue: String) {
        if storageValue == "mixed" { self = .mixed; return }
        guard let animal = Animal(rawValue: storageValue) else { return nil }
        self = .only(animal)
    }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = AnimalChoice(storageValue: raw) ?? .only(.sheep)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(storageValue)
    }
}
