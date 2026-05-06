//
//  ContentView.swift
//  remote-coding
//
//  Created by Nick Buser on 4/30/26.
//

import SwiftUI

/// The v2 5-tab shell — Inbox, Projects, Roadmap, Sessions, You.
///
/// Every tab body is an `EmptyState` placeholder. Each Phase 3 screen
/// ticket replaces one placeholder with its real screen. The terminal
/// is intentionally absent from this top-level set: it becomes a
/// full-screen drill-down reached from Sessions, Inbox `Open pane`
/// actions, or a feature's Sessions sub-tab in later tickets.
struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        TabView(selection: selectedTabBinding) {
            Tab(value: AppTab.inbox) {
                TabPlaceholder(
                    systemImage: "tray",
                    title: "Inbox",
                    message: "Activity that needs you lands here. Coming in service-inbox-screen."
                )
            } label: {
                Label("Inbox", systemImage: "tray")
            }
            .badge(appModel.needsYou ? Text("●") : nil)

            Tab(value: AppTab.projects) {
                TabPlaceholder(
                    systemImage: "square.grid.2x2",
                    title: "Projects",
                    message: "Pinned and all projects. Coming in service-projects-list."
                )
            } label: {
                Label("Projects", systemImage: "square.grid.2x2")
            }

            Tab(value: AppTab.roadmap) {
                TabPlaceholder(
                    systemImage: "chart.bar.xaxis",
                    title: "Roadmap",
                    message: "Milestone timeline. Coming in service-roadmap-screen."
                )
            } label: {
                Label("Roadmap", systemImage: "chart.bar.xaxis")
            }

            Tab(value: AppTab.sessions) {
                TabPlaceholder(
                    systemImage: "terminal",
                    title: "Sessions",
                    message: "Agent sessions, grouped by state. Coming in service-sessions-list."
                )
            } label: {
                Label("Sessions", systemImage: "terminal")
            }

            Tab(value: AppTab.you) {
                YouTabPlaceholder()
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
            get: { appModel.selectedTab },
            set: { appModel.selectedTab = $0 }
        )
    }
}

/// Centred `EmptyState` wrapped in a `NavigationStack` so each tab has
/// its own navigation context. Phase 3 screen tickets replace these
/// bodies one at a time.
private struct TabPlaceholder: View {
    var systemImage: String
    var title: String
    var message: String

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        NavigationStack {
            EmptyState(systemImage: systemImage, title: title, message: message)
                .frame(maxHeight: .infinity)
                .background(Theme.Surface.bg(scheme))
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.large)
        }
    }
}

/// You tab placeholder — keeps the existing API base URL form
/// reachable until `service-you-screen` replaces this body. The form
/// lives behind a `NavigationLink` so the tab doesn't yet visually
/// commit to "You = Settings".
private struct YouTabPlaceholder: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        NavigationStack {
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
}

#Preview {
    ContentView()
        .environment(AppModel(repository: MockTmuxAgentRepository()))
}
