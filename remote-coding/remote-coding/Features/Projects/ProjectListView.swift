import SwiftUI

/// Projects tab body — Pinned + All projects sections.
///
/// Reads the workspace repository from `AppModel`, lazy-loads per-row
/// live session counts via `task(id:)`, and pushes
/// `.projectDetail(idOrSlug:)` on tap. Long-press exposes
/// Pin / Unpin (wired) and Edit / Open in tmux / Delete (stubbed —
/// land in `service-projects-edit` and `service-projects-create`).
struct ProjectListView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(RootCoordinator.self) private var coordinator
    @Environment(\.colorScheme) private var scheme
    @State private var viewModel = ProjectListViewModel()
    @State private var showCreateSheet = false

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
            await viewModel.load(repository: appModel.repository)
        }
        .refreshable {
            await viewModel.load(repository: appModel.repository)
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateProjectSheet { project in
                viewModel.projects.insert(project, at: 0)
                viewModel.projects = ProjectListViewModel.sorted(viewModel.projects)
                coordinator.push(.projectDetail(idOrSlug: project.slug), in: .projects)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        LargeTitleHeader(title: "Projects", subtitle: viewModel.subtitle()) {
            HStack(spacing: 8) {
                NavIconButton(name: .search) {
                    // Search sheet ships in a follow-up.
                }
                NavIconButton(name: .plus, accent: appModel.accent, tinted: true) {
                    showCreateSheet = true
                }
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.projects.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, Theme.Spacing.s5)
        } else if let errorMessage = viewModel.errorMessage, viewModel.projects.isEmpty {
            VStack(spacing: Theme.Spacing.s4) {
                EmptyState(
                    systemImage: "wifi.exclamationmark",
                    title: "Couldn't load projects",
                    message: errorMessage
                )
                Button("Retry") {
                    Task { await viewModel.load(repository: appModel.repository) }
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, Theme.Spacing.s4)
        } else if viewModel.projects.isEmpty {
            EmptyState(
                systemImage: "square.grid.2x2",
                title: "No projects",
                message: "Tap + to add your first project."
            )
            .padding(.top, Theme.Spacing.s5)
        } else {
            let pinned = viewModel.pinnedProjects
            let unpinned = viewModel.unpinnedProjects
            if !pinned.isEmpty {
                section(title: "Pinned", projects: pinned)
            }
            if !unpinned.isEmpty {
                section(title: pinned.isEmpty ? "All projects" : "All projects", projects: unpinned)
            }
        }
    }

    private func section(title: String, projects: [Components.Schemas.Project]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s2) {
            Text(title.uppercased())
                .themeMonoSm()
                .foregroundStyle(Theme.Text.fg2(scheme))
                .padding(.horizontal, Theme.Spacing.s4)
            RoundedCard {
                VStack(spacing: 8) {
                    ForEach(Array(projects.enumerated()), id: \.element.id) { index, project in
                        if index > 0 {
                            Divider()
                                .background(Theme.Surface.sep(scheme))
                        }
                        rowView(for: project)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.s4)
        }
    }

    private func rowView(for project: Components.Schemas.Project) -> some View {
        ProjectRow(
            project: project,
            liveCount: viewModel.liveSessionCounts[project.id],
            featureCount: viewModel.featureCounts[project.id],
            onTap: {
                coordinator.push(.projectDetail(idOrSlug: project.slug), in: .projects)
            }
        )
        .contextMenu {
            Button {
                Task { await viewModel.togglePin(for: project, repository: appModel.repository) }
            } label: {
                Label(project.pinned ? "Unpin" : "Pin",
                      systemImage: project.pinned ? "pin.slash" : "pin")
            }
            Button { /* edit sheet — service-projects-edit */ } label: {
                Label("Edit", systemImage: "pencil")
            }
            .disabled(true)
            Button { /* open-in-tmux — wired by terminal phase */ } label: {
                Label("Open in tmux", systemImage: "terminal")
            }
            .disabled(true)
            Button(role: .destructive) {
                /* delete — service-projects-edit */
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .disabled(true)
        }
        .task(id: project.id) {
            await viewModel.loadLiveSessionCount(for: project, repository: appModel.repository)
        }
    }
}

#Preview("Projects — light") {
    NavigationStack {
        ProjectListView()
    }
    .environment(AppModel(repository: MockTmuxAgentRepository()))
    .environment(RootCoordinator())
}

#Preview("Projects — dark") {
    NavigationStack {
        ProjectListView()
    }
    .environment(AppModel(repository: MockTmuxAgentRepository()))
    .environment(RootCoordinator())
    .preferredColorScheme(.dark)
}
