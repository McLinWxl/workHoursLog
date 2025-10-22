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

fileprivate extension Date {
    func adding(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self)!
    }
    func at(_ hour: Int, _ minute: Int = 0, _ second: Int = 0) -> Date {
        Calendar.current.date(
            bySettingHour: hour, minute: minute, second: second, of: self
        )!
    }
}

enum PreviewData {
    static let container: ModelContainer = {
        let schema = Schema([WorkLogs.self])
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
    }()

    /// 生成最近 14 天的数据，时段类型多样且可预测（非随机，保证截图/对比一致）
    private static func seed(into ctx: ModelContext) {
        // 清空（防止多次注入重复）
        if let existing = try? ctx.fetch(FetchDescriptor<WorkLogs>()) {
            existing.forEach { ctx.delete($0) }
        }

        let today = Date().startOfDay
        // 生成从今天起往前 13 天（共 14 天）
        for i in 0..<14 {
            let day = today.adding(days: -i)

            switch i % 4 {
            case 0:
                // 标准白班：09:00–18:00（8h）
                insert(ctx, start: day.at(9, 0), end: day.at(18, 0))

            case 1:
                // 长班：10:00–20:30（10.5h）
                insert(ctx, start: day.at(10, 0), end: day.at(20, 30))

            case 2:
                // 跨日夜班：20:00–次日 03:00（7h）
                insert(ctx, start: day.at(20, 0), end: day.adding(days: 1).at(3, 0))

            case 3:
                // 半天 + 加班两段：14:00–18:30（4.5h）& 19:30–22:00（2.5h）
                insert(ctx, start: day.at(14, 0), end: day.at(18, 30))
                insert(ctx, start: day.at(19, 30), end: day.at(22, 0))
            default:
                break
            }
        }

        try? ctx.save()
    }

    @discardableResult
    private static func insert(_ ctx: ModelContext, start: Date, end: Date) -> WorkLogs {
        let item = WorkLogs(startTime: start, endTime: end)
        item.touch()              // 刷新 updatedAt，利于冲突合并策略预览
        ctx.insert(item)
        return item
    }
}
