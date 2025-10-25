//
//  AppSchema.swift
//  DiscoLog
//
//  Created by McLin on 2025/10/25.
//


// AppSchema.swift
import SwiftData

enum AppSchema {
    /// Keep this list in sync with all @Model types in the app.
    static let current = Schema([
        WorkLog.self,
        Project.self
        // …如果未来新增 @Model，都要加到这里
    ])
}