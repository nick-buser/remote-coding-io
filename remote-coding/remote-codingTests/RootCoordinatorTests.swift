import Foundation
import Testing
@testable import remote_coding

struct RootCoordinatorTests {

    // MARK: - Helpers

    /// Each test gets its own isolated `UserDefaults` so persistence
    /// behaviour is testable without polluting the standard suite.
    private func makeStore(file: StaticString = #file, line: UInt = #line) -> UserDefaults {
        let suiteName = "RootCoordinatorTests-\(UUID().uuidString)"
        let store = UserDefaults(suiteName: suiteName)!
        store.removePersistentDomain(forName: suiteName)
        return store
    }

    // MARK: - AppRoute Codable

    /// Each `AppRoute` case must round-trip through JSON unchanged so
    /// path persistence is lossless.
    @Test func appRouteRoundTripsThroughJSON() throws {
        let cases: [AppRoute] = [
            .projectDetail(idOrSlug: "tmux-server-coding-app"),
            .featureDetail(featureID: 11),
            .ticketDetail(publicID: "PRJ-01-T-0042"),
            .docDetail(docID: 7),
            .sessionsForFeature(featureID: 21),
            .agentSession(sessionID: 99),
        ]

        for route in cases {
            let data = try JSONEncoder().encode(route)
            let decoded = try JSONDecoder().decode(AppRoute.self, from: data)
            #expect(decoded == route)
        }
    }

    /// Pin the wire format so a future refactor doesn't silently flip
    /// to a less-readable encoding (e.g. `{"_0": ...}`).
    @Test func appRouteEncodesAsFlatDiscriminatorPair() throws {
        let route = AppRoute.projectDetail(idOrSlug: "tmux-server-coding-app")

        let data = try JSONEncoder().encode(route)
        let json = try JSONSerialization.jsonObject(with: data) as? [Any]

        #expect(json?.count == 2)
        #expect(json?[0] as? String == "projectDetail")
        #expect(json?[1] as? String == "tmux-server-coding-app")
    }

    // MARK: - Coordinator state

    @Test func freshCoordinatorLandsOnInboxWithEmptyPaths() {
        let coordinator = RootCoordinator(store: makeStore(), storeKey: "fresh")

        #expect(coordinator.selectedTab == .inbox)
        for tab in AppTab.allCases {
            #expect(coordinator.paths[tab] == [])
        }
    }

    /// The headline acceptance criterion: push then popToRoot clears
    /// the path.
    @Test func pushThenPopToRootClearsThePath() {
        let coordinator = RootCoordinator(store: makeStore(), storeKey: "push-pop")
        coordinator.switchTab(.projects)

        coordinator.push(.featureDetail(featureID: 11))

        #expect(coordinator.paths[.projects] == [.featureDetail(featureID: 11)])

        coordinator.popToRoot(in: .projects)

        #expect(coordinator.paths[.projects] == [])
    }

    @Test func pushWithExplicitTabIgnoresActiveTab() {
        let coordinator = RootCoordinator(store: makeStore(), storeKey: "explicit-tab")
        coordinator.switchTab(.inbox)

        coordinator.push(.projectDetail(idOrSlug: "tmux-server-coding-app"), in: .projects)

        #expect(coordinator.paths[.inbox] == [])
        #expect(coordinator.paths[.projects] == [.projectDetail(idOrSlug: "tmux-server-coding-app")])
    }

    @Test func switchTabUpdatesSelectedTab() {
        let coordinator = RootCoordinator(store: makeStore(), storeKey: "switch")

        coordinator.switchTab(.sessions)

        #expect(coordinator.selectedTab == .sessions)
    }

    // MARK: - Persistence

    /// Mutations made on one coordinator must be visible to a fresh
    /// coordinator opened against the same store. This is the
    /// "fresh install lands on .inbox; existing install restores its
    /// drill-down" guarantee at the persistence boundary.
    @Test func mutationsPersistAcrossCoordinatorRebuilds() {
        let store = makeStore()
        let key = "persist"

        do {
            let first = RootCoordinator(store: store, storeKey: key)
            first.switchTab(.projects)
            first.push(.projectDetail(idOrSlug: "tmux-server-coding-app"))
            first.push(.featureDetail(featureID: 11))
        }

        let restored = RootCoordinator(store: store, storeKey: key)

        #expect(restored.selectedTab == .projects)
        #expect(restored.paths[.projects] == [
            .projectDetail(idOrSlug: "tmux-server-coding-app"),
            .featureDetail(featureID: 11),
        ])
        #expect(restored.paths[.inbox] == [])
    }

    /// Switching tabs after pushing in another tab preserves that
    /// tab's drill-down — the per-tab path model isn't a global
    /// stack.
    @Test func switchingTabsPreservesOtherTabPaths() {
        let coordinator = RootCoordinator(store: makeStore(), storeKey: "preserve")

        coordinator.switchTab(.projects)
        coordinator.push(.projectDetail(idOrSlug: "tmux-server-coding-app"))
        coordinator.switchTab(.inbox)

        #expect(coordinator.selectedTab == .inbox)
        #expect(coordinator.paths[.projects] == [.projectDetail(idOrSlug: "tmux-server-coding-app")])

        coordinator.switchTab(.projects)

        #expect(coordinator.paths[.projects] == [.projectDetail(idOrSlug: "tmux-server-coding-app")])
    }

    /// A garbage persisted blob must not crash startup — the
    /// coordinator falls back to defaults silently.
    @Test func corruptPersistedStateFallsBackToDefaults() {
        let store = makeStore()
        let key = "corrupt"
        store.set(Data("not json".utf8), forKey: key)

        let coordinator = RootCoordinator(store: store, storeKey: key)

        #expect(coordinator.selectedTab == .inbox)
        for tab in AppTab.allCases {
            #expect(coordinator.paths[tab] == [])
        }
    }
}
