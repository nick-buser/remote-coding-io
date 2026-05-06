import SwiftUI

struct ProjectListView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(RootCoordinator.self) private var coordinator
    @State private var viewModel = ProjectListViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.projects.isEmpty {
                ProgressView()
            } else if let errorMessage = viewModel.errorMessage {
                ContentUnavailableView("Projects unavailable", systemImage: "wifi.exclamationmark", description: Text(errorMessage))
            } else {
                List(viewModel.projects) { project in
                    Button {
                        coordinator.push(.projectDetail(idOrSlug: project.slug), in: .projects)
                    } label: {
                        ProjectRow(project: project)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.insetGrouped)
            }
        }
        .task {
            await viewModel.load(repository: appModel.repository)
        }
        .refreshable {
            await viewModel.load(repository: appModel.repository)
        }
    }
}

private struct ProjectRow: View {
    let project: Components.Schemas.Project

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: project.icon ?? "folder")
                .frame(width: 30, height: 30)
                .foregroundStyle(.white)
                .background(accentColor, in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(project.name)
                        .font(.headline)
                    if project.pinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if let tagline = project.tagline {
                    Text(tagline)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Text(project.localRepoPath)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            Chevron()
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private var accentColor: Color {
        switch project.accent {
        case "teal": .teal
        case "indigo": .indigo
        case "green": .green
        default: .blue
        }
    }
}

#Preview {
    NavigationStack {
        ProjectListView()
            .navigationTitle("Projects")
    }
    .environment(AppModel(repository: MockTmuxAgentRepository()))
    .environment(RootCoordinator())
}
