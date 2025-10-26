//
//  WorkLog.swift
//  WorkSession
//
//  Created by McLin on 2025/10/13.
//

import Foundation
import SwiftData
import Combine

// MARK: - Model

@Model
final class WorkLog {
    var syncID: UUID = UUID()

    // Core times
    var startTime: Date = Date.now  { didSet { touch() } }
    var endTime: Date = Date.now  { didSet { touch() } }
    
    var isRestDay: Bool = false  { didSet { touch() } }
    var isHoliday: Bool = false  { didSet { touch() } }

    // Relations
    @Relationship(deleteRule: .nullify, inverse: \Project.workLogs)
    var project: Project? = nil
    
    /// Updated whenever a persisted field changes.
    var updatedAt: Date = Date.now

    // MARK: Init
    init(startTime: Date, endTime: Date, isRestDay: Bool = false, isHoliday: Bool = false, syncID: UUID = UUID(), project: Project? = nil) {
        self.syncID    = syncID
        self.startTime = startTime
        self.endTime   = endTime
        self.isRestDay = isRestDay
        self.isHoliday = isHoliday
        self.project   = project
        self.updatedAt = Date()
    }

    // MARK: Derived

    /// Key for quick diff/merge.
    var timeKey: String { "\(startTime.timeIntervalSince1970)-\(endTime.timeIntervalSince1970)" }

    /// Duration in seconds (≥ 0).
    var duration: TimeInterval { max(0, endTime.timeIntervalSince(startTime)) }

    /// Crosses midnight?
    var isOvernight: Bool { !Calendar.current.isDate(startTime, inSameDayAs: endTime) }

    /// Interval overlap.
    func overlaps(with other: WorkLog) -> Bool {
        (startTime < other.endTime) && (endTime > other.startTime)
    }

    /// Ensure `startTime <= endTime`.
    func normalized() {
        if endTime < startTime { swap(&self.startTime, &self.endTime) }
    }

    /// Bump `updatedAt`.
    func touch() { updatedAt = Date() }
}

// MARK: - Preview / In-memory seeding

enum PreviewSeed {
    /// In-memory container for previews (WorkLog + Project schema).
    static func container() -> ModelContainer {
        let schema = Schema([WorkLog.self, Project.self])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        let container = try! ModelContainer(for: schema, configurations: [config])
        let ctx = ModelContext(container)
        seed(into: ctx)
        return container
    }

    /// Deterministic 14-day dataset across two projects for consistent snapshots.
    static func seed(into ctx: ModelContext) {
        // Clear previous
        if let logs = try? ctx.fetch(FetchDescriptor<WorkLog>()) { logs.forEach { ctx.delete($0) } }
        if let prjs = try? ctx.fetch(FetchDescriptor<Project>()) { prjs.forEach { ctx.delete($0) } }

        // Demo projects with different payroll configs
        let pA = Project(
            name: "Alpha",
            colorTag: "#7B61FF",
            payroll: PayrollConfig(
                mode: .standardHours,
                periodKind: .monthly,
                dailyRegularHours: 8,
                hoursPerWorkday: 8,
                rateTable: RateTable(basePerHour: 35, multipliers: .init(workday: 1.5, restDay: 2.0, holiday: 3.0))
            )
        )
        let pB = Project(
            name: "Beta",
            colorTag: "#34C759",
            payroll: PayrollConfig(
                mode: .comprehensiveHours,
                periodKind: .monthly,
                dailyRegularHours: 8,
                hoursPerWorkday: 7.5,
                rateTable: RateTable(basePerHour: 30, multipliers: .init(workday: 1.5, restDay: 2.0, holiday: 3.0))
            )
        )
        ctx.insert(pA); ctx.insert(pB)

        // Logs: 14 days, alternate projects
        let today = Date().startOfDay
        for i in 0..<14 {
            let day = today.addingDays(-i)
            let project = (i % 2 == 0) ? pA : pB

            switch i % 4 {
            case 0:
                insert(ctx, start: day.at(hour: 9), end: day.at(hour: 18), project: project)
            case 1:
                insert(ctx, start: day.at(hour: 10), end: day.at(hour: 20, minute: 30), project: project)
            case 2:
                insert(ctx, start: day.at(hour: 20), end: day.addingDays(1).at(hour: 3), project: project)
            case 3:
                insert(ctx, start: day.at(hour: 14), end: day.at(hour: 18, minute: 30), project: project)
                insert(ctx, start: day.at(hour: 19, minute: 30), end: day.at(hour: 22), project: project)
            default:
                break
            }
        }

        try? ctx.save()
    }

    @discardableResult
    private static func insert(_ ctx: ModelContext, start: Date, end: Date, project: Project?) -> WorkLog {
        let log = WorkLog(startTime: start, endTime: end, project: project)
        log.normalized()
        log.touch()
        ctx.insert(log)
        return log
    }
}
