//
//  EditTab.swift
//  DiscoLog
//
//  Created by McLin on 2025/10/13.
//

import SwiftUI
import SwiftData

struct EditTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkLogs.startTime) var workLogs: [WorkLogs]
    @State private var modalType: ModalType?
    @State private var showingLogForm: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(workLogs) { workLog in
                        workLogCard(workLog: workLog)
                            .onTapGesture {
                                modalType = .editLog(workLog)
                            }
                            
                    }
                }
            }
            .navigationTitle("工时记录")
            .background(
                LinearGradient(gradient: Gradient(colors: [Color.mint.opacity(0.3), Color.orange.opacity(0.3)]), startPoint: .topLeading, endPoint: .bottomTrailing)
            )
        }
        .sheet(item: $modalType) {sheet in
            sheet
                .presentationDetents([.height(320),  .large])
                .presentationDragIndicator(.visible)
        }
        .navigationTitle("工时记录")
    }
}

struct workLogCard: View {
    private var workLog: WorkLogs

    private var startTime: Date
    private var endTime: Date
    
    init(workLog: WorkLogs) {
        self.workLog = workLog
        self.startTime = workLog.startTime
        self.endTime = workLog.endTime
    }
    
    var body: some View {
        ZStack {
            Rectangle()
                .frame(height: 125)
                .opacity(0)
                .glassEffect(in: .rect(cornerRadius: 20))
                .padding(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                
            HStack {
                VStack (alignment: .leading) {
                    Text(startTime, format: .dateTime.year().month().day())
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    
                    Rectangle()
                        .fill(.secondary.opacity(0.5))
                        .frame(height: 2)
                    
                    HStack {
                        VStack {
                            Text("开始：\(startTime, format: .dateTime.hour().minute())")
                            Spacer(minLength: 0)
                            Text("结束：\(endTime, format: .dateTime.hour().minute())")
                        }
                        Spacer(minLength: 0)
                        let workDurations = endTime.timeIntervalSince(startTime)
                        let workDurationsOfHour = Int(workDurations / 3600)
                        let workDurationsOfMinutes = (Int(workDurations) % 3600) / 60
                        
                        Text(" \(workDurationsOfHour) 小时 \(workDurationsOfMinutes) 分钟 ")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.orange)
                    }
                }
                .frame(height: 30)
            }
            .padding(EdgeInsets(top: 10, leading: 40, bottom: 10, trailing: 40))
        }
    }
}

#Preview {
    ContentView()
        .environment(\.locale, .init(identifier: "zh-Hans-CN"))
        .modelContainer(for: WorkLogs.self, inMemory: true)
}
