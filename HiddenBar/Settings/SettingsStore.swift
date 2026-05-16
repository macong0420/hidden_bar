import Combine
import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    private enum Key {
        static let preferences = "com.HiddenBar.preferences.v1"
    }

    private let defaults: UserDefaults
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    @Published private(set) var preferences: AppPreferences

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let data = defaults.data(forKey: Key.preferences),
           let stored = try? JSONDecoder().decode(AppPreferences.self, from: data) {
            preferences = stored
        } else {
            preferences = .default
        }
    }

    func update(_ transform: (inout AppPreferences) -> Void) {
        var next = preferences
        transform(&next)
        guard next != preferences else { return }
        preferences = next
        persistPreferences()
    }

    private func persistPreferences() {
        do {
            let data = try encoder.encode(preferences)
            defaults.set(data, forKey: Key.preferences)
        } catch {
            Logger.app.error("Failed to encode preferences: \(error.localizedDescription)")
        }
    }
}
