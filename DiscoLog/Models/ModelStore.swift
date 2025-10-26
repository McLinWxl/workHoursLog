//
//  ModelStore.swift
//  WorkSession
//
//

import SwiftData
import SwiftUI
import Combine

// MARK: - ModelStore

@MainActor
final class ModelStore: ObservableObject {

    // Expose container read-only to views.
    @Published private(set) var container: ModelContainer

    // Schema is explicit to avoid accidental entity drift.
    private let schema = Schema([WorkLog.self, Project.self])

    init(cloudEnabled: Bool, settings: UserSettings? = nil) {
        self.container = try! Self.makeContainer(schema: schema, cloudEnabled: cloudEnabled)
    }
    
    static func makeContainer(schema: Schema, cloudEnabled: Bool) throws -> ModelContainer {
        if cloudEnabled {
            do {
                let cloudCfg = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    allowsSave: true,
                    cloudKitDatabase: .automatic
                )
                return try ModelContainer(for: schema, configurations: [cloudCfg])
            } catch {
                #if DEBUG
                print("❌ Cloud init error: \(error)")
                #endif
                // fall through to local
            }
        }
        let localCfg = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [localCfg])
    }

    // MARK: Factory

    static func buildContainer(
        schema: Schema,
        cloudEnabled: Bool,
        inMemory: Bool = false
    ) throws -> ModelContainer {
        let cfg = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            allowsSave: true,
            cloudKitDatabase: cloudEnabled ? .automatic : .none
        )
        return try ModelContainer(for: schema, configurations: [cfg])
    }

    // MARK: Storage Switch (Local <-> Cloud)

    /// Atomically switch storage by snapshotting all data, building a target container, importing with merge policy, then swapping the container.
    func switchCloud(to enabled: Bool) async throws {
        // 1) Snapshot from current container
        let snapshot = try await snapshotAll(from: container)

        // 2) Build target container
        let newContainer = try Self.buildContainer(schema: schema, cloudEnabled: enabled)

        // 3) Import & merge into target
        try await importAndMerge(snapshot: snapshot, into: newContainer, policy: .default)

        // 4) Swap atomically after success
        self.container = newContainer
    }

    // MARK: Snapshot (value semantics)

    /// Value snapshot to avoid cross-container references.
    private func snapshotAll(from container: ModelContainer) async throws -> [WorkLogDTO] {
        let ctx = ModelContext(container)
        let all = try ctx.fetch(FetchDescriptor<WorkLog>())
        return all.map { WorkLogDTO(from: $0) }
    }

    // MARK: Import & Merge

    private func importAndMerge(
        snapshot: [WorkLogDTO],
        into container: ModelContainer,
        policy: MergePolicy
    ) async throws {
        let ctx = ModelContext(container)
        ctx.autosaveEnabled = true

        // Index destination by syncID to reduce queries.
        var byID: [UUID: WorkLog] = [:]
        for item in try ctx.fetch(FetchDescriptor<WorkLog>()) {
            byID[item.syncID] = item
        }

        // 1) Primary-key upsert (syncID)
        for src in snapshot {
            if let dst = byID[src.syncID] {
                if policy.shouldOverwrite(srcUpdatedAt: src.updatedAt, dstUpdatedAt: dst.updatedAt) {
                    dst.startTime = src.startTime
                    dst.endTime   = src.endTime
                    dst.updatedAt = src.updatedAt
                }
            } else {
                let neo = src.materialize()
                ctx.insert(neo)
                byID[neo.syncID] = neo
            }
        }

        // 2) Secondary dedup: identical time range but different syncID -> keep latest updatedAt
        try deduplicateByTimeKey(in: ctx, policy: policy)

        try ctx.save()
    }

    private func deduplicateByTimeKey(in ctx: ModelContext, policy: MergePolicy) throws {
        let all = try ctx.fetch(FetchDescriptor<WorkLog>())
        var bucket: [String: WorkLog] = [:]
        for x in all {
            let key = x.timeKey
            if let kept = bucket[key] {
                if policy.shouldOverwrite(srcUpdatedAt: x.updatedAt, dstUpdatedAt: kept.updatedAt) {
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

// MARK: - DTO (value snapshot)

/// Immutable snapshot used to move data across containers safely.
struct WorkLogDTO: Sendable, Hashable {
    let syncID: UUID
    let startTime: Date
    let endTime: Date
    let updatedAt: Date

    init(syncID: UUID, startTime: Date, endTime: Date, updatedAt: Date) {
        self.syncID = syncID
        self.startTime = startTime
        self.endTime = endTime
        self.updatedAt = updatedAt
    }

    init(from model: WorkLog) {
        self.init(syncID: model.syncID,
                  startTime: model.startTime,
                  endTime: model.endTime,
                  updatedAt: model.updatedAt)
    }

    func materialize() -> WorkLog {
        let m = WorkLog(startTime: startTime, endTime: endTime, syncID: syncID)
        m.updatedAt = updatedAt
        return m
    }
}

// MARK: - Merge Policy

/// Centralized merge decisions; extend here for future rules.
struct MergePolicy {
    /// Newer `updatedAt` wins.
    func shouldOverwrite(srcUpdatedAt: Date, dstUpdatedAt: Date) -> Bool {
        srcUpdatedAt > dstUpdatedAt
    }

    static let `default` = MergePolicy()
}
