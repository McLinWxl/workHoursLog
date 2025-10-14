//
//  LogForm.swift
//  DiscoLog
//
//  Created by McLin on 2025/10/13.
//

import SwiftUI
import SwiftData

struct LogForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State var workLog: WorkLogs
    @State var isEdit: Bool
    
    @State private var startTime_: Date
    @State private var endTime_: Date
    init(workLog: WorkLogs, isEdit: Bool) {
        self.workLog = workLog
        self.isEdit = isEdit
        self.startTime_ = workLog.startTime
        self.endTime_ = workLog.endTime
    }
    
    var body: some View {
        let workDurations = endTime_.timeIntervalSince(startTime_)
        let workDurationsOfHour = Int(workDurations / 3600)
        let workDurationsOfMinutes = (Int(workDurations) % 3600) / 60
        
        NavigationStack {
            Form {
                Section {
                    DatePicker("开始时间",
                               selection: $startTime_,
                               in: ...Date(),
                               displayedComponents: [.date, .hourAndMinute])
                    .pickerStyle(.wheel)
                    
                    DatePicker("结束时间",
                               selection: $endTime_,
                               displayedComponents: [.date, .hourAndMinute])
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .destructive) {
                        if isEdit == true {
                            modelContext.delete(workLog)
                        }
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .confirm) {
                        workLog.startTime = startTime_
                        workLog.endTime = endTime_
                        modelContext.insert(workLog)
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack (alignment: .bottom) {
                    ZStack {
                        Rectangle()
                            .frame(width: 180, height: 55)
                            .opacity(0)
                            .glassEffect(in: .rect(cornerRadius: 50))
                        
                        Text("\(workDurationsOfHour) 小时 \(workDurationsOfMinutes) 分钟 ")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)

                    }
                    .padding(.leading, 30)

                    
                    Spacer(minLength: 0)
                    
//                    if isEdit == false {
//                        HStack {
//                            Button {
//                                dismiss()
//                            } label: {
//                                Image(systemName: "xmark")
//                            }.buttonStyle(CustomButtonDismiss())
//                                .offset(x: -10)
//                        }
//                    } else {
//                        HStack {
//    //                        Spacer()
//                            Button {
//                                workLog.startTime = startTime_
//                                workLog.endTime = endTime_
//                                dismiss()
//                            } label: {
//                                Image(systemName: "checkmark")
//                            }.buttonStyle(CustomButtonComfirm())
//                        }
//                        .padding(.trailing, 30)
//                    }
                }
                .padding(.bottom, 30)
            }
            .ignoresSafeArea()
        }

    }
}

#Preview {
    let workLog = WorkLogs(startTime: Date().addingTimeInterval(-28800), endTime: Date())
    LogForm(workLog: workLog, isEdit: true)
}
