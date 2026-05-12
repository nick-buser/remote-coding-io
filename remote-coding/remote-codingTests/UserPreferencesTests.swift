import Foundation
import Testing
@testable import remote_coding

struct UserPreferencesTests {

    private func makeStore(file: StaticString = #file, line: UInt = #line) -> UserDefaults {
        let suiteName = "UserPreferencesTests-\(UUID().uuidString)"
        let store = UserDefaults(suiteName: suiteName)!
        store.removePersistentDomain(forName: suiteName)
        return store
    }

    // MARK: - Defaults

    @MainActor
    @Test func defaultsAreSaneOnFirstLaunch() async {
        let prefs = UserPreferences(store: makeStore())

        #expect(prefs.displayName == "You")
        #expect(prefs.defaultProjectID == nil)
        #expect(prefs.accent == .iris)
        #expect(prefs.textSize == .default)
        #expect(prefs.appearance == .system)
        #expect(prefs.pushToken == nil)
        #expect(prefs.mutedProjectIDs.isEmpty)
        #expect(prefs.quietHoursStart == nil)
        #expect(prefs.quietHoursEnd == nil)
    }

    // MARK: - Push fields

    @MainActor
    @Test func pushTokenPersistsAndCanBeCleared() async {
        let store = makeStore()
        let first = UserPreferences(store: store)
        first.pushToken = "abc123"

        let second = UserPreferences(store: store)
        #expect(second.pushToken == "abc123")

        second.pushToken = nil
        let third = UserPreferences(store: store)
        #expect(third.pushToken == nil)
    }

    @MainActor
    @Test func mutedProjectIDsAndQuietHoursPersist() async {
        let store = makeStore()
        let first = UserPreferences(store: store)
        first.mutedProjectIDs = [1, 7, 42]
        first.quietHoursStart = 22
        first.quietHoursEnd = 7

        let second = UserPreferences(store: store)
        #expect(second.mutedProjectIDs == [1, 7, 42])
        #expect(second.quietHoursStart == 22)
        #expect(second.quietHoursEnd == 7)

        second.quietHoursStart = nil
        second.quietHoursEnd = nil
        let third = UserPreferences(store: store)
        #expect(third.quietHoursStart == nil)
        #expect(third.quietHoursEnd == nil)
    }

    // MARK: - Persistence

    @MainActor
    @Test func accentPersistsAcrossInstances() async {
        let store = makeStore()
        let first = UserPreferences(store: store)
        first.accent = .mint

        let second = UserPreferences(store: store)

        #expect(second.accent == .mint)
    }

    @MainActor
    @Test func defaultProjectIDPersistsAndCanBeCleared() async {
        let store = makeStore()
        let first = UserPreferences(store: store)
        first.defaultProjectID = 42

        let second = UserPreferences(store: store)
        #expect(second.defaultProjectID == 42)

        second.defaultProjectID = nil
        let third = UserPreferences(store: store)
        #expect(third.defaultProjectID == nil)
    }

    @MainActor
    @Test func textSizeAndAppearancePersist() async {
        let store = makeStore()
        let first = UserPreferences(store: store)
        first.textSize = .large
        first.appearance = .dark

        let second = UserPreferences(store: store)

        #expect(second.textSize == .large)
        #expect(second.appearance == .dark)
    }

    @MainActor
    @Test func displayNamePersistsAndOverridesDefault() async {
        let store = makeStore()
        let first = UserPreferences(store: store)
        first.displayName = "Nick"

        let second = UserPreferences(store: store)
        #expect(second.displayName == "Nick")
    }

    // MARK: - Mappings

    @MainActor
    @Test func appearanceModePreferredColorSchemeMatchesCases() async {
        #expect(UserPreferences.AppearanceMode.light.preferredColorScheme == .light)
        #expect(UserPreferences.AppearanceMode.dark.preferredColorScheme == .dark)
        #expect(UserPreferences.AppearanceMode.system.preferredColorScheme == nil)
    }

    @MainActor
    @Test func textSizeMapsToDistinctDynamicTypeSizes() async {
        let small = UserPreferences.TextSize.small.dynamicTypeSize
        let medium = UserPreferences.TextSize.default.dynamicTypeSize
        let large = UserPreferences.TextSize.large.dynamicTypeSize

        #expect(small != medium)
        #expect(medium != large)
    }

    @MainActor
    @Test func corruptedAccentRawFallsBackToIris() async {
        let store = makeStore()
        store.set("garbage", forKey: "user.accent")

        let prefs = UserPreferences(store: store)

        #expect(prefs.accent == .iris)
    }
}
