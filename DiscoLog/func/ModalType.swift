//
//  ModalType.swift
//  WorkSession
//
//

import SwiftUI
import SwiftData

// MARK: - Modal Routing

enum ModalType: Identifiable, Equatable {
    case addLog(defaultDate: Date)
    case editLog(WorkLog)

    /// Stable identity to ensure sheet refreshes correctly.
    var id: String {
        switch self {
        case .addLog(let d):
            // Use day key to differentiate different "add" targets
            let dayKey = DateFormatter.yyyyMMdd.string(from: d.startOfDay)
            return "add-\(dayKey)"
        case .editLog(let log):
            // Use model's unique identity
            return "edit-\(log.syncID.uuidString)"
        }
    }

    // Custom equality: avoid comparing entire WorkLog object graph.
    static func == (lhs: ModalType, rhs: ModalType) -> Bool {
        switch (lhs, rhs) {
        case let (.addLog(d1), .addLog(d2)):
            return d1.startOfDay == d2.startOfDay
        case let (.editLog(a), .editLog(b)):
            return a.syncID == b.syncID
        default:
            return false
        }
    }
}

// MARK: - Modal Sheet Host

struct ModalSheetView: View {
    let modal: ModalType
    @EnvironmentObject var userSettings: UserSettings

    @Query private var activeProjects: [Project]

    init(modal: ModalType) {
        self.modal = modal
        let pred: Predicate<Project> = #Predicate { $0.isArchived == false }
        let sorts: [SortDescriptor<Project>] = [
            SortDescriptor(\Project.sortOrder, order: .forward),
            SortDescriptor(\Project.createdAt,  order: .forward)
        ]
        _activeProjects = Query(filter: pred, sort: sorts)
    }

    var body: some View {
        switch modal {
        case .addLog(let defaultDate):
            let start = userSettings.start(on: defaultDate)
            let end   = userSettings.end(on: defaultDate)

            // weekend => rest, no holiday
            let wd = Calendar.current.component(.weekday, from: defaultDate) // 1=Sun ... 7=Sat
            let isWeekend = (wd == 1 || wd == 7)

            let draft = WorkLog(startTime: start,
                                endTime: end,
                                isRestDay: isWeekend,
                                isHoliday: false)

            // 只传“默认项目ID”，不要把 Project 挂到 draft 上
            let prefillID = resolveDefaultProjectID()

            LogForm(workLog: draft, isEdit: false, prefillProjectID: prefillID)

        case .editLog(let log):
            LogForm(workLog: log, isEdit: true, prefillProjectID: nil)
        }
    }

    /// 优先使用用户设置的默认项目；无则回退到第一个有效项目；都无则 nil
    private func resolveDefaultProjectID() -> UUID? {
        if let id = userSettings.defaultProjectID,
           activeProjects.contains(where: { $0.id == id && !$0.isArchived }) {
            return id
        }
        return activeProjects.first?.id
    }
}

private extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let f = DateFormatter()
        f.calendar = .current
        f.locale = .current
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
