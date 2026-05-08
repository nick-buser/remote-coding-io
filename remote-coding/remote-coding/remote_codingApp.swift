//
//  remote_codingApp.swift
//  remote-coding
//
//  Created by Nick Buser on 4/30/26.
//

import SwiftUI

@main
struct remote_codingApp: App {
    @State private var appModel = AppModel()
    @State private var coordinator = RootCoordinator()
    @State private var preferences = UserPreferences()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
                .environment(coordinator)
                .environment(preferences)
                .environment(\.accent, preferences.accent)
                .preferredColorScheme(preferences.appearance.preferredColorScheme)
                .dynamicTypeSize(preferences.textSize.dynamicTypeSize)
                .onChange(of: preferences.accent) { _, newValue in
                    appModel.accent = newValue
                }
                .task {
                    // Initial sync so AppModel.accent matches the
                    // persisted user preference at startup.
                    appModel.accent = preferences.accent
                }
        }
    }
}
