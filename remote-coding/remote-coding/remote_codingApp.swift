//
//  remote_codingApp.swift
//  remote-coding
//
//  Created by Nick Buser on 4/30/26.
//

import SwiftUI

@main
struct remote_codingApp: App {
    @State private var appModel = AppModel(repository: MockTmuxAgentRepository())

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
        }
    }
}
