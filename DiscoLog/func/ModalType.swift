//
//  ModalType.swift
//  DiscoLog
//
//  Created by McLin on 2025/10/13.
//

import SwiftUI

enum ModalType: View, Identifiable, Equatable {
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
    
    @ViewBuilder
    var body: some View{

        switch self {
        case .addLog(let defaultDate):
//            let calendar = Calendar.current
//            let startTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: defaultDate)!
//            let endTime   = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: defaultDate)!
            @StateObject var userSettings = UserSettings()

            let workLog = WorkLogs(startTime: userSettings.start(on: defaultDate), endTime: userSettings.end(on: defaultDate))
            LogForm(workLog: workLog, isEdit: false)
        case .editLog(let Log):
            LogForm(workLog: Log, isEdit: true)
        }
    }
}
