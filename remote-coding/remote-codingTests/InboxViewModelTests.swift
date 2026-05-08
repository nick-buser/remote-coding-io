import Foundation
import Testing
@testable import remote_coding

struct InboxViewModelTests {

    // MARK: - Helpers

    private static let baseDate = Date(timeIntervalSince1970: 1_730_000_000)

    private func makeEvent(
        id: Int64,
        kind: Components.Schemas.ActivityKind,
        minutesAgo: Double,
        projectID: Int64? = 1,
        featureID: Int64? = 11,
        ticketID: Int64? = 200,
        verb: String = "did the thing",
        detail: String? = "more context",
        actorName: String? = "session-04",
        now: Date = baseDate
    ) -> Components.Schemas.ActivityEvent {
        Components.Schemas.ActivityEvent(
            id: id,
            projectId: projectID,
            featureId: featureID,
            ticketId: ticketID,
            actor: .agent,
            actorName: actorName,
            verb: verb,
            kind: kind,
            detail: detail,
            createdAt: now.addingTimeInterval(-minutesAgo * 60)
        )
    }

    private func tinyFixture(now: Date) -> [Components.Schemas.ActivityEvent] {
        // 5 events: question (15m), review (45m), recent decision (30m),
        // old decision (4h), commit earlier today (3h).
        [
            makeEvent(id: 1, kind: .question, minutesAgo: 15, now: now),
            makeEvent(id: 2, kind: .review,   minutesAgo: 45, now: now),
            makeEvent(id: 3, kind: .decision, minutesAgo: 30, now: now),
            makeEvent(id: 4, kind: .decision, minutesAgo: 240, now: now),
            makeEvent(id: 5, kind: .commit,   minutesAgo: 180, now: now)
        ]
    }

    // MARK: - Grouping

    @MainActor
    @Test func needsYouContainsQuestionsReviewsAndRecentDecisions() async {
        let viewModel = InboxViewModel()
        let now = Self.baseDate
        let events = tinyFixture(now: now)

        let needsYou = viewModel.needsYouEvents(from: events, now: now)
        let ids = Set(needsYou.map(\.id))

        #expect(ids == [1, 2, 3])
    }

    @MainActor
    @Test func earlierTodayExcludesNeedsYouAndOldDecisions() async {
        let viewModel = InboxViewModel()
        // Use a "now" that's safely past the start of its local day so
        // both 4h-old events stay within the day window.
        let now = Calendar.current.startOfDay(for: Self.baseDate).addingTimeInterval(20 * 3600)
        let events = tinyFixture(now: now)

        let earlier = viewModel.earlierTodayEvents(from: events, now: now)
        let ids = Set(earlier.map(\.id))

        // The old decision (4h) and the commit (3h) are still within
        // the local day; the recent decision moved into needs-you.
        #expect(ids == [4, 5])
    }

    @MainActor
    @Test func earlierTodayDropsEventsBeforeStartOfDay() async {
        let viewModel = InboxViewModel()
        // Place "now" 30 minutes after start-of-day so a 60-minute-old
        // event falls outside today.
        let now = Calendar.current.startOfDay(for: Self.baseDate).addingTimeInterval(30 * 60)
        let events = [
            makeEvent(id: 10, kind: .commit, minutesAgo: 60, now: now)
        ]

        let earlier = viewModel.earlierTodayEvents(from: events, now: now)

        #expect(earlier.isEmpty)
    }

    // MARK: - Filter counts and apply

    @MainActor
    @Test func filterCountsMatchPredicate() async {
        let viewModel = InboxViewModel()
        let events = tinyFixture(now: Self.baseDate)

        let counts = viewModel.filterCounts(from: events)

        #expect(counts[.all] == 5)
        #expect(counts[.questions] == 1)
        #expect(counts[.reviews] == 1)
        #expect(counts[.decisions] == 2)
    }

    @MainActor
    @Test func applyFilterCollapsesEventsToSelection() async {
        let viewModel = InboxViewModel()
        viewModel.selectedFilter = .questions
        let events = tinyFixture(now: Self.baseDate)

        let filtered = viewModel.applyFilter(events)

        #expect(filtered.count == 1)
        #expect(filtered.first?.kind == .question)
    }

    @MainActor
    @Test func applyFilterIsIdentityForAll() async {
        let viewModel = InboxViewModel()
        let events = tinyFixture(now: Self.baseDate)

        let filtered = viewModel.applyFilter(events)

        #expect(filtered.map(\.id) == events.map(\.id))
    }

    // MARK: - Optimistic hide

    @MainActor
    @Test func visibleEventsExcludesPendingHidden() async {
        let viewModel = InboxViewModel()
        viewModel.pendingHidden.insert(2)
        let events = tinyFixture(now: Self.baseDate)

        let visible = viewModel.visibleEvents(from: events)

        #expect(visible.map(\.id) == [1, 3, 4, 5])
    }

    @MainActor
    @Test func filterCountsAccountForPendingHidden() async {
        let viewModel = InboxViewModel()
        viewModel.pendingHidden.insert(2)  // hide the review
        let events = tinyFixture(now: Self.baseDate)

        let counts = viewModel.filterCounts(from: events)

        #expect(counts[.all] == 4)
        #expect(counts[.reviews] == 0)
    }

    // MARK: - Accent resolver

    @MainActor
    @Test func accentColorMappingCoversV2AndLegacyValues() async {
        #expect(InboxViewModel.accentColor(forRaw: "iris") == .iris)
        #expect(InboxViewModel.accentColor(forRaw: "amber") == .amber)
        #expect(InboxViewModel.accentColor(forRaw: "mint") == .mint)
        #expect(InboxViewModel.accentColor(forRaw: "rose") == .rose)
        #expect(InboxViewModel.accentColor(forRaw: "slate") == .slate)
        #expect(InboxViewModel.accentColor(forRaw: "indigo") == .iris)
        #expect(InboxViewModel.accentColor(forRaw: "teal") == .mint)
        #expect(InboxViewModel.accentColor(forRaw: "green") == .mint)
        #expect(InboxViewModel.accentColor(forRaw: "yellow") == .amber)
        #expect(InboxViewModel.accentColor(forRaw: "")  == .iris)
    }

    @MainActor
    @Test func loadAccentsCachesProjectsAndPicksMatchingAccent() async throws {
        let viewModel = InboxViewModel()
        let repository = MockTmuxAgentRepository()

        await viewModel.loadAccentsIfNeeded(repository: repository)

        // The seed has projects with accents "indigo" → .iris and "teal"
        // → .mint. Check both via the public accessor.
        let projects = try await repository.listProjects()
        for project in projects {
            let resolved = viewModel.accent(forProjectID: project.id)
            let expected = InboxViewModel.accentColor(forRaw: project.accent ?? "")
            #expect(resolved == expected)
        }
    }

    // MARK: - Pane parsing

    @MainActor
    @Test func parsePaneIDHandlesStandardAndDegenerateInputs() async {
        #expect(InboxViewModel.parsePaneID("agent:1.0") == 0)
        #expect(InboxViewModel.parsePaneID("session:0.3") == 3)
        #expect(InboxViewModel.parsePaneID("0") == 0)
        #expect(InboxViewModel.parsePaneID(nil) == nil)
        #expect(InboxViewModel.parsePaneID("garbage") == nil)
    }

    // MARK: - Fallback route

    @MainActor
    @Test func fallbackRoutePrefersFeatureDetail() async {
        let viewModel = InboxViewModel()
        let event = makeEvent(id: 99, kind: .doc, minutesAgo: 5, featureID: 21, ticketID: nil)

        let route = viewModel.fallbackRoute(for: event)

        #expect(route == .featureDetail(featureID: 21))
    }

    @MainActor
    @Test func fallbackRouteIsNilWhenNoFeature() async {
        let viewModel = InboxViewModel()
        let event = makeEvent(id: 100, kind: .doc, minutesAgo: 5, projectID: nil, featureID: nil, ticketID: nil)

        let route = viewModel.fallbackRoute(for: event)

        #expect(route == nil)
    }

    // MARK: - Resolution against the mock repo

    @MainActor
    @Test func resolveTicketPublicIDFindsSeededTicket() async {
        let viewModel = InboxViewModel()
        let repository = MockTmuxAgentRepository()
        // Seed: TMX-0042 = ticket id 200, feature 11.
        let event = makeEvent(id: 1, kind: .question, minutesAgo: 5, featureID: 11, ticketID: 200)

        let publicID = await viewModel.resolveTicketPublicID(for: event, repository: repository)

        #expect(publicID == "TMX-0042")
    }

    @MainActor
    @Test func resolveTicketPublicIDIsNilWhenIdsMissing() async {
        let viewModel = InboxViewModel()
        let repository = MockTmuxAgentRepository()
        let event = makeEvent(id: 1, kind: .doc, minutesAgo: 5, featureID: nil, ticketID: nil)

        let publicID = await viewModel.resolveTicketPublicID(for: event, repository: repository)

        #expect(publicID == nil)
    }

    @MainActor
    @Test func approveOptimisticallyHidesEventAndCallsRepo() async throws {
        let viewModel = InboxViewModel()
        let repository = MockTmuxAgentRepository()
        // Seed: TMX-0050 = ticket id 208, feature 21, status .inReview.
        let event = makeEvent(id: 1, kind: .review, minutesAgo: 5, featureID: 21, ticketID: 208)

        await viewModel.approve(event: event, repository: repository)

        #expect(viewModel.pendingHidden.contains(1))
        let ticket = try await repository.getTicket(publicID: "TMX-0050")
        #expect(ticket.status == .done)
    }

    // MARK: - Subtitle

    @MainActor
    @Test func subtitleIncludesLiveSessionsWhenKnown() async {
        let viewModel = InboxViewModel()

        let subtitle = viewModel.subtitle(needsYouCount: 3, liveSessionsCount: 2)

        #expect(subtitle == "3 need you · 2 sessions live")
    }

    @MainActor
    @Test func subtitleOmitsSessionsWhenUnknown() async {
        let viewModel = InboxViewModel()

        let subtitle = viewModel.subtitle(needsYouCount: 0, liveSessionsCount: nil)

        #expect(subtitle == "0 need you")
    }

    // MARK: - Relative time

    @MainActor
    @Test func relativeTimeShortShapes() async {
        let now = Self.baseDate
        #expect(InboxRelativeTime.short(now.addingTimeInterval(-30), now: now) == "Just now")
        #expect(InboxRelativeTime.short(now.addingTimeInterval(-60 * 5), now: now) == "5m")
        #expect(InboxRelativeTime.short(now.addingTimeInterval(-60 * 60 * 2), now: now) == "2h")
        #expect(InboxRelativeTime.short(now.addingTimeInterval(-60 * 60 * 24 * 3), now: now) == "3d")
    }
}
