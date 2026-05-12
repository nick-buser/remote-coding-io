import Foundation
import Observation
import SwiftUI

/// Owns per-tab `NavigationStack` paths and the active tab. One
/// `RootCoordinator` is injected into the SwiftUI environment from
/// `RemoteCodingApp` and read by `ContentView` plus any view that
/// needs to push a route.
///
/// State is persisted to `UserDefaults` on every mutation and
/// restored on init. `Restoration` is best-effort: if the persisted
/// blob can't be decoded the coordinator returns to `.inbox` with
/// empty paths. Callers don't need to opt in.
@Observable
final class RootCoordinator {
    /// Active tab in the bottom shell.
    var selectedTab: AppTab {
        didSet { persist() }
    }

    /// Per-tab navigation stack contents. The dictionary always
    /// contains an entry for every `AppTab` case after init; an
    /// empty array is the tab-root state.
    var paths: [AppTab: [AppRoute]] {
        didSet { persist() }
    }

    @ObservationIgnored private let store: UserDefaults
    @ObservationIgnored private let storeKey: String

    /// `store` is overridable so tests can inject an isolated
    /// `UserDefaults(suiteName:)` and so previews don't pollute
    /// the real defaults database.
    init(
        store: UserDefaults = .standard,
        storeKey: String = "RootCoordinator.state.v1"
    ) {
        self.store = store
        self.storeKey = storeKey
        let restored = Self.restore(from: store, key: storeKey)
        self.selectedTab = restored?.selectedTab ?? .inbox
        self.paths = restored?.paths ?? Self.emptyPaths()
    }

    func push(_ route: AppRoute, in tab: AppTab? = nil) {
        let target = tab ?? selectedTab
        var path = paths[target] ?? []
        path.append(route)
        paths[target] = path
    }

    /// Switches to the destination's tab and pushes its route (if any) onto
    /// that tab's stack. Used by deep-link surfaces (push notifications,
    /// universal links) to land the user on the right screen in one call.
    func navigate(to destination: PushDestination) {
        selectedTab = destination.tab
        if let route = destination.route {
            push(route, in: destination.tab)
        }
    }

    func popToRoot(in tab: AppTab) {
        paths[tab] = []
    }

    func switchTab(_ tab: AppTab) {
        selectedTab = tab
    }

    /// SwiftUI binding suitable for `NavigationStack(path:)`. Reads
    /// from `paths[tab]` (defaulting to an empty array if missing)
    /// and writes back through the observed setter so persistence
    /// stays in sync with stack edits performed by SwiftUI itself
    /// (e.g. swipe-back, pop on appear).
    func binding(for tab: AppTab) -> Binding<[AppRoute]> {
        Binding(
            get: { self.paths[tab] ?? [] },
            set: { self.paths[tab] = $0 }
        )
    }

    // MARK: - Persistence

    private struct PersistedState: Codable {
        let selectedTab: AppTab
        let paths: [AppTab: [AppRoute]]
    }

    private func persist() {
        let state = PersistedState(selectedTab: selectedTab, paths: paths)
        guard let data = try? JSONEncoder().encode(state) else { return }
        store.set(data, forKey: storeKey)
    }

    private static func restore(
        from store: UserDefaults,
        key: String
    ) -> (selectedTab: AppTab, paths: [AppTab: [AppRoute]])? {
        guard
            let data = store.data(forKey: key),
            let state = try? JSONDecoder().decode(PersistedState.self, from: data)
        else { return nil }
        return (state.selectedTab, sanitize(state.paths))
    }

    /// Hook for trimming routes whose target resource no longer
    /// exists. Today this only fills in missing tab keys so callers
    /// can rely on `paths[tab]` returning an entry. Async resource
    /// validation (stale `featureID`, deleted project) is the right
    /// thing to add here when the screen tickets land repository
    /// access; views are expected to render an unavailable state in
    /// the meantime rather than crash.
    private static func sanitize(_ paths: [AppTab: [AppRoute]]) -> [AppTab: [AppRoute]] {
        var result = emptyPaths()
        for (tab, path) in paths {
            result[tab] = path
        }
        return result
    }

    private static func emptyPaths() -> [AppTab: [AppRoute]] {
        Dictionary(uniqueKeysWithValues: AppTab.allCases.map { ($0, []) })
    }
}
