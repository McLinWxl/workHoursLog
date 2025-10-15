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
    var startTime: Date
    var endTime: Date
    
    
    init(startTime: Date, endTime: Date) {
        self.startTime = startTime
        self.endTime = endTime
    }
}


enum PreviewListData {
    static let container: ModelContainer = {
        let schema = Schema([WorkLogs.self])
        let cfg = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let mc = try! ModelContainer(for: schema, configurations: [cfg])

        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)

        // 一周样本，含多段与跨日
        let samples: [WorkLogs] = [
            WorkLogs(startTime: cal.date(bySettingHour: 9,  minute:  0, second: 0, of: today)!, endTime: cal.date(bySettingHour: 12, minute: 0, second: 0, of: today)!),
            WorkLogs(startTime: cal.date(bySettingHour: 13, minute: 30, second: 0, of: today)!, endTime: cal.date(bySettingHour: 18, minute: 0,  second: 0, of: today)!),
            // 前一天的跨夜
            {
                let d = cal.date(byAdding: .day, value: -1, to: today)!
                return WorkLogs(startTime: cal.date(bySettingHour: 22, minute:  0, second: 0, of: d)!,
                                endTime:   cal.date(byAdding: .hour, value: 3, to: cal.date(bySettingHour: 22, minute: 0, second: 0, of: d)!)!)
            }(),
            // 未来一天
            {
                let d = cal.date(byAdding: .day, value: 1, to: today)!
                return WorkLogs(startTime: cal.date(bySettingHour: 10, minute:  0, second: 0, of: d)!,
                                endTime:   cal.date(bySettingHour: 17, minute: 30, second: 0, of: d)!)
            }(),
        ]

        samples.forEach { mc.mainContext.insert($0) }
        return mc
    }()
}
