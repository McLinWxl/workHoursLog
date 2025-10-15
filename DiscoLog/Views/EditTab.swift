//
//  EditTab.swift
//  DiscoLog
//
//  Created by McLin on 2025/10/13.
//

import SwiftUI
import SwiftData

enum LogFilterMode: String, CaseIterable, Identifiable {
    case all = "全部"
    case month = "按月"
    var id: Self { self }
}

struct EditTab: View {
    @State private var mode: LogFilterMode = .all
    @State private var selectedYear = Date().yearInt
    @State private var selectedMonth = Date().monthInt

    private let years  = Array(2020...Date().yearInt)
    private let months = Array(1...12)

    var body: some View {
        NavigationStack {
            headerFilter
                .offset(y: -10)
                .frame(height: 45)
            
            Spacer(minLength: 0)

            EditList(mode: mode, year: selectedYear, month: selectedMonth)
                .navigationTitle("工时记录")


        }
    }

    private var headerFilter: some View {
        HStack(alignment: .center) {
            Picker("筛选", selection: $mode) {
                ForEach(LogFilterMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            Spacer(minLength: 0)

            if mode == .month {
                HStack {
                    Picker("年", selection: $selectedYear) {
                        ForEach(years, id: \.self) {
                            Text("\($0)年").font(.subheadline)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 90, height: 95)
                    .offset(x: 12)

                    Picker("月", selection: $selectedMonth) {
                        ForEach(1...12, id: \.self) { m in
                            Text(String(format: "%02d月", m)).font(.subheadline).tag(m)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 90, height: 95)
                }
            }

        }
        .offset(y:7)
        .padding(.horizontal)
        .frame(height: 30)
    }
}

private struct EditList: View {
    let mode: LogFilterMode
    let year: Int
    let month: Int
    
    @State private var modalType: ModalType?
    @Query private var workLogs: [WorkLogs]

    init(mode: LogFilterMode, year: Int, month: Int) {
        self.mode = mode
        self.year = year
        self.month = month

        switch mode {
        case .all:
            _workLogs = Query(sort: \WorkLogs.startTime)
        case .month:
            let (startOfMonth, startOfNextMonth) = Self.monthBounds(year: year, month: month)
            let predicate = #Predicate<WorkLogs> { log in
                log.startTime < startOfNextMonth && log.endTime > startOfMonth
            }
            _workLogs = Query(filter: predicate, sort: [SortDescriptor(\WorkLogs.startTime)])
        }
    }

    var body: some View {
        
        if workLogs.isEmpty {
            Text("暂无记录")
                .foregroundStyle(.secondary)
                .padding(.vertical, 32)
            Spacer(minLength: 0)
        } else {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(workLogs) { log in
                        workLogCard(workLog: log)
                            .onTapGesture {
                                modalType = .editLog(log)}
                    }
                }
                .padding(.top, 10)
                .padding(.horizontal)
            }
            .sheet(item: $modalType) {sheet in
                sheet
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
        }
    }
}

    private static func monthBounds(year: Int, month: Int) -> (Date, Date) {
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: year, month: month, day: 1))!
        let next  = cal.date(byAdding: .month, value: 1, to: start)!
        return (start, next)
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
//                .foregroundStyle(.ultraThickMaterial)
                .frame(height: 125)
                .opacity(0)
                .glassEffect(in: .rect(cornerRadius: 17))
//                .backgroundStyle(.thickMaterial)
                
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
            .padding(EdgeInsets(top: 7, leading: 20, bottom: 7, trailing: 20))
        }
    }
}



#Preview {
    EditTab()
        .environment(\.locale, .init(identifier: "zh-Hans-CN"))
        .modelContainer(PreviewListData.container)
}
