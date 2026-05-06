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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
                .environment(coordinator)
                .environment(\.accent, appModel.accent)
        }
    }
}
