//
//  ModalType.swift
//  DiscoLog
//
//  Created by McLin on 2025/10/13.
//

import SwiftUI

enum ModalType: Identifiable, Equatable {
    case addLog(defaultDate: Date)
    case editLog(WorkLogs)
    
    
    var id: String {
        switch self {
        case .addLog:
            "addLog"
        case .editLog:
            "editLog"
        }
    }
    
//    @ViewBuilder
//    var body: some View{
//
//        switch self {
//        case .addLog(let defaultDate):
//
//            @StateObject var userSettings = UserSettings()
//
//            let workLog = WorkLogs(startTime: userSettings.start(on: defaultDate), endTime: userSettings.end(on: defaultDate))
//            LogForm(workLog: workLog, isEdit: false)
//        case .editLog(let Log):
//            LogForm(workLog: Log, isEdit: true)
//        }
//    }
}

struct ModalSheetView: View {
    let modal: ModalType
    @EnvironmentObject var userSettings: UserSettings

    var body: some View {
        switch modal {
        case .addLog(let defaultDate):
            // 用环境里的 settings 生成开始/结束时间
            let start = userSettings.start(on: defaultDate)
            let end   = userSettings.end(on: defaultDate)
            let workLog = WorkLogs(startTime: start, endTime: end)
            LogForm(workLog: workLog, isEdit: false)

        case .editLog(let log):
            LogForm(workLog: log, isEdit: true)
        }
    }
}
