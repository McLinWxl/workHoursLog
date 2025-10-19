//
//  Item.swift
//  DiscoLog
//
//  Created by McLin on 2025/10/13.
//

import Foundation
import SwiftData

@Model
final class WorkLogs {
    var syncID: UUID = UUID()

    var startTime: Date = Date() {
        didSet { updatedAt = Date() }  // ⬅️ 任意修改都会刷新
    }
    var endTime: Date = Date() {
        didSet { updatedAt = Date() }
    }

    var updatedAt: Date = Date()

    init(startTime: Date, endTime: Date, syncID: UUID = UUID()) {
        self.syncID    = syncID
        self.startTime = startTime
        self.endTime   = endTime
        self.updatedAt = Date()
    }

    func touch() { updatedAt = Date() }
    var timeKey: String { "\(startTime.timeIntervalSince1970)-\(endTime.timeIntervalSince1970)" }
}
