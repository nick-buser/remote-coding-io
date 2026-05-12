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
    @State private var showSearchSheet = false
    @State private var editingProject: Components.Schemas.Project?
    @State private var deletePendingProject: Components.Schemas.Project?

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
            appModel.searchViewModel.invalidate()
            await viewModel.load(repository: appModel.repository)
        }
        .sheet(isPresented: $showSearchSheet) {
            SearchView(viewModel: appModel.searchViewModel)
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateProjectSheet { project in
                viewModel.projects.insert(project, at: 0)
                viewModel.projects = ProjectListViewModel.sorted(viewModel.projects)
                coordinator.push(.projectDetail(idOrSlug: project.slug), in: .projects)
            }
        }
        .sheet(item: $editingProject) { project in
            CreateProjectSheet(existing: project) { updated in
                if let index = viewModel.projects.firstIndex(where: { $0.id == updated.id }) {
                    viewModel.projects[index] = updated
                    viewModel.projects = ProjectListViewModel.sorted(viewModel.projects)
                }
            }
        }
        .confirmationDialog(
            "Delete project?",
            isPresented: Binding(
                get: { deletePendingProject != nil },
                set: { if !$0 { deletePendingProject = nil } }
            ),
            titleVisibility: .visible,
            presenting: deletePendingProject
        ) { project in
            Button("Delete \(project.name)", role: .destructive) {
                Task { await delete(project) }
            }
            Button("Cancel", role: .cancel) { deletePendingProject = nil }
        } message: { _ in
            Text("Removes the project and all its features, tickets, docs, decisions, and sessions.")
        }
    }

    @MainActor
    private func delete(_ project: Components.Schemas.Project) async {
        // Optimistic remove with rollback on failure.
        let previous = viewModel.projects
        viewModel.projects.removeAll { $0.id == project.id }
        do {
            try await appModel.repository.deleteProject(idOrSlug: project.slug)
        } catch {
            viewModel.projects = previous
            viewModel.errorMessage = "Couldn't delete \(project.name): \(error.localizedDescription)"
        }
        deletePendingProject = nil
    }

    // MARK: - Header

    private var header: some View {
        LargeTitleHeader(title: "Projects", subtitle: viewModel.subtitle()) {
            HStack(spacing: 8) {
                NavIconButton(name: .search) {
                    showSearchSheet = true
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
            Button {
                editingProject = project
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive) {
                deletePendingProject = project
            } label: {
                Label("Delete", systemImage: "trash")
            }
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
