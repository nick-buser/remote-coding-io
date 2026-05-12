import SwiftUI

/// Sessions tab body — Awaiting hero + status-grouped list.
struct SessionsListView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(RootCoordinator.self) private var coordinator
    @Environment(PushRegistrationService.self) private var pushService
    @Environment(\.colorScheme) private var scheme

    @State private var viewModel = SessionsListViewModel()
    @State private var showSpawnSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.s4) {
                header
                content
            }
            .padding(.bottom, Theme.Spacing.s5)
        }
        .background(Theme.Surface.bg(scheme))
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.load(
                fetcher: CrossProjectFeatureFetcher(repository: appModel.repository),
                repository: appModel.repository
            )
            await pushService.requestPermissionIfNeeded()
        }
        .refreshable {
            await viewModel.load(
                fetcher: CrossProjectFeatureFetcher(repository: appModel.repository),
                repository: appModel.repository
            )
        }
        .sheet(isPresented: $showSpawnSheet) {
            EmptyState(
                systemImage: "plus.circle",
                title: "Spawn session",
                message: "The pickers (project → feature → ticket) ship in a follow-up to service-feature-sessions-tab."
            )
            .presentationDetents([.medium])
        }
    }

    // MARK: - Header

    private var header: some View {
        LargeTitleHeader(title: "Sessions", subtitle: viewModel.subtitle()) {
            NavIconButton(name: .plus, accent: appModel.accent, tinted: true) {
                showSpawnSheet = true
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.allSessions.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, Theme.Spacing.s5)
        } else if let errorMessage = viewModel.errorMessage, viewModel.allSessions.isEmpty {
            EmptyState(
                systemImage: "wifi.exclamationmark",
                title: "Couldn't load sessions",
                message: errorMessage
            )
        } else if viewModel.allSessions.isEmpty {
            allClearHero
        } else {
            heroBlock
            chips
            sectionsBody
        }
    }

    // MARK: - Hero

    private var heroBlock: some View {
        let awaiting = viewModel.heroAwaiting
        return VStack(alignment: .leading, spacing: 8) {
            Text("AWAITING YOU")
                .themeMonoSm()
                .foregroundStyle(Theme.Semantic.orange)
            Text("\(viewModel.awaitingSessions.count) session\(viewModel.awaitingSessions.count == 1 ? "" : "s")")
                .themeDisplayMedium()
                .foregroundStyle(Theme.Text.fg(scheme))
            if awaiting.isEmpty && viewModel.awaitingSessions.isEmpty {
                EmptyState(
                    systemImage: "checkmark.circle",
                    title: "All clear",
                    message: "Agents are working."
                )
            } else if !awaiting.isEmpty {
                VStack(spacing: Theme.Spacing.s3) {
                    ForEach(awaiting, id: \.id) { session in
                        awaitingCard(for: session)
                    }
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.s4)
    }

    private func awaitingCard(for session: Components.Schemas.AgentSession) -> some View {
        let metadata = viewModel.metadata(for: session)
        return RoundedCard(radius: 18) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Circle().fill(Theme.Semantic.orange).frame(width: 8, height: 8)
                    Text("session-\(session.id)")
                        .themeMonoSm()
                        .foregroundStyle(Theme.Text.fg2(scheme))
                    Spacer()
                    Text(session.uptime)
                        .themeMonoSm()
                        .foregroundStyle(Theme.Text.fg2(scheme))
                }
                Text(metadata.ticket?.title ?? session.tmuxSession)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.Text.fg(scheme))
                    .lineLimit(2)
                PillButton(title: "Open pane", role: .primary, accent: metadata.accent, wide: true) {
                    coordinator.push(.agentSession(sessionID: session.id), in: .sessions)
                }
            }
        }
    }

    private var allClearHero: some View {
        EmptyState(
            systemImage: "terminal",
            title: "No live sessions",
            message: "Spawn a session from a ticket to see it here."
        )
        .padding(.top, Theme.Spacing.s5)
    }

    // MARK: - Chips

    private var chips: some View {
        let counts = viewModel.filterCounts()
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SessionsListViewModel.SessionFilter.displayed, id: \.self) { filter in
                    Button {
                        viewModel.selectedFilter = filter
                    } label: {
                        Chip(
                            label: filter.label,
                            count: (counts[filter] ?? 0) > 0 ? counts[filter] : nil,
                            active: viewModel.selectedFilter == filter
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
    private var sectionsBody: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s4) {
            if shouldRender(.active) {
                section(title: "Active", sessions: viewModel.activeSessions)
            }
            if shouldRender(.awaiting), !viewModel.awaitingSection.isEmpty {
                section(title: "Awaiting", sessions: viewModel.awaitingSection)
            }
            if shouldRender(.idle) {
                section(title: "Idle", sessions: viewModel.idleSessions)
            }
        }
    }

    private func shouldRender(_ kind: SessionsListViewModel.SessionFilter) -> Bool {
        switch viewModel.selectedFilter {
        case .all:      return true
        case .active:   return kind == .active
        case .awaiting: return kind == .awaiting
        case .idle:     return kind == .idle
        }
    }

    private func section(title: String, sessions: [Components.Schemas.AgentSession]) -> some View {
        Group {
            if sessions.isEmpty {
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: Theme.Spacing.s2) {
                    Text(title.uppercased())
                        .themeMonoSm()
                        .foregroundStyle(Theme.Text.fg2(scheme))
                        .padding(.horizontal, Theme.Spacing.s4)
                    RoundedCard {
                        VStack(spacing: 8) {
                            ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                                if index > 0 {
                                    Divider().background(Theme.Surface.sep(scheme))
                                }
                                row(for: session)
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.s4)
                }
            }
        }
    }

    private func row(for session: Components.Schemas.AgentSession) -> some View {
        let metadata = viewModel.metadata(for: session)
        return SessionRow(
            session: session,
            ticketLabel: metadata.ticket?.publicId,
            onTap: {
                coordinator.push(.agentSession(sessionID: session.id), in: .sessions)
            }
        )
    }
}

#Preview("Sessions — light") {
    let appModel = AppModel(repository: MockTmuxAgentRepository())
    let preferences = UserPreferences()
    let pushService = PushRegistrationService(
        repositoryProvider: { appModel.repository },
        preferences: preferences,
        pushSystem: MockPushSystem(initialStatus: .denied)
    )
    return NavigationStack {
        SessionsListView()
    }
    .environment(appModel)
    .environment(RootCoordinator())
    .environment(pushService)
}

#Preview("Sessions — dark") {
    let appModel = AppModel(repository: MockTmuxAgentRepository())
    let preferences = UserPreferences()
    let pushService = PushRegistrationService(
        repositoryProvider: { appModel.repository },
        preferences: preferences,
        pushSystem: MockPushSystem(initialStatus: .denied)
    )
    return NavigationStack {
        SessionsListView()
    }
    .environment(appModel)
    .environment(RootCoordinator())
    .environment(pushService)
    .preferredColorScheme(.dark)
}
