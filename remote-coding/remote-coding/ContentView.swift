//
//  ContentView.swift
//  remote-coding
//
//  Created by Nick Buser on 4/30/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        TabView(selection: selectedTabBinding) {
            ProjectListView()
                .tabItem {
                    Label("Projects", systemImage: "folder")
                }
                .tag(AppTab.projects)

            TerminalView()
                .tabItem {
                    Label("Terminal", systemImage: "terminal")
                }
                .tag(AppTab.terminal)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(AppTab.settings)
        }
    }

    private var selectedTabBinding: Binding<AppTab> {
        Binding(
            get: { appModel.selectedTab },
            set: { appModel.selectedTab = $0 }
        )
    }
}

#Preview {
    ContentView()
        .environment(AppModel(repository: MockTmuxAgentRepository()))
}
