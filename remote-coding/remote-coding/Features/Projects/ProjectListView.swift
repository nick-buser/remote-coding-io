import SwiftUI

struct ProjectListView: View {
    @Environment(AppModel.self) private var appModel
    @State private var viewModel = ProjectListViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.projects.isEmpty {
                    ProgressView()
                } else if let errorMessage = viewModel.errorMessage {
                    ContentUnavailableView("Projects unavailable", systemImage: "wifi.exclamationmark", description: Text(errorMessage))
                } else {
                    List(viewModel.projects) { project in
                        NavigationLink(value: project) {
                            ProjectRow(project: project)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Projects")
            .navigationDestination(for: OpenAPI.Project.self) { project in
                ProjectDetailView(project: project)
            }
            .task {
                await viewModel.load(repository: appModel.repository)
            }
            .refreshable {
                await viewModel.load(repository: appModel.repository)
            }
        }
    }
}

private struct ProjectRow: View {
    let project: OpenAPI.Project

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
        }
        .padding(.vertical, 6)
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
    ProjectListView()
        .environment(AppModel(repository: MockTmuxAgentRepository()))
}

