//
//  ModalType.swift
//  DiscoLog
//
//  Created by McLin on 2025/10/13.
//

import SwiftUI

enum ModalType: View, Identifiable, Equatable {
    case addLog
    case editLog(WorkLogs)
    
    var id: String {
        switch self {
        case .addLog:
            "addLog"
        case .editLog:
            "editLog"
        }
    }
    
    var body: some View{
        switch self {
        case .addLog:
            let workLog = WorkLogs(startTime: Date().addingTimeInterval(-28800), endTime: Date())
            LogForm(workLog: workLog, isEdit: false)
        case .editLog(let Log):
            LogForm(workLog: Log, isEdit: true)
        }
    }
}
