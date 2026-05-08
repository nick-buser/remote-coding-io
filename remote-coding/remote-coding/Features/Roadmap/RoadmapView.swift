import SwiftUI

/// The Roadmap tab body — milestone-focused page-swipe layout.
///
/// One milestone per `TabView` page; the project chip row at the top
/// narrows which features show inside each page. Swiping or tapping
/// a page dot moves between milestones.
struct RoadmapView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(RootCoordinator.self) private var coordinator
    @Environment(\.colorScheme) private var scheme

    @State private var viewModel = RoadmapViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s4) {
            header
            chips
            content
        }
        .background(Theme.Surface.bg(scheme))
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.load(fetcher: CrossProjectFeatureFetcher(repository: appModel.repository))
        }
        .refreshable {
            await viewModel.load(fetcher: CrossProjectFeatureFetcher(repository: appModel.repository))
        }
    }

    // MARK: - Header / chips

    private var header: some View {
        LargeTitleHeader(title: "Roadmap", subtitle: viewModel.subtitle()) {
            HStack(spacing: 8) {
                NavIconButton(name: .calendar) { /* date-range scope — follow-up */ }
                NavIconButton(name: .filter) { /* extra filters — follow-up */ }
            }
        }
    }

    private var chips: some View {
        let projects = viewModel.bundle?.projects ?? []
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    viewModel.selectedProjectID = nil
                } label: {
                    Chip(
                        label: "All",
                        count: nil,
                        active: viewModel.selectedProjectID == nil
                    )
                }
                .buttonStyle(.plain)
                ForEach(projects, id: \.id) { project in
                    Button {
                        viewModel.selectedProjectID = project.id
                    } label: {
                        Chip(
                            label: project.name,
                            dot: ProjectAccentMapper.color(for: project.accent ?? "").value(for: scheme),
                            active: viewModel.selectedProjectID == project.id
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.s4)
        }
    }

    // MARK: - Body

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.milestones.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage = viewModel.errorMessage, viewModel.milestones.isEmpty {
            EmptyState(
                systemImage: "wifi.exclamationmark",
                title: "Couldn't load roadmap",
                message: errorMessage
            )
        } else if viewModel.milestones.isEmpty {
            EmptyState(
                systemImage: "calendar",
                title: "No milestones yet",
                message: "Add a milestone to a feature to start grouping work."
            )
        } else {
            milestonePager
        }
    }

    private var milestonePager: some View {
        TabView(selection: $viewModel.milestoneIndex) {
            ForEach(Array(viewModel.milestones.enumerated()), id: \.element.id) { index, milestone in
                MilestonePage(
                    milestone: milestone,
                    filteredProject: viewModel.filteredProject
                ) { feature in
                    coordinator.push(.featureDetail(featureID: feature.id), in: .roadmap)
                }
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .never))
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Milestone page

private struct MilestonePage: View {
    let milestone: RoadmapViewModel.Milestone
    let filteredProject: Components.Schemas.Project?
    var onFeatureTap: (Components.Schemas.Feature) -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.s4) {
                eyebrowAndHero
                if milestone.features.isEmpty {
                    EmptyState(
                        systemImage: "rectangle.stack",
                        title: filteredProject.map { "No features for \($0.name)" } ?? "No features",
                        message: "Try All to see features across projects."
                    )
                } else {
                    featuresCard
                }
                hint
            }
            .padding(.horizontal, Theme.Spacing.s4)
            .padding(.bottom, Theme.Spacing.s5)
        }
    }

    private var eyebrowAndHero: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(eyebrowText)
                .themeMonoSm()
                .foregroundStyle(eyebrowColor)
            Text(milestone.label)
                .themeDisplayMedium()
                .foregroundStyle(Theme.Text.fg(scheme))
            if !milestone.idPrefix.isEmpty {
                Text(milestone.idPrefix)
                    .themeMonoSm()
                    .foregroundStyle(Theme.Text.fg2(scheme))
            }
        }
        .padding(.top, Theme.Spacing.s2)
    }

    private var featuresCard: some View {
        RoundedCard {
            VStack(spacing: 8) {
                ForEach(Array(milestone.features.enumerated()), id: \.element.id) { index, feature in
                    if index > 0 {
                        Divider().background(Theme.Surface.sep(scheme))
                    }
                    Button { onFeatureTap(feature) } label: {
                        FeatureMilestoneRow(feature: feature)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var hint: some View {
        Text("Swipe for next milestone")
            .font(.system(size: 12, weight: .regular))
            .foregroundStyle(Theme.Text.fg2(scheme))
            .frame(maxWidth: .infinity)
            .padding(.top, Theme.Spacing.s4)
    }

    private var eyebrowText: String {
        switch milestone.state {
        case .active:  return "NOW · \(milestone.earliestTarget.map { "ENDS \($0)" } ?? "ACTIVE")"
        case .planned: return "PLANNED · \(milestone.earliestTarget.map { "STARTS \($0)" } ?? "UPCOMING")"
        case .shipped: return "SHIPPED \(milestone.earliestTarget ?? "")"
        }
    }

    private var eyebrowColor: Color {
        switch milestone.state {
        case .active:  return Theme.Semantic.orange
        case .planned: return Theme.Text.fg2(scheme)
        case .shipped: return Theme.Semantic.green
        }
    }
}

// MARK: - Per-feature row inside a milestone page

private struct FeatureMilestoneRow: View {
    let feature: Components.Schemas.Feature

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Circle()
                .fill(stateColor)
                .frame(width: 8, height: 8)
            Text(feature.title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.Text.fg(scheme))
                .lineLimit(1)
            Spacer(minLength: 8)
            if let target = feature.targetDate, !target.isEmpty {
                Text(target)
                    .themeMonoSm()
                    .foregroundStyle(Theme.Text.fg2(scheme))
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private var stateColor: Color {
        switch feature.status {
        case .inProgress, .review:
            return ProjectAccentMapper.color(for: feature.accent).value(for: scheme)
        case .shipped, .merged:
            return Theme.Semantic.green
        case .planned, .abandoned:
            return Theme.Text.fg3(scheme)
        }
    }
}

#Preview("Roadmap — light") {
    NavigationStack {
        RoadmapView()
    }
    .environment(AppModel(repository: MockTmuxAgentRepository()))
    .environment(RootCoordinator())
}

#Preview("Roadmap — dark") {
    NavigationStack {
        RoadmapView()
    }
    .environment(AppModel(repository: MockTmuxAgentRepository()))
    .environment(RootCoordinator())
    .preferredColorScheme(.dark)
}
