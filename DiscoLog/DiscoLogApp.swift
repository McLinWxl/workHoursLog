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
    @StateObject var userSettings = UserSettings()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            WorkLogs.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(userSettings)
        }
        .modelContainer(sharedModelContainer)
    }
}
