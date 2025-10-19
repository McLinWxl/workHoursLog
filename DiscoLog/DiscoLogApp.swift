//
//  DiscoLogApp.swift
//  DiscoLog
//
//  Created by McLin on 2025/10/13.
//

import SwiftUI
import SwiftData


@main
struct DiscoLogApp: App {
    @StateObject private var userSettings = UserSettings()
    @StateObject private var modelStore: ModelStore

    init() {
        // 按“上次选择”初始化容器（默认 false）
        let settings = UserSettings()
        _userSettings = StateObject(wrappedValue: settings)
        _modelStore   = StateObject(wrappedValue: ModelStore(cloudEnabled: settings.iCloudSyncEnabled))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(modelStore)
                .environmentObject(userSettings)
                .preferredColorScheme(userSettings.theme.colorScheme)
        }
        .modelContainer(modelStore.container) // ← 使用可切换的容器
    }
}
