import SwiftUI

/// The Project detail body — hero, 4-up stats strip, and a segmented
/// control selecting between Features / Tickets / Docs / Sessions.
///
/// Mounted from `ContentView.ProjectDetailDestination`, which resolves
/// the project by id-or-slug and hands the resolved value to this
/// view's init.
struct ProjectDetailView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(RootCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @State private var viewModel: ProjectDetailViewModel
    @State private var section: String = ProjectDetailSection.features.rawValue

    init(project: Components.Schemas.Project) {
        _viewModel = State(initialValue: ProjectDetailViewModel(project: project))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.s4) {
                topBar
                hero
                statsStrip
                SegmentedControl(items: ProjectDetailSection.allLabels, selection: $section)
                    .padding(.horizontal, Theme.Spacing.s4)
                sectionBody
            }
            .padding(.bottom, Theme.Spacing.s5)
        }
        .background(Theme.Surface.bg(scheme))
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.load(repository: appModel.repository)
        }
        .refreshable {
            await viewModel.load(repository: appModel.repository)
        }
    }

    // MARK: - Top bar / hero / stats

    private var topBar: some View {
        QuietHeader(label: viewModel.project.name) {
            BackChevron(label: "Projects", accent: nil) { dismiss() }
        } trailing: {
            HStack(spacing: 8) {
                NavIconButton(name: .search) { /* search placeholder */ }
                NavIconButton(name: .dots) { /* dots menu placeholder */ }
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.project.name)
                .themeDisplayLarge()
                .foregroundStyle(Theme.Text.fg(scheme))
            Text(viewModel.subtitle())
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Theme.Text.fg2(scheme))
                .lineLimit(2)
        }
        .padding(.horizontal, Theme.Spacing.s4)
    }

    private var statsStrip: some View {
        let stats = viewModel.stats
        return RoundedCard {
            HStack(alignment: .top, spacing: Theme.Spacing.s3) {
                statCell(label: "Active", value: stats.active)
                Divider().frame(height: 32).background(Theme.Surface.sep(scheme))
                statCell(label: "Open", value: stats.open)
                Divider().frame(height: 32).background(Theme.Surface.sep(scheme))
                statCell(label: "Live", value: stats.live, accent: stats.live > 0 ? Theme.Semantic.green : nil)
                Divider().frame(height: 32).background(Theme.Surface.sep(scheme))
                statCell(label: "Total", value: stats.total)
            }
        }
        .padding(.horizontal, Theme.Spacing.s4)
    }

    private func statCell(label: String, value: Int, accent: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(value)")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(accent ?? Theme.Text.fg(scheme))
            Text(label.uppercased())
                .themeMonoSm()
                .foregroundStyle(Theme.Text.fg2(scheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Section bodies

    @ViewBuilder
    private var sectionBody: some View {
        if viewModel.isLoading && viewModel.features.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, Theme.Spacing.s4)
        } else if let errorMessage = viewModel.errorMessage, viewModel.features.isEmpty {
            EmptyState(
                systemImage: "wifi.exclamationmark",
                title: "Couldn't load",
                message: errorMessage
            )
            .padding(.top, Theme.Spacing.s4)
        } else {
            switch ProjectDetailSection.from(label: section) {
            case .features: featuresBody
            case .tickets:  ticketsBody
            case .docs:     docsBody
            case .sessions: sessionsBody
            }
        }
    }

    private var featuresBody: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s4) {
            ForEach(ProjectDetailViewModel.featureSections, id: \.label) { spec in
                let features = viewModel.features(for: spec.statuses)
                if !features.isEmpty {
                    section(title: spec.label) {
                        ForEach(Array(features.enumerated()), id: \.element.id) { index, feature in
                            if index > 0 {
                                Divider().background(Theme.Surface.sep(scheme))
                            }
                            FeatureRow(
                                feature: feature,
                                liveSessionsCount: viewModel.liveSessionsByFeatureID[feature.id] ?? 0,
                                ticketsDone: ticketsDone(for: feature.id),
                                ticketsTotal: ticketsTotal(for: feature.id),
                                onTap: {
                                    coordinator.push(.featureDetail(featureID: feature.id), in: .projects)
                                }
                            )
                        }
                    }
                }
            }
            if viewModel.features.isEmpty {
                EmptyState(
                    systemImage: "rectangle.stack",
                    title: "No features yet",
                    message: "Add a feature from the project hub to start scoping work."
                )
            }
        }
    }

    private var ticketsBody: some View {
        let tickets = viewModel.allTickets
        return Group {
            if tickets.isEmpty {
                EmptyState(
                    systemImage: "tray",
                    title: "No tickets",
                    message: "Tickets created across this project's features will appear here."
                )
            } else {
                section(title: "All tickets") {
                    ForEach(Array(tickets.enumerated()), id: \.element.id) { index, ticket in
                        if index > 0 { Divider().background(Theme.Surface.sep(scheme)) }
                        TicketRow(
                            ticket: ticket,
                            featureLabel: featurePublicID(for: ticket.featureId),
                            onTap: { coordinator.push(.ticketDetail(publicID: ticket.publicId), in: .projects) }
                        )
                    }
                }
            }
        }
    }

    private var docsBody: some View {
        let docs = viewModel.allDocs
        return Group {
            if docs.isEmpty {
                EmptyState(
                    systemImage: "doc.text",
                    title: "No docs yet",
                    message: "PRDs and design notes for this project's features will collect here."
                )
            } else {
                section(title: "All docs") {
                    ForEach(Array(docs.enumerated()), id: \.element.doc.id) { index, item in
                        if index > 0 { Divider().background(Theme.Surface.sep(scheme)) }
                        DocRow(
                            doc: item.doc,
                            featureLabel: item.feature.title,
                            onTap: { coordinator.push(.docDetail(docID: item.doc.id), in: .projects) }
                        )
                    }
                }
            }
        }
    }

    private var sessionsBody: some View {
        let sessions = viewModel.agentSessions
        return Group {
            if sessions.isEmpty {
                EmptyState(
                    systemImage: "terminal",
                    title: "No agent sessions",
                    message: "Spawn a session from a ticket to see it here."
                )
            } else {
                section(title: "Sessions") {
                    ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                        if index > 0 { Divider().background(Theme.Surface.sep(scheme)) }
                        SessionRow(
                            session: session,
                            ticketLabel: ticketLabel(for: session),
                            onTap: { coordinator.push(.agentSession(sessionID: session.id), in: .projects) }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func section<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s2) {
            Text(title.uppercased())
                .themeMonoSm()
                .foregroundStyle(Theme.Text.fg2(scheme))
                .padding(.horizontal, Theme.Spacing.s4)
            RoundedCard {
                VStack(spacing: 8) {
                    content()
                }
            }
            .padding(.horizontal, Theme.Spacing.s4)
        }
    }

    private func featurePublicID(for featureID: Int64) -> String {
        "FEAT-\(String(format: "%03d", featureID))"
    }

    private func ticketsDone(for featureID: Int64) -> Int {
        viewModel.ticketsByFeatureID[featureID]?.filter { $0.status == .done }.count ?? 0
    }

    private func ticketsTotal(for featureID: Int64) -> Int {
        viewModel.ticketsByFeatureID[featureID]?.count ?? 0
    }

    private func ticketLabel(for session: Components.Schemas.AgentSession) -> String? {
        guard let ticketID = session.ticketId else { return nil }
        for tickets in viewModel.ticketsByFeatureID.values {
            if let match = tickets.first(where: { $0.id == ticketID }) {
                return match.publicId
            }
        }
        return nil
    }
}

/// The 4 segmented-control sections. Stored as a typed enum so the
/// switch in `sectionBody` is exhaustive.
enum ProjectDetailSection: String, CaseIterable {
    case features = "Features"
    case tickets = "Tickets"
    case docs = "Docs"
    case sessions = "Sessions"

    static let allLabels: [String] = ProjectDetailSection.allCases.map(\.rawValue)

    static func from(label: String) -> ProjectDetailSection {
        ProjectDetailSection(rawValue: label) ?? .features
    }
}

#Preview("Project detail — light") {
    NavigationStack {
        ProjectDetailDestinationStub()
    }
    .environment(AppModel(repository: MockTmuxAgentRepository()))
    .environment(RootCoordinator())
}

#Preview("Project detail — dark") {
    NavigationStack {
        ProjectDetailDestinationStub()
    }
    .environment(AppModel(repository: MockTmuxAgentRepository()))
    .environment(RootCoordinator())
    .preferredColorScheme(.dark)
}

/// Local resolver that mirrors `ContentView.ProjectDetailDestination`
/// so previews can mount the screen without depending on the
/// coordinator path.
private struct ProjectDetailDestinationStub: View {
    @Environment(AppModel.self) private var appModel
    @State private var project: Components.Schemas.Project?

    var body: some View {
        Group {
            if let project {
                ProjectDetailView(project: project)
            } else {
                ProgressView()
            }
        }
        .task {
            project = try? await appModel.repository.getProject(idOrSlug: "tmux-server-coding-app")
        }
    }
}
