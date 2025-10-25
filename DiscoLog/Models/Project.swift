//
//  Project.swift
//  DiscoLog
//
//  Created by McLin on 2025/10/25.
//


//
//  Project.swift
//  WorkSession
//
//  Defines a project as the primary grouping for work logs.
//  Keep UI-irrelevant data out; store only domain essentials.
//

import Foundation
import SwiftData

@Model
final class Project {
    // Identity
    @Attribute(.unique) var id: UUID = UUID()

    // Core
    var name: String                    // display name
    var note: String?                   // optional memo
    var colorTag: String                // hex or token (UI maps it to Color)
    var emojiTag: String?               // optional emoji marker, e.g. "🛠️"

    // Lifecycle
    var isArchived: Bool                // archived projects are hidden by default
    var sortOrder: Int                  // for manual ordering in lists

    // Timestamps
    var createdAt: Date
    var updatedAt: Date

    // Payroll/Overtime policy bound to this project
    var payroll: PayrollConfig          // see WorkMode.swift

    // Relations
    @Relationship(inverse: \WorkLog.project)
    var workLogs: [WorkLog] = []

    // MARK: - Init

    init(
        name: String,
        note: String? = nil,
        colorTag: String = "#7B61FF",
        emojiTag: String? = nil,
        isArchived: Bool = false,
        sortOrder: Int = 0,
        payroll: PayrollConfig = PayrollConfig(
            mode: .standardHours,
            periodKind: .monthly,
            dailyRegularHours: 8,
            hoursPerWorkday: 8,
            rateTable: .demo
        )
    ) {
        self.name = name
        self.note = note
        self.colorTag = colorTag
        self.emojiTag = emojiTag
        self.isArchived = isArchived
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.updatedAt = Date()
        self.payroll = payroll
    }

    // MARK: - Mutations

    func rename(to newName: String) {
        guard newName != name else { return }
        name = newName
        touch()
    }

    func archive() { isArchived = true;  touch() }
    func unarchive() { isArchived = false; touch() }

    func updatePayroll(_ cfg: PayrollConfig) { payroll = cfg; touch() }

    func touch() { updatedAt = Date() }
}