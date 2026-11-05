/// Seasonal decorations.
public enum Seasonal: String, Hashable, Sendable {
    case none, santaHat, pumpkin

    /// Santa hats in December, pumpkins in October.
    public static func forMonth(_ month: Int) -> Seasonal {
        switch month {
        case 12: return .santaHat
        case 10: return .pumpkin
        default: return .none
        }
    }
}

/// Part of the day, which nudges how lively pets are.
public enum DayPart: String, Sendable {
    case morning, day, evening, night

    public static func forHour(_ hour: Int) -> DayPart {
        switch hour {
        case 6..<10: return .morning
        case 10..<18: return .day
        case 18..<22: return .evening
        default: return .night
        }
    }

    /// Multiplier for a behavior's chance of being picked next.
    public func weight(for behavior: Behavior) -> Double {
        switch (self, behavior) {
        case (.night, .sleep): return 3.5
        case (.night, .sit), (.night, .yawn): return 2
        case (.night, .run), (.night, .playFight), (.night, .butterfly), (.night, .tumble), (.night, .dig): return 0.3
        case (.night, .walk): return 0.6
        case (.morning, .run), (.morning, .playFight), (.morning, .butterfly): return 1.8
        case (.morning, .walk): return 1.3
        case (.morning, .sleep): return 0.3
        case (.evening, .sit), (.evening, .yawn): return 1.4
        case (.evening, .sleep): return 1.5
        default: return 1
        }
    }

    /// Multiplier for how long a behavior lasts (sleep runs long at night).
    public func durationScale(for behavior: Behavior) -> Double {
        switch (self, behavior) {
        case (.night, .sleep): return 2
        case (.morning, .sleep): return 0.6
        default: return 1
        }
    }
}
