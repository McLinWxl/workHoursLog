import SwiftData
import SwiftUI
import Combine

@MainActor
final class ModelStore: ObservableObject {
    @Published private(set) var container: ModelContainer

    private let schema = Schema([WorkLogs.self])

    init(cloudEnabled: Bool) {
        self.container = try! Self.makeContainer(schema: schema, cloudEnabled: cloudEnabled)
    }

    static func makeContainer(schema: Schema, cloudEnabled: Bool) throws -> ModelContainer {
        let cfg = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: cloudEnabled ? .automatic : .none
        )
        return try ModelContainer(for: schema, configurations: [cfg])
    }

    /// 切换云/本地。保证：快照完成并成功导入新容器后，才“原子”替换 container。
    func switchCloud(to enabled: Bool) async throws {

        // 1) 从“当前容器”做快照（所有 WorkLogs）
        let snapshot = try await snapshotAll(from: container)

        // 2) 构建“目标容器”
        let newContainer = try Self.makeContainer(schema: schema, cloudEnabled: enabled)

        // 3) 将快照导入“目标容器”（含冲突合并）
        try await importAndMerge(snapshot: snapshot, into: newContainer)

        // 4) 成功后再原子切换（旧容器保持到此时，一直在）
        self.container = newContainer
    }

    // MARK: - 快照：把所有记录取出来（值语义，不引用旧容器对象）
    private func snapshotAll(from container: ModelContainer) async throws -> [WorkLogs] {
        let ctx = ModelContext(container)
        let all = try ctx.fetch(FetchDescriptor<WorkLogs>())
        // 用“纯值”快照，避免跨容器对象引用
        return all.map { src in
            let copy = WorkLogs(startTime: src.startTime, endTime: src.endTime, syncID: src.syncID)
            copy.updatedAt = src.updatedAt
            return copy
        }
    }

    // MARK: - 导入 & 合并：以 syncID 为主键；冲突 updatedAt 新者胜；(start,end) 二次去重
    private func importAndMerge(snapshot: [WorkLogs], into container: ModelContainer) async throws {
        let ctx = ModelContext(container)
        ctx.autosaveEnabled = true

        // 先把目标库现有数据做字典，减少查询
        var byID: [UUID: WorkLogs] = [:]
        for item in try ctx.fetch(FetchDescriptor<WorkLogs>()) {
            byID[item.syncID] = item
        }

        // 1) 主键层合并（syncID）
        for src in snapshot {
            if let dst = byID[src.syncID] {
                if src.updatedAt > dst.updatedAt {
                    dst.startTime = src.startTime
                    dst.endTime   = src.endTime
                    dst.updatedAt = src.updatedAt
                }
            } else {
                let neo = WorkLogs(startTime: src.startTime, endTime: src.endTime, syncID: src.syncID)
                neo.updatedAt = src.updatedAt
                ctx.insert(neo)
                byID[neo.syncID] = neo
            }
        }

        // 2) 二次去重：不同 syncID 但时间段完全相同 → 保留 updatedAt 新者
        try deduplicateByTimeKey(in: ctx)

        try ctx.save()
    }

    private func deduplicateByTimeKey(in ctx: ModelContext) throws {
        let all = try ctx.fetch(FetchDescriptor<WorkLogs>())
        var bucket: [String: WorkLogs] = [:]
        for x in all {
            let key = x.timeKey
            if let kept = bucket[key] {
                if x.updatedAt > kept.updatedAt {
                    ctx.delete(kept)
                    bucket[key] = x
                } else {
                    ctx.delete(x)
                }
            } else {
                bucket[key] = x
            }
        }
    }
}
