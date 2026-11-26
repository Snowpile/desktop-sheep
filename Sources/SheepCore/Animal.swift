/// The kinds of pet. Every animal supports the same behaviors, with its own flavor.
public enum Animal: String, CaseIterable, Codable, Sendable {
    case sheep, cat, dog, bunny, redPanda, pig, hippo, elephant, flyingSquirrel, tiger

    public var title: String {
        switch self {
        case .sheep: return "Sheep"
        case .cat: return "Cat"
        case .dog: return "Dog"
        case .bunny: return "Bunny"
        case .redPanda: return "Red Panda"
        case .pig: return "Pig"
        case .hippo: return "Baby Hippo"
        case .elephant: return "Elephant"
        case .flyingSquirrel: return "Flying Squirrel"
        case .tiger: return "Tiger"
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
        case .pig: return "oink"
        case .hippo: return "honk"
        case .elephant: return "trumpet"
        case .flyingSquirrel: return "chitter"
        case .tiger: return "roar"
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
        case .pig: return "an apple"
        case .hippo: return "watermelon"
        case .elephant: return "peanuts"
        case .flyingSquirrel: return "an acorn"
        case .tiger: return "a drumstick"
        }
    }

    /// Tigers now and then hunt down another pet and eat it (it comes back a little later).
    public var hunts: Bool { self == .tiger }

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
