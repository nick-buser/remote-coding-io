//
//  remote_codingApp.swift
//  remote-coding
//
//  Created by Nick Buser on 4/30/26.
//

import SwiftUI

@main
struct remote_codingApp: App {
    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    @State private var appModel: AppModel
    @State private var coordinator = RootCoordinator()
    @State private var preferences: UserPreferences
    @State private var pushService: PushRegistrationService

    init() {
        let appModel = AppModel()
        let preferences = UserPreferences()
        _appModel = State(initialValue: appModel)
        _preferences = State(initialValue: preferences)
        _pushService = State(initialValue: PushRegistrationService(
            repositoryProvider: { appModel.repository },
            preferences: preferences,
            pushSystem: LivePushSystem()
        ))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
                .environment(coordinator)
                .environment(preferences)
                .environment(pushService)
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
                    bindPushDelegate()
                }
        }
    }

    private func bindPushDelegate() {
        #if canImport(UIKit)
        appDelegate.onDeviceTokenReceived = { [pushService] data in
            Task { @MainActor in await pushService.applyDeviceToken(data) }
        }
        appDelegate.onDeviceRegistrationFailed = { [pushService] error in
            Task { @MainActor in pushService.handleRegistrationFailure(error) }
        }
        #endif
    }
}
