//
//  DiscoLogApp.swift
//  WorkSession
//
//  Refactored by ChatGPT on 2025/10/25
//

import SwiftUI
import SwiftData

@main
struct DiscoLogApp: App {
    @StateObject private var userSettings: UserSettings
    @StateObject private var modelStore: ModelStore

    init() {
        let settings = UserSettings()
        _userSettings = StateObject(wrappedValue: settings)
        
        _modelStore = StateObject(wrappedValue: ModelStore(cloudEnabled: settings.iCloudSyncEnabled))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(modelStore)
                .environmentObject(userSettings)
                .preferredColorScheme(userSettings.theme.colorScheme)
                .environment(\.locale, .init(identifier: "zh-Hans-CN"))
                .id(ObjectIdentifier(modelStore.container)) 
        }
        // Use the switchable container managed by ModelStore.
        .modelContainer(modelStore.container)
    }
}
