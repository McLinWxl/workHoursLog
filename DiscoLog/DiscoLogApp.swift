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

        do {
            let store = try ModelStore(cloudEnabled: settings.iCloudSyncEnabled)
            _modelStore = StateObject(wrappedValue: store)
        } catch {
            fatalError("Failed to initialize ModelStore: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(modelStore)
                .environmentObject(userSettings)
                .preferredColorScheme(userSettings.theme.colorScheme)
                .environment(\.locale, .init(identifier: "zh-Hans-CN"))
        }
        // Use the switchable container managed by ModelStore.
        .modelContainer(modelStore.container)
    }
}
