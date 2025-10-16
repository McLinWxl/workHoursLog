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
    @State private var selectedYear = Date().yearInt
    @State private var selectedMonth = Date().monthInt
    @State private var showFilterPanel = false
    
    @State private var modalType: ModalType?


    var body: some View {
        NavigationStack {
            EditList(year: selectedYear, month: selectedMonth)
                .navigationTitle("\(String(selectedYear))年\(String(selectedMonth))月")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            withAnimation(.snappy) { showFilterPanel.toggle() }
                        } label: {
                            Label("筛选", systemImage: "line.3.horizontal.decrease")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            modalType = .addLog
                        } label: {
                            Label("添加", systemImage: "square.and.pencil")
                        }
                    }
                }
                .sheet(item: $modalType) {sheet in
                    sheet
                        .presentationDetents([.medium,  .large])
                        .presentationDragIndicator(.visible)
                }
                .overlay(alignment: .top) {
                    if showFilterPanel {
                        ZStack(alignment: .top) {
                            Color.black.opacity(0.001)
                                .ignoresSafeArea()
                                .onTapGesture { withAnimation(.snappy) { showFilterPanel = false } }

                            MonthFilterPanel(
                                year: $selectedYear,
                                month: $selectedMonth,
                            )
                            .padding(.horizontal, 16)
//                            .padding(.top, 8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                }
                .animation(.snappy, value: showFilterPanel)
        }
    }
}

private struct MonthFilterPanel: View {
    @Binding var year: Int
    @Binding var month: Int
    
    private let years  = Array(2020...Date().yearInt)
    private let months = Array(1...12)

    var body: some View {
        VStack {
            HStack {
                Spacer(minLength: 0)
                Button("回到当月") {
                    year = Date().yearInt
                    month = Date().monthInt
                }
                .foregroundStyle(.blue)
                .buttonStyle(.glass)
            }
            HStack(spacing: 12) {
                
                Picker("年", selection: $year) {
                    ForEach(years, id: \.self) { Text("\($0)年") }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
                .frame(maxHeight: 130)

                Picker("月", selection: $month) {
                    if year == Date().yearInt
                    {
                        ForEach(Array(1...Date().monthInt), id: \.self) { m in
                            Text(String(format: "%02d月", m)).tag(m)
                        }
                    } else {
                        ForEach(months, id: \.self) { m in
                            Text(String(format: "%02d月", m)).tag(m)
                        }
                    }

                }
                .pickerStyle(.wheel)
                .labelsHidden()
                .frame(maxHeight: 130)
            }
        }
        .padding(EdgeInsets(top: 17, leading: 17, bottom: 0, trailing: 17))
//        .glassEffect(in: .rect(cornerRadius: 20))
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.15)))
        .shadow(radius: 10, y: 6)
    }
}

private struct EditList: View {
    let year: Int
    let month: Int

    @State private var modalType: ModalType?
    @Query private var workLogs: [WorkLogs]

    init(year: Int, month: Int) {
        self.year = year
        self.month = month

        let (startOfMonth, startOfNextMonth) = Self.monthBounds(year: year, month: month)
        let predicate = #Predicate<WorkLogs> { log in
            log.startTime < startOfNextMonth && log.endTime > startOfMonth
        }
        _workLogs = Query(filter: predicate, sort: [SortDescriptor(\WorkLogs.startTime, order: .reverse)])
        
    }

    var body: some View {
        ScrollView {
            if workLogs.isEmpty {
                Text("暂无记录")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 320)
                    .frame(maxWidth: .infinity)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 2)) {
                    ForEach(workLogs) { log in
                        workLogCard(workLog: log)
                            .onTapGesture { modalType = .editLog(log) }
                    }
                }
                .padding(.horizontal, 7)
                .padding(.top, 8)
            }

        }
        .sheet(item: $modalType) { sheet in
            sheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
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
    
    private let cardMaxHeight: CGFloat = UIScreen.main.bounds.width / 2 - 20
    private let cardMaxWidth: CGFloat = UIScreen.main.bounds.width / 2 - 20
    init(workLog: WorkLogs) {
        self.workLog = workLog
        self.startTime = workLog.startTime
        self.endTime = workLog.endTime
    }
    
    private var isOvernight: Bool {
        !Calendar.current.isDate(startTime, inSameDayAs: endTime)
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 17)
                .frame(maxWidth: cardMaxWidth, maxHeight: cardMaxHeight)
                .foregroundStyle(
                    isOvernight
                    ? LinearGradient(
                        colors: [
                            Color.indigo.opacity(0.93),
                            Color.indigo.opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                      )
                    : LinearGradient(
                        colors: [
                            Color.mint.opacity(0.3),
                            Color.mint.opacity(0.07)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                      )
                )
                .glassEffect(in: .rect(cornerRadius: 17))
                
            VStack (alignment: .trailing) {
                HStack {
                    Text(String(startTime.dayInt))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(isOvernight ? .white: .primary)
                    
                    Spacer(minLength: 0)
                    
                    if isOvernight {
                        Text("夜")
                            .fontWeight(.semibold)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 4)
                            .background(Color.indigo.opacity(0.99))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .glassEffect(in: .rect(cornerRadius: 8))
                    }
                }
                
                VStack(alignment: .trailing, spacing: 7) {
                    Spacer(minLength: 0)
                    let workDurations = endTime.timeIntervalSince(startTime)
                    let workDurationsOfHour = Int(workDurations / 3600)
                    let workDurationsOfMinutes = (Int(workDurations) % 3600) / 60
                    
                    HStack {
                        Text(" \(workDurationsOfHour) 小时 \(workDurationsOfMinutes) 分钟 ")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(isOvernight ? .yellow : .orange)
                    }
                    
                    HStack {
                        Spacer(minLength: 0)
                        Text("\(startTime, format: .dateTime.hour().minute()) ")
                            .font(.callout)
                            .foregroundStyle(isOvernight ? .white.opacity(0.8): .secondary)
                        Image(systemName: "chevron.right.dotted.chevron.right")
                            .font(.callout)
                            .foregroundStyle(isOvernight ? .white.opacity(0.8): .secondary)
                        HStack (alignment: .center, spacing: 8) {
                            Text("\(endTime, format: .dateTime.hour().minute())")
                                .font(.callout)
                                .foregroundStyle(isOvernight ? .white.opacity(0.8): .secondary)
                            if isOvernight {
                                Text("次")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 3)
                                    .padding(.vertical, 2)
                                    .background(Color.indigo.opacity(0.99))
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                        
                        
                    }
                    .foregroundStyle(isOvernight ? .secondary: .secondary)

                    
                }
            }
            .frame(maxWidth: cardMaxWidth, maxHeight: cardMaxHeight)
            .padding(EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20))
        }
        .contentShape(Rectangle())
    }
}



#Preview {
    EditTab()
        .environment(\.locale, .init(identifier: "zh-Hans-CN"))
        .modelContainer(PreviewListData.container)
}
