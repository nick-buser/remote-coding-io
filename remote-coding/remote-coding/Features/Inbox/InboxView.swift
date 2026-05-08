import SwiftUI

/// Inbox tab body — the v2 home screen.
///
/// Reads the workspace-scoped `ActivityPoller` from `AppModel`, renders
/// the `Needs you` and `Earlier today` sections, and handles inline
/// actions (Approve / Reply) plus tap-to-route. The surrounding
/// `NavigationStack` lives on `ContentView`; this view is the stack's
/// root for the Inbox tab.
struct InboxView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(RootCoordinator.self) private var coordinator
    @Environment(\.colorScheme) private var scheme
    @State private var viewModel = InboxViewModel()
    @State private var replyContext: ReplyContext?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.s4) {
                header
                chips
                content
            }
            .padding(.bottom, Theme.Spacing.s5)
        }
        .background(Theme.Surface.bg(scheme))
        .toolbar(.hidden, for: .navigationBar)
        .refreshable {
            await viewModel.refresh(poller: appModel.activityPoller)
        }
        .task {
            appModel.activityPoller.markSeen()
            await viewModel.loadAccentsIfNeeded(repository: appModel.repository)
            await viewModel.loadLiveSessionsIfNeeded(repository: appModel.repository)
        }
        .sheet(item: $replyContext) { context in
            ReplySheet(context: context)
                .environment(appModel)
        }
        .alert(
            "Inbox error",
            isPresented: Binding(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            ),
            actions: { Button("OK") { viewModel.error = nil } },
            message: { Text(viewModel.error ?? "") }
        )
    }

    // MARK: - Header / chips

    private var header: some View {
        let needsYou = viewModel.needsYouEvents(from: appModel.activityPoller.events)
        let subtitle = viewModel.subtitle(
            needsYouCount: needsYou.count,
            liveSessionsCount: viewModel.liveSessionsCount
        )
        return LargeTitleHeader(title: "Inbox", subtitle: subtitle) {
            HStack(spacing: 8) {
                NavIconButton(name: .filter) {
                    // Filter sheet is a follow-up; chips below cover the
                    // primary filter affordance.
                }
                NavIconButton(name: .compose, accent: appModel.accent, tinted: true) {
                    // Compose sheet lands later — see service-0013 follow-ups.
                    print("[Inbox] compose tapped")
                }
            }
        }
    }

    private var chips: some View {
        let counts = viewModel.filterCounts(from: appModel.activityPoller.events)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(InboxFilter.displayed, id: \.self) { filter in
                    Button {
                        viewModel.selectedFilter = filter
                    } label: {
                        Chip(
                            label: filter.label,
                            count: (counts[filter] ?? 0) > 0 ? counts[filter] : nil,
                            active: filter == viewModel.selectedFilter
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.s4)
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var content: some View {
        let baseEvents = appModel.activityPoller.events
        let needsYouAll = viewModel.needsYouEvents(from: baseEvents)
        let earlierAll = viewModel.earlierTodayEvents(from: baseEvents)
        let needsYou = viewModel.applyFilter(needsYouAll)
        let earlier = viewModel.applyFilter(earlierAll)

        if needsYouAll.isEmpty && earlierAll.isEmpty {
            allClearEmptyState
        } else if viewModel.selectedFilter != .all && needsYou.isEmpty && earlier.isEmpty {
            EmptyState(
                systemImage: "tray",
                title: "Nothing matches",
                message: "Try a different filter to see more events."
            )
            .padding(.top, Theme.Spacing.s4)
        } else {
            if !needsYou.isEmpty {
                section(title: "Needs you", events: needsYou)
            } else if viewModel.selectedFilter == .all {
                allClearEmptyState
                    .padding(.top, Theme.Spacing.s2)
            }

            if !earlier.isEmpty {
                section(title: "Earlier today", events: earlier)
            }
        }
    }

    private var allClearEmptyState: some View {
        EmptyState(
            systemImage: "envelope",
            title: "All clear",
            message: "Agents are working. They'll find you here when they need something."
        )
        .padding(.top, Theme.Spacing.s5)
    }

    private func section(title: String, events: [Components.Schemas.ActivityEvent]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s2) {
            Text(title.uppercased())
                .themeMonoSm()
                .foregroundStyle(Theme.Text.fg2(scheme))
                .padding(.horizontal, Theme.Spacing.s4)
            RoundedCard {
                VStack(spacing: 8) {
                    ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                        if index > 0 {
                            Divider()
                                .background(Theme.Surface.sep(scheme))
                        }
                        InboxRow(
                            event: event,
                            rowAccent: viewModel.accent(forProjectID: event.projectId),
                            onTap: { handleRowTap(event) },
                            onPrimaryAction: { handlePrimary(event) },
                            onSecondaryAction: { handleSecondary(event) }
                        )
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.s4)
        }
    }

    // MARK: - Actions

    private func handleRowTap(_ event: Components.Schemas.ActivityEvent) {
        Task {
            if let route = await viewModel.route(for: event, repository: appModel.repository) {
                coordinator.push(route, in: .inbox)
            }
        }
    }

    private func handlePrimary(_ event: Components.Schemas.ActivityEvent) {
        switch event.kind {
        case .question:
            Task {
                if let context = await viewModel.replyContext(for: event, repository: appModel.repository) {
                    replyContext = context
                } else {
                    viewModel.error = "Couldn't open a reply for this question."
                }
            }
        case .review:
            Task {
                await viewModel.approve(event: event, repository: appModel.repository)
            }
        default:
            handleRowTap(event)
        }
    }

    private func handleSecondary(_ event: Components.Schemas.ActivityEvent) {
        // Question / review secondary actions both route the user to a
        // detail surface; route() picks the right one per kind.
        handleRowTap(event)
    }
}

// MARK: - ReplyContext Identifiable

extension ReplyContext: Identifiable {
    var id: Int64 { eventID }
}

// MARK: - Previews

#Preview("Inbox — light") {
    let model = AppModel(repository: MockTmuxAgentRepository())
    return NavigationStack {
        InboxView()
    }
    .environment(model)
    .environment(RootCoordinator())
    .task {
        await model.activityPoller.tick()
    }
}

#Preview("Inbox — dark") {
    let model = AppModel(repository: MockTmuxAgentRepository())
    return NavigationStack {
        InboxView()
    }
    .environment(model)
    .environment(RootCoordinator())
    .preferredColorScheme(.dark)
    .task {
        await model.activityPoller.tick()
    }
}

#Preview("Inbox — all clear") {
    let model = AppModel(repository: EmptyInboxRepository())
    return NavigationStack {
        InboxView()
    }
    .environment(model)
    .environment(RootCoordinator())
}

/// Preview-only repository that returns no activity events but still
/// surfaces the seeded projects so the accent resolver has data.
@MainActor
private final class EmptyInboxRepository: TmuxAgentRepository {
    private let underlying = MockTmuxAgentRepository()

    func listProjects() async throws -> [Components.Schemas.Project] {
        try await underlying.listProjects()
    }
    func getProject(idOrSlug: String) async throws -> Components.Schemas.Project {
        try await underlying.getProject(idOrSlug: idOrSlug)
    }
    func updateProject(idOrSlug: String, body: Components.Schemas.UpdateProjectRequest) async throws -> Components.Schemas.Project {
        try await underlying.updateProject(idOrSlug: idOrSlug, body: body)
    }
    func createProject(_ body: Components.Schemas.CreateProjectRequest) async throws -> Components.Schemas.Project {
        try await underlying.createProject(body)
    }
    func listFeatures(projectIDOrSlug: String) async throws -> [Components.Schemas.Feature] {
        try await underlying.listFeatures(projectIDOrSlug: projectIDOrSlug)
    }
    func getFeature(id: Int64) async throws -> Components.Schemas.Feature {
        try await underlying.getFeature(id: id)
    }
    func updateFeatureStatus(id: Int64, body: Components.Schemas.UpdateFeatureStatusRequest) async throws -> Components.Schemas.Feature {
        try await underlying.updateFeatureStatus(id: id, body: body)
    }
    func listTickets(featureID: Int64, status: Components.Schemas.TicketStatus?) async throws -> [Components.Schemas.Ticket] {
        try await underlying.listTickets(featureID: featureID, status: status)
    }
    func getTicket(publicID: String) async throws -> Components.Schemas.Ticket {
        try await underlying.getTicket(publicID: publicID)
    }
    func createTicket(featureID: Int64, body: Components.Schemas.CreateTicketRequest) async throws -> Components.Schemas.Ticket {
        try await underlying.createTicket(featureID: featureID, body: body)
    }
    func updateTicket(publicID: String, body: Components.Schemas.UpdateTicketRequest) async throws -> Components.Schemas.Ticket {
        try await underlying.updateTicket(publicID: publicID, body: body)
    }
    func listCriteria(ticketPublicID: String) async throws -> [Components.Schemas.AcceptanceCriterion] {
        try await underlying.listCriteria(ticketPublicID: ticketPublicID)
    }
    func createCriterion(ticketPublicID: String, body: Components.Schemas.CreateAcceptanceCriterionRequest) async throws -> Components.Schemas.AcceptanceCriterion {
        try await underlying.createCriterion(ticketPublicID: ticketPublicID, body: body)
    }
    func updateCriterion(id: Int64, body: Components.Schemas.UpdateAcceptanceCriterionRequest) async throws -> Components.Schemas.AcceptanceCriterion {
        try await underlying.updateCriterion(id: id, body: body)
    }
    func deleteCriterion(id: Int64) async throws {
        try await underlying.deleteCriterion(id: id)
    }
    func listFeatureDocs(featureID: Int64) async throws -> [Components.Schemas.Doc] {
        try await underlying.listFeatureDocs(featureID: featureID)
    }
    func getDoc(id: Int64) async throws -> Components.Schemas.Doc {
        try await underlying.getDoc(id: id)
    }
    func createFeatureDoc(featureID: Int64, body: Components.Schemas.CreateDocRequest) async throws -> Components.Schemas.Doc {
        try await underlying.createFeatureDoc(featureID: featureID, body: body)
    }
    func updateDoc(id: Int64, body: Components.Schemas.UpdateDocRequest) async throws -> Components.Schemas.Doc {
        try await underlying.updateDoc(id: id, body: body)
    }
    func deleteDoc(id: Int64) async throws {
        try await underlying.deleteDoc(id: id)
    }
    func listFeatureDecisions(featureID: Int64) async throws -> [Components.Schemas.Decision] {
        try await underlying.listFeatureDecisions(featureID: featureID)
    }
    func createFeatureDecision(featureID: Int64, body: Components.Schemas.CreateDecisionRequest) async throws -> Components.Schemas.Decision {
        try await underlying.createFeatureDecision(featureID: featureID, body: body)
    }
    func deleteDecision(id: Int64) async throws {
        try await underlying.deleteDecision(id: id)
    }
    func listActivity(project: String?, feature: Int64?, since: Date?, limit: Int?) async throws -> [Components.Schemas.ActivityEvent] {
        []
    }
    func listProjectAgentSessions(projectIDOrSlug: String) async throws -> [Components.Schemas.AgentSession] {
        []
    }
    func listTicketAgentSessions(ticketPublicID: String) async throws -> [Components.Schemas.AgentSession] {
        try await underlying.listTicketAgentSessions(ticketPublicID: ticketPublicID)
    }
    func createAgentSession(_ body: Components.Schemas.CreateAgentSessionRequest) async throws -> Components.Schemas.AgentSession {
        try await underlying.createAgentSession(body)
    }
    func getTicketDiff(publicID: String) async throws -> Components.Schemas.TicketDiff {
        try await underlying.getTicketDiff(publicID: publicID)
    }
    func approveTicket(publicID: String) async throws -> Components.Schemas.Ticket {
        try await underlying.approveTicket(publicID: publicID)
    }
    func requestTicketChanges(publicID: String, comment: String?) async throws -> Components.Schemas.Ticket {
        try await underlying.requestTicketChanges(publicID: publicID, comment: comment)
    }
    func sendTicketBack(publicID: String, comment: String?) async throws -> Components.Schemas.Ticket {
        try await underlying.sendTicketBack(publicID: publicID, comment: comment)
    }
    func listProjectDocuments(projectID: Int64) async throws -> [LocalProjectNote] {
        try await underlying.listProjectDocuments(projectID: projectID)
    }
    func saveDocument(_ document: LocalProjectNote) async throws -> LocalProjectNote {
        try await underlying.saveDocument(document)
    }
    func openProjectSession(idOrSlug: String) async throws -> Components.Schemas.Project {
        try await underlying.openProjectSession(idOrSlug: idOrSlug)
    }
    func listSessions(projectID: Int64) async throws -> [Components.Schemas.Session] {
        try await underlying.listSessions(projectID: projectID)
    }
    func listSessions(featureID: Int64) async throws -> [Components.Schemas.Session] {
        try await underlying.listSessions(featureID: featureID)
    }
    func listSessions() async throws -> [Components.Schemas.Session] {
        try await underlying.listSessions()
    }
    func listPanes(sessionName: String) async throws -> [Components.Schemas.Pane] {
        try await underlying.listPanes(sessionName: sessionName)
    }
    func getPaneOutput(sessionName: String, paneID: Int) async throws -> Components.Schemas.PaneOutput {
        try await underlying.getPaneOutput(sessionName: sessionName, paneID: paneID)
    }
    func sendPaneInput(sessionName: String, paneID: Int, body: Components.Schemas.SendInputRequest) async throws -> Components.Schemas.StatusResponse {
        try await underlying.sendPaneInput(sessionName: sessionName, paneID: paneID, body: body)
    }
}
