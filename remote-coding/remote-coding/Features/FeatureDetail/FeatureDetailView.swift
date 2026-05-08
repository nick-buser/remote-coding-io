import SwiftUI

/// The Feature detail body — hero (Pip + FEAT-### + StatusPill +
/// title + vision), single-line progress strip, segmented control
/// for Tickets / PRD / Decisions / Sessions, and a footer action row
/// shown only on the Tickets sub-tab.
///
/// The four sub-tab bodies stay stubbed in this ticket; their content
/// lands in `service-feature-tickets-tab` and friends. The shell is
/// the contract this ticket fulfills.
struct FeatureDetailView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(RootCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @State private var viewModel: FeatureDetailViewModel
    @State private var section: String = FeatureDetailSection.tickets.rawValue
    @State private var showCreateTicketSheet = false

    init(project: Components.Schemas.Project, feature: Components.Schemas.Feature) {
        _viewModel = State(initialValue: FeatureDetailViewModel(project: project, feature: feature))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.s4) {
                topBar
                hero
                progressStrip
                SegmentedControl(items: FeatureDetailSection.allLabels, selection: $section)
                    .padding(.horizontal, Theme.Spacing.s4)
                sectionBody
                if FeatureDetailSection.from(label: section) == .tickets {
                    footerActions
                }
            }
            .padding(.bottom, Theme.Spacing.s5)
        }
        .background(Theme.Surface.bg(scheme))
        .toolbar(.hidden, for: .navigationBar)
        .environment(\.accent, viewModel.accentColor)
        .task {
            await viewModel.load(repository: appModel.repository)
        }
        .refreshable {
            await viewModel.load(repository: appModel.repository)
        }
        .sheet(isPresented: $showCreateTicketSheet) {
            CreateTicketSheet(featureID: viewModel.feature.id, accent: viewModel.accentColor) { created in
                viewModel.tickets.insert(created, at: 0)
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        QuietHeader(label: viewModel.publicLabel) {
            BackChevron(label: viewModel.project.name, accent: viewModel.accentColor) { dismiss() }
        } trailing: {
            HStack(spacing: 8) {
                NavIconButton(name: .share) { /* share placeholder */ }
                Menu {
                    Button("Mark in progress") { setStatus(.inProgress) }
                    Button("Mark in review")   { setStatus(.review) }
                    Button("Mark planned")     { setStatus(.planned) }
                    Button("Mark shipped")     { setStatus(.shipped) }
                    Button("Edit feature") { /* opens edit sheet — service-feature-create */ }
                        .disabled(true)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Theme.Text.fg(scheme))
                        .frame(width: 28, height: 28)
                }
                .accessibilityLabel("Feature actions")
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Pip(accent: viewModel.accentColor, size: 10, radius: 3)
                Text(viewModel.publicLabel)
                    .themeMonoSm()
                    .foregroundStyle(Theme.Text.fg2(scheme))
                StatusPill(role: viewModel.statusRole, label: viewModel.statusLabel)
            }
            Text(viewModel.feature.title)
                .themeDisplayMedium()
                .foregroundStyle(Theme.Text.fg(scheme))
            if let vision = viewModel.feature.vision, !vision.isEmpty {
                Text(vision)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Theme.Text.fg2(scheme))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, Theme.Spacing.s4)
    }

    // MARK: - Progress strip

    private var progressStrip: some View {
        let progress = viewModel.progress
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(progress.done) of \(progress.total) tickets")
                    .themeMonoSm()
                    .foregroundStyle(Theme.Text.fg2(scheme))
                Spacer()
                if let target = viewModel.feature.targetDate, !target.isEmpty {
                    Text(target)
                        .themeMonoSm()
                        .foregroundStyle(Theme.Text.fg2(scheme))
                }
            }
            ProgressBar(value: progress.fraction, accent: viewModel.accentColor, height: 2)
        }
        .padding(.horizontal, Theme.Spacing.s4)
    }

    // MARK: - Sub-tab bodies (stubs in this ticket)

    @ViewBuilder
    private var sectionBody: some View {
        if viewModel.isLoading && viewModel.tickets.isEmpty && viewModel.docs.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, Theme.Spacing.s4)
        } else if let errorMessage = viewModel.errorMessage,
                  viewModel.tickets.isEmpty,
                  viewModel.docs.isEmpty {
            EmptyState(
                systemImage: "wifi.exclamationmark",
                title: "Couldn't load",
                message: errorMessage
            )
            .padding(.top, Theme.Spacing.s4)
        } else {
            switch FeatureDetailSection.from(label: section) {
            case .tickets:   ticketsBody
            case .prd:       prdBody
            case .decisions: decisionsSummary
            case .sessions:  sessionsSummary
            }
        }
    }

    private var ticketsBody: some View {
        FeatureTicketsTab(
            viewModel: viewModel,
            showCreateSheet: $showCreateTicketSheet,
            repository: appModel.repository,
            onSelect: { ticket in
                coordinator.push(.ticketDetail(publicID: ticket.publicId))
            }
        )
    }

    private var prdBody: some View {
        FeaturePRDTab(
            viewModel: viewModel,
            accent: viewModel.accentColor,
            onSelect: { doc in
                coordinator.push(.docDetail(docID: doc.id))
            }
        )
    }

    private var decisionsSummary: some View {
        EmptyState(
            systemImage: "scribble.variable",
            title: "Decisions — \(viewModel.decisions.count)",
            message: "Append-only log lands in service-feature-decisions-tab."
        )
        .padding(.horizontal, Theme.Spacing.s4)
    }

    private var sessionsSummary: some View {
        EmptyState(
            systemImage: "terminal",
            title: "Sessions — \(viewModel.agentSessions.count)",
            message: "Session list + Spawn flow lands in service-feature-sessions-tab."
        )
        .padding(.horizontal, Theme.Spacing.s4)
    }

    // MARK: - Footer

    private var footerActions: some View {
        HStack(spacing: 8) {
            PillButton(title: "+ New ticket", role: .primary, accent: viewModel.accentColor, wide: true) {
                showCreateTicketSheet = true
            }
            PillButton(title: "Spawn session", role: .secondary, accent: viewModel.accentColor, wide: true) {
                // Sheet lands in service-feature-sessions-tab.
            }
        }
        .padding(.horizontal, Theme.Spacing.s4)
        .padding(.top, Theme.Spacing.s2)
    }

    // MARK: - Helpers

    private func setStatus(_ status: Components.Schemas.FeatureStatus) {
        Task {
            await viewModel.setStatus(status, repository: appModel.repository)
        }
    }
}

/// Typed sub-tab enum for the Feature detail segmented control.
enum FeatureDetailSection: String, CaseIterable {
    case tickets   = "Tickets"
    case prd       = "PRD"
    case decisions = "Decisions"
    case sessions  = "Sessions"

    static let allLabels: [String] = FeatureDetailSection.allCases.map(\.rawValue)

    static func from(label: String) -> FeatureDetailSection {
        FeatureDetailSection(rawValue: label) ?? .tickets
    }
}

#Preview("FeatureDetail — light") {
    NavigationStack {
        FeatureDetailDestinationStub(featureID: 11)
    }
    .environment(AppModel(repository: MockTmuxAgentRepository()))
    .environment(RootCoordinator())
}

#Preview("FeatureDetail — dark") {
    NavigationStack {
        FeatureDetailDestinationStub(featureID: 21)
    }
    .environment(AppModel(repository: MockTmuxAgentRepository()))
    .environment(RootCoordinator())
    .preferredColorScheme(.dark)
}

private struct FeatureDetailDestinationStub: View {
    let featureID: Int64
    @Environment(AppModel.self) private var appModel
    @State private var resolved: Resolved?

    private struct Resolved {
        var project: Components.Schemas.Project
        var feature: Components.Schemas.Feature
    }

    var body: some View {
        Group {
            if let resolved {
                FeatureDetailView(project: resolved.project, feature: resolved.feature)
            } else {
                ProgressView()
            }
        }
        .task(id: featureID) {
            do {
                let feature = try await appModel.repository.getFeature(id: featureID)
                let project = try await appModel.repository.getProject(idOrSlug: String(feature.projectId))
                resolved = Resolved(project: project, feature: feature)
            } catch {
                resolved = nil
            }
        }
    }
}
