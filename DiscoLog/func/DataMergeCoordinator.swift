//
//  DataMergeCoordinator.swift
//  DiscoLog
//
//  Created by McLin on 2025/10/20.
//


import SwiftData
import Combine
import Foundation

struct DataMergeCoordinator {

    /// 在“打开 iCloud”时调用。把本地库的数据合并进云库，并从云拉取缺失数据。
    static func migrateLocalToCloud(localURL: URL, cloudURL: URL) throws {
        let schema = Schema([WorkLogs.self])

        // 1) 建立“只读本地”容器，拍个快照
        let localCfg = ModelConfiguration(schema: schema, url: localURL)
        let localContainer = try ModelContainer(for: schema, configurations: [localCfg])
        let localCtx = ModelContext(localContainer)
        let localAll = try localCtx.fetch(FetchDescriptor<WorkLogs>())

        // 2) 建立“可写云”容器
        let cloudCfg = ModelConfiguration(schema: schema, url: cloudURL, cloudKitDatabase: .automatic)
        let cloudContainer = try ModelContainer(for: schema, configurations: [cloudCfg])
        let cloudCtx = ModelContext(cloudContainer)

        // 3) 云端现有数据
        let cloudAll = try cloudCtx.fetch(FetchDescriptor<WorkLogs>())

        // 4) 索引云端：按 syncID 建立字典
//        var cloudByID = Dictionary(uniqueKeysWithValues: cloudAll.map { ($0.syncID, $0) })
        let cloudByID: [UUID: WorkLogs] =
            Dictionary(cloudAll.map { ($0.syncID, $0) },
                       uniquingKeysWith: { a, b in
                           (a.updatedAt >= b.updatedAt) ? a : b
                       })

        // 5) 合并：把本地的“灌入云端”
        for local in localAll {
            if let hit = cloudByID[local.syncID] {
                // 同 ID：按 updatedAt 取新
                if local.updatedAt > hit.updatedAt {
                    hit.startTime = local.startTime
                    hit.endTime   = local.endTime
//                    hit.note      = local.note
                    hit.updatedAt = local.updatedAt
                }
            } else {
                // 不同 ID：尝试用 (start,end) 兜底匹配（±60s 容忍）
                if let dupe = cloudAll.first(where: { approxEqual($0, local) }) {
                    // 认为是同一条：用更新策略
                    if local.updatedAt > dupe.updatedAt {
                        dupe.startTime = local.startTime
                        dupe.endTime   = local.endTime
//                        dupe.note      = local.note
                        dupe.updatedAt = local.updatedAt
                        dupe.syncID    = local.syncID   // 补上稳定主键
                    }
                } else {
                    // 云端不存在 → 直接插入到云
                    let copy = WorkLogs(startTime: local.startTime,
                                        endTime: local.endTime,
//                                        note: local.note,
                                        syncID: local.syncID)
                    copy.updatedAt = local.updatedAt
                    cloudCtx.insert(copy)
                }
            }
        }

        try cloudCtx.save()   // 触发上行；云端 mirroring 会继续处理
    }

    /// 宽容相等：开始/结束时间都在容忍阈值内（避免极小漂移造成重复）
    private static func approxEqual(_ a: WorkLogs, _ b: WorkLogs, eps: TimeInterval = 60) -> Bool {
        abs(a.startTime.timeIntervalSince(b.startTime)) < eps &&
        abs(a.endTime.timeIntervalSince(b.endTime))     < eps
    }
}
