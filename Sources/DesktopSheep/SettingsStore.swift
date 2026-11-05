import Foundation
import SheepCore

/// Persists `PetSettings` in UserDefaults and tells observers when they change.
@MainActor
final class SettingsStore {
    private static let key = "settings.v1"
    private let defaults: UserDefaults
    private var observers: [(PetSettings) -> Void] = []
    /// When false, changes apply for this session only (used by `--count`).
    var persists = true

    var settings: PetSettings {
        didSet {
            settings = settings.clamped()
            guard settings != oldValue else { return }
            save()
            observers.forEach { $0(settings) }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(PetSettings.self, from: data) {
            settings = saved
        } else {
            settings = PetSettings()
            // Carry over the pre-settings "walk on windows" toggle.
            if let old = defaults.object(forKey: "walkOnWindows") as? Bool { settings.walkOnWindows = old }
        }
    }

    func observe(_ observer: @escaping (PetSettings) -> Void) { observers.append(observer) }

    func update(_ change: (inout PetSettings) -> Void) {
        var s = settings
        change(&s)
        settings = s
    }

    private func save() {
        guard persists else { return }
        if let data = try? JSONEncoder().encode(settings) { defaults.set(data, forKey: Self.key) }
    }
}
