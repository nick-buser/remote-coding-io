//
//  ContentView.swift
//  remote-coding
//
//  Created by Nick Buser on 4/30/26.
//

import SwiftUI

/// The v2 5-tab shell — Inbox, Projects, Roadmap, Sessions, You.
///
/// Each tab body is wrapped in a `NavigationStack` bound to the
/// `RootCoordinator`'s path for that tab. A single
/// `.navigationDestination(for: AppRoute.self)` per stack maps every
/// typed route to its destination view. The terminal is intentionally
/// absent from this top-level set: it is reached as the
/// `.agentSession` drill-down from Sessions, the Inbox `Open pane`
/// action, or a feature's Sessions sub-tab — `service-terminal-shell`
/// replaces the prototype that backs that destination today.
struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(RootCoordinator.self) private var coordinator
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        TabView(selection: selectedTabBinding) {
            Tab(value: AppTab.inbox) {
                NavigationStack(path: coordinator.binding(for: .inbox)) {
                    TabPlaceholder(
                        systemImage: "tray",
                        title: "Inbox",
                        message: "Activity that needs you lands here. Coming in service-inbox-screen."
                    )
                    .navigationDestination(for: AppRoute.self, destination: destinationView)
                }
            } label: {
                Label("Inbox", systemImage: "tray")
            }
            .badge(appModel.needsYou ? Text("●") : nil)

            Tab(value: AppTab.projects) {
                NavigationStack(path: coordinator.binding(for: .projects)) {
                    ProjectListView()
                        .navigationTitle("Projects")
                        .navigationDestination(for: AppRoute.self, destination: destinationView)
                }
            } label: {
                Label("Projects", systemImage: "square.grid.2x2")
            }

            Tab(value: AppTab.roadmap) {
                NavigationStack(path: coordinator.binding(for: .roadmap)) {
                    TabPlaceholder(
                        systemImage: "chart.bar.xaxis",
                        title: "Roadmap",
                        message: "Milestone timeline. Coming in service-roadmap-screen."
                    )
                    .navigationDestination(for: AppRoute.self, destination: destinationView)
                }
            } label: {
                Label("Roadmap", systemImage: "chart.bar.xaxis")
            }

            Tab(value: AppTab.sessions) {
                NavigationStack(path: coordinator.binding(for: .sessions)) {
                    TabPlaceholder(
                        systemImage: "terminal",
                        title: "Sessions",
                        message: "Agent sessions, grouped by state. Coming in service-sessions-list."
                    )
                    .navigationDestination(for: AppRoute.self, destination: destinationView)
                }
            } label: {
                Label("Sessions", systemImage: "terminal")
            }

            Tab(value: AppTab.you) {
                NavigationStack(path: coordinator.binding(for: .you)) {
                    YouTabPlaceholder()
                        .navigationDestination(for: AppRoute.self, destination: destinationView)
                }
            } label: {
                Label("You", systemImage: "person.crop.circle")
            }
        }
        .tint(appModel.accent.value(for: scheme))
        .toolbarBackground(Theme.Surface.tabBg(scheme), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }

    private var selectedTabBinding: Binding<AppTab> {
        Binding(
            get: { coordinator.selectedTab },
            set: { coordinator.switchTab($0) }
        )
    }

    @ViewBuilder
    private func destinationView(for route: AppRoute) -> some View {
        switch route {
        case .projectDetail(let idOrSlug):
            ProjectDetailDestination(idOrSlug: idOrSlug)
        case .featureDetail(let featureID):
            FeatureDetailDestination(featureID: featureID)
        case .ticketDetail(let publicID):
            RoutePlaceholder(label: "Ticket", value: publicID, owner: "service-review-screen")
        case .docDetail(let docID):
            RoutePlaceholder(label: "Doc", value: String(docID), owner: "service-feature-prd-tab")
        case .sessionsForFeature(let featureID):
            RoutePlaceholder(label: "Feature sessions", value: String(featureID), owner: "service-feature-sessions-tab")
        case .agentSession:
            // Legacy prototype until service-terminal-shell replaces it. The
            // route carries an `AgentSession.id`; the prototype reads its
            // own fixture via TerminalView's optional `context:` initializer.
            TerminalView()
        }
    }
}

/// Resolves a project by id-or-slug then hands it to the existing
/// `ProjectDetailView`. The view's init takes a full `Project` value;
/// the coordinator route only carries an identifier, so this wrapper
/// owns the async fetch + loading / error chrome until the view itself
/// is rewritten to take an identifier.
private struct ProjectDetailDestination: View {
    let idOrSlug: String

    @Environment(AppModel.self) private var appModel
    @State private var project: Components.Schemas.Project?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let project {
                ProjectDetailView(project: project)
            } else if let errorMessage {
                ContentUnavailableView(
                    "Project unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else {
                ProgressView()
            }
        }
        .task(id: idOrSlug) {
            do {
                project = try await appModel.repository.getProject(idOrSlug: idOrSlug)
            } catch {
                errorMessage = String(describing: error)
            }
        }
    }
}

/// Resolves a feature (and its parent project) by feature id then
/// hands both to `FeatureDetailView`, mirroring
/// `ProjectDetailDestination`.
private struct FeatureDetailDestination: View {
    let featureID: Int64

    @Environment(AppModel.self) private var appModel
    @State private var resolved: Resolved?
    @State private var errorMessage: String?

    private struct Resolved {
        var project: Components.Schemas.Project
        var feature: Components.Schemas.Feature
    }

    var body: some View {
        Group {
            if let resolved {
                FeatureDetailView(project: resolved.project, feature: resolved.feature)
            } else if let errorMessage {
                ContentUnavailableView(
                    "Feature unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
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
                errorMessage = String(describing: error)
            }
        }
    }
}

/// Stub destination for routes that don't have a real screen yet.
/// Each Phase 3 ticket replaces one of these.
private struct RoutePlaceholder: View {
    let label: String
    let value: String
    let owner: String

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        EmptyState(
            systemImage: "rectangle.dashed",
            title: "\(label): \(value)",
            message: "Destination wired by \(owner)."
        )
        .frame(maxHeight: .infinity)
        .background(Theme.Surface.bg(scheme))
        .navigationTitle(label)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Centred `EmptyState` placeholder. Phase 3 screen tickets replace
/// the bodies one at a time; the surrounding `NavigationStack` lives
/// in `ContentView` and is bound to the coordinator path.
private struct TabPlaceholder: View {
    var systemImage: String
    var title: String
    var message: String

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        EmptyState(systemImage: systemImage, title: title, message: message)
            .frame(maxHeight: .infinity)
            .background(Theme.Surface.bg(scheme))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
    }
}

/// You tab placeholder — keeps the existing API base URL form
/// reachable until `service-you-screen` replaces this body. The
/// `NavigationStack` lives in `ContentView`; the `NavigationLink`
/// here pushes a `Components.Schemas`-free destination so the
/// coordinator path machinery stays focused on `AppRoute`.
private struct YouTabPlaceholder: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: Theme.Spacing.s4) {
            EmptyState(
                systemImage: "person.crop.circle",
                title: "You",
                message: "Profile, workspace, accent, agent settings. Coming in service-you-screen."
            )

            NavigationLink {
                SettingsView()
            } label: {
                Label("Backend settings", systemImage: "gearshape")
                    .font(.system(size: 16, weight: .medium))
            }
            .buttonStyle(.bordered)
            .padding(.bottom, Theme.Spacing.s5)
        }
        .frame(maxHeight: .infinity)
        .background(Theme.Surface.bg(scheme))
        .navigationTitle("You")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    ContentView()
        .environment(AppModel(repository: MockTmuxAgentRepository()))
        .environment(RootCoordinator())
}
