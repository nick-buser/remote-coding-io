import Foundation
import Observation
import SwiftUI

/// Centralised `@Observable` store for user-facing preferences.
///
/// Persists through `UserDefaults` (one key per preference, all
/// namespaced) so the values survive launch. The store is constructed
/// once at app start and shared via the SwiftUI environment, so any
/// mutation triggers re-renders in the consuming views automatically.
@MainActor
@Observable
final class UserPreferences {
    var displayName: String {
        didSet { store.set(displayName, forKey: Keys.displayName) }
    }
    var defaultProjectID: Int64? {
        didSet {
            if let id = defaultProjectID {
                store.set(id, forKey: Keys.defaultProjectID)
            } else {
                store.removeObject(forKey: Keys.defaultProjectID)
            }
        }
    }
    var accent: AccentColor {
        didSet { store.set(accent.rawValue, forKey: Keys.accent) }
    }
    var textSize: TextSize {
        didSet { store.set(textSize.rawValue, forKey: Keys.textSize) }
    }
    var appearance: AppearanceMode {
        didSet { store.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    /// Lowercase hex APNs token. `nil` when push has not been registered
    /// (either the user denied authorization or hasn't been prompted).
    /// Cleared on deregister.
    var pushToken: String? {
        didSet {
            if let token = pushToken {
                store.set(token, forKey: Keys.pushToken)
            } else {
                store.removeObject(forKey: Keys.pushToken)
            }
        }
    }

    /// Project IDs the user has muted server-side. Filtered before
    /// dispatch in the backend — the device receives nothing for these.
    var mutedProjectIDs: [Int64] {
        didSet {
            store.set(mutedProjectIDs.map(NSNumber.init), forKey: Keys.mutedProjectIDs)
        }
    }

    /// Quiet hours window, expressed as UTC hours 0–23.
    /// Both must be set to enable filtering server-side. Wrap-past-midnight
    /// is supported (end < start means "from start to next-day end").
    var quietHoursStart: Int? {
        didSet { setOptionalInt(quietHoursStart, forKey: Keys.quietHoursStart) }
    }

    var quietHoursEnd: Int? {
        didSet { setOptionalInt(quietHoursEnd, forKey: Keys.quietHoursEnd) }
    }

    enum TextSize: String, Hashable, CaseIterable, Codable, Sendable {
        case small
        case `default`
        case large

        var dynamicTypeSize: DynamicTypeSize {
            switch self {
            case .small:    return .small
            case .default:  return .medium
            case .large:    return .xLarge
            }
        }

        var label: String {
            switch self {
            case .small:    return "Small"
            case .default:  return "Default"
            case .large:    return "Large"
            }
        }
    }

    enum AppearanceMode: String, Hashable, CaseIterable, Codable, Sendable {
        case light
        case dark
        case system

        /// `nil` for `.system` so SwiftUI falls back to the device
        /// setting; `.light` / `.dark` force the appearance.
        var preferredColorScheme: ColorScheme? {
            switch self {
            case .light:  return .light
            case .dark:   return .dark
            case .system: return nil
            }
        }

        var label: String {
            switch self {
            case .light:  return "Light"
            case .dark:   return "Dark"
            case .system: return "System"
            }
        }
    }

    private enum Keys {
        static let displayName     = "user.displayName"
        static let defaultProjectID = "user.defaultProjectID"
        static let accent          = "user.accent"
        static let textSize        = "user.textSize"
        static let appearance      = "user.appearance"
        static let pushToken       = "user.pushToken"
        static let mutedProjectIDs = "user.mutedProjectIDs"
        static let quietHoursStart = "user.quietHoursStart"
        static let quietHoursEnd   = "user.quietHoursEnd"
    }

    private func setOptionalInt(_ value: Int?, forKey key: String) {
        if let value {
            store.set(value, forKey: key)
        } else {
            store.removeObject(forKey: key)
        }
    }

    @ObservationIgnored private let store: UserDefaults

    init(store: UserDefaults = .standard) {
        self.store = store
        self.displayName = (store.string(forKey: Keys.displayName) ?? "").nonEmptyOrDefault("You")

        let storedID = store.object(forKey: Keys.defaultProjectID) as? Int64
        self.defaultProjectID = storedID

        if let raw = store.string(forKey: Keys.accent),
           let parsed = AccentColor(rawValue: raw) {
            self.accent = parsed
        } else {
            self.accent = .iris
        }

        if let raw = store.string(forKey: Keys.textSize),
           let parsed = TextSize(rawValue: raw) {
            self.textSize = parsed
        } else {
            self.textSize = .default
        }

        if let raw = store.string(forKey: Keys.appearance),
           let parsed = AppearanceMode(rawValue: raw) {
            self.appearance = parsed
        } else {
            self.appearance = .system
        }

        self.pushToken = store.string(forKey: Keys.pushToken)

        let storedMuted = (store.array(forKey: Keys.mutedProjectIDs) as? [NSNumber]) ?? []
        self.mutedProjectIDs = storedMuted.map { $0.int64Value }

        self.quietHoursStart = store.object(forKey: Keys.quietHoursStart) as? Int
        self.quietHoursEnd = store.object(forKey: Keys.quietHoursEnd) as? Int
    }
}

private extension String {
    func nonEmptyOrDefault(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}
