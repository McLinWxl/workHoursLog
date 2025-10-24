////
////  EditTab.swift
////  DiscoLog
////
////  Created by McLin on 2025/10/13.
////
//
//import SwiftUI
//import SwiftData
//
//enum LogFilterMode: String, CaseIterable, Identifiable {
//    case all = "全部"
//    case month = "按月"
//    var id: Self { self }
//}
//
//struct EditTab: View {
//    @Query(sort: [SortDescriptor(\WorkLogs.startTime, order: .forward)])
//    private var allLogs: [WorkLogs]
//
//    @State private var selectedYear = Date().yearInt
//    @State private var selectedMonth = Date().monthInt
//    @State private var showFilterPanel = false
//    
//    @State private var modalType: ModalType?
//    
//
//    var body: some View {
//        let today = Date().startOfDay
//        let firstMonth = allLogs.first?.startTime.startOfMonth ?? today.startOfMonth
//        let monthOptions = Date.monthsAscending(from: firstMonth, to: today)
//
//        NavigationStack {
//            EditList(year: selectedYear, month: selectedMonth)
//                .navigationTitle("\(String(selectedYear))年\(String(selectedMonth))月")
//                .toolbar {
//                    ToolbarItem(placement: .topBarLeading) {
//                        Menu {
//                            Button {
//                                selectedYear = Date().yearInt
//                                selectedMonth = Date().monthInt
//                            } label: {
//                                Label("回到本月", systemImage: "arrow.uturn.left")
//                            }
//
//                            // 分组列出所有可选月（按年分组）
//                            let grouped = Dictionary(grouping: monthOptions, by: { $0.yearInt })
//                            ForEach(grouped.keys.sorted(by: >), id: \.self) { y in
//                                Section("\(String(y))年") {
//                                    ForEach(grouped[y]!.sorted(by: { $0.monthInt > $1.monthInt }), id: \.self) { m in
//                                        Button {
//                                            selectedYear = m.yearInt
//                                            selectedMonth = m.monthInt
//                                        } label: {
//                                            HStack {
//                                                Text("\(String(format: "%02d", m.monthInt)) 月")
//                                                if m.yearInt == selectedYear && m.monthInt == selectedMonth {
//                                                    Image(systemName: "checkmark")
//                                                }
//                                            }
//                                        }
//                                    }
//                                }
//                            }
//                        } label: {
//                            Label("选择年月", systemImage: "calendar")
//                        }
//                    }
//
//                    ToolbarItem(placement: .topBarTrailing) {
//                        Button {
//                            modalType = .addLog(defaultDate: Date())
//                        } label: {
//                            Label("添加", systemImage: "square.and.pencil")
//                        }
//                    }
//                }
//                .sheet(item: $modalType) {sheet in
//                    ModalSheetView(modal: sheet)
//                        .presentationDetents([.medium,  .large])
//                        .presentationDragIndicator(.visible)
//                }
//                .animation(.snappy, value: showFilterPanel)
//        }
//    }
//}
//
//private struct EditList: View {
//    let year: Int
//    let month: Int
//
//    @State private var modalType: ModalType?
//    @Query private var workLogs: [WorkLogs]
//
//    init(year: Int, month: Int) {
//        self.year = year
//        self.month = month
//
//        let (startOfMonth, startOfNextMonth) = Self.monthBounds(year: year, month: month)
//        let predicate = #Predicate<WorkLogs> { log in
//            log.startTime < startOfNextMonth && log.endTime > startOfMonth
//        }
//        _workLogs = Query(filter: predicate, sort: [SortDescriptor(\WorkLogs.startTime, order: .reverse)])
//        
//    }
//
//    var body: some View {
//        
//        let days = Date.daysInMonth(year: year, month: month).reversed()
//        let grouped = Dictionary(grouping: workLogs, by: { $0.startTime.startOfDay })
//        
//        let columns = Array(repeating: GridItem(.flexible()), count: 2)
//
//        ScrollView {
//            LazyVGrid(columns: columns, spacing: 8) {           // ← 行间距
//                ForEach(days, id: \.self) { day in
//                    let logs = (grouped[day] ?? []).sorted { $0.startTime < $1.startTime }
//
////                    VStack(alignment: .leading, spacing: 10) {   // ← 同一天内的卡片间距
//                    if logs.isEmpty {
//                        restCard(startTime: day)
//                            .onTapGesture { modalType = .addLog(defaultDate: day) }
//                    } else {
//                        ForEach(logs) { log in
//                            workLogCard(workLog: log)
//                                .onTapGesture { modalType = .editLog(log) }
//                        }
//                    }
////                    }
////                    .padding(.horizontal, 0)
//                }
//            }
//            .padding(.horizontal, 7)
//        }
//        .sheet(item: $modalType) { sheet in
//            ModalSheetView(modal: sheet)
//                .presentationDetents([.medium, .large])
//                .presentationDragIndicator(.visible)
//        }
//    }
//
//    private static func monthBounds(year: Int, month: Int) -> (Date, Date) {
//        let cal = Calendar.current
//        let start = cal.date(from: DateComponents(year: year, month: month, day: 1))!
//        let next  = cal.date(byAdding: .month, value: 1, to: start)!
//        return (start, next)
//    }
//}
//
//struct restCard: View {
//    
//    private var startTime: Date
//    private let cardCorner: CGFloat = 10
//
//    
//    init(startTime: Date) {
//        self.startTime = startTime
//    }
//    
//    var body: some View {
//        ZStack {
//            RoundedRectangle(cornerRadius: cardCorner)
////                .frame(width: width)
//                .foregroundStyle(
//                    LinearGradient(colors: [Color(red: 0.83, green: 0.92, blue: 0.90, opacity: 1.0),
//                                            Color(red: 0.72, green: 0.83, blue: 0.80, opacity: 1.0)
//                                             ]
//                                   , startPoint: .topLeading
//                                   , endPoint: .bottomTrailing
//                      )
//                )
//                .overlay(
//                    RoundedRectangle(cornerRadius: cardCorner)
//                        .stroke(Color.white.opacity(0.8), lineWidth: 2)
//                )
//                .shadow(color: Color.black.opacity(0.18), radius: 4, x: 0, y: 2)
//                .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 4)
//
//            
//            VStack{
//                HStack {
//                    Text(String(format: "%02d", startTime.dayInt))
//                        .font(.largeTitle)
//                        .fontWeight(.bold)
//                        .foregroundStyle(Color(red: 0.12, green: 0.13, blue: 0.13, opacity: 1.0))
//                        .frame(width: 50)
//                    
//                    Spacer(minLength: 0)
//
//                    Image(systemName: "cup.and.saucer.fill")
//                        .font(.caption)
//                        .fontWeight(.semibold)
//                        .padding(.horizontal, 6)
//                        .padding(.vertical, 8)
//                        .background(Color(red: 0.92, green: 0.96, blue: 0.94, opacity: 1.0))
//                        .foregroundStyle(Color(red: 0.35, green: 0.70, blue: 0.65, opacity: 1.0))
//                        .clipShape(RoundedRectangle(cornerRadius: 8))
//                        .glassEffect(in: .rect(cornerRadius: 8))
//                }
//                Spacer(minLength: 0)
//                HStack {
//                    Spacer(minLength: 0)
//                    Text("今日休息")
//                        .font(.callout)
//                        .foregroundStyle(Color(red: 0.36, green: 0.38, blue: 0.37, opacity: 1.0))
//                        .bold()
//                }
//            }
////            .frame(width: width)
//            .padding(EdgeInsets(top: 10, leading: 15, bottom: 10, trailing: 15))
//        }
//        
//        .contentShape(Rectangle())
//
//
//
//    }
//}
//
//struct workLogCard: View {
//    private var workLog: WorkLogs
//
//    private var startTime: Date
//    private var endTime: Date
//    
//    private let cardCorner: CGFloat = 10
//    
//    init(workLog: WorkLogs) {
//        self.workLog = workLog
//        self.startTime = workLog.startTime
//        self.endTime = workLog.endTime
//    }
//    
//    private var isOvernight: Bool {
//        !Calendar.current.isDate(startTime, inSameDayAs: endTime)
//    }
//    
//    var body: some View {
//        
//
//        ZStack {
//            RoundedRectangle(cornerRadius: cardCorner)
////                .frame(maxWidth: cardMaxWidth, maxHeight: .infinity)
//                .foregroundStyle(
//                    isOvernight
//                    ? LinearGradient(
//                        colors: [
//                            Color(red: 0.52, green: 0.45, blue: 0.80, opacity: 1.0),
//                            Color(red: 0.35, green: 0.28, blue: 0.65, opacity: 1.0)
//                        ],
//                        startPoint: .topLeading,
//                        endPoint: .bottomTrailing
//                      )
//                    : LinearGradient(
//                        colors: [
//                            Color(red: 1.00, green: 0.93, blue: 0.75, opacity: 1.0),
//                            Color(red: 1.00, green: 0.85, blue: 0.56, opacity: 1.0)
//                        ],
//                        startPoint: .topLeading,
//                        endPoint: .bottomTrailing
//                      )
//                )
//                .overlay(
//                    RoundedRectangle(cornerRadius: cardCorner)
//                        .stroke(Color.white.opacity(0.8), lineWidth: 2)
//                )
//                .shadow(color: Color.black.opacity(0.18), radius: 4, x: 0, y: 2)
//                .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 4)
////                .glassEffect(in: .rect(cornerRadius: 17))
//                
//            VStack (alignment: .trailing) {
//                HStack {
//                    Text(String(format: "%02d", startTime.dayInt))
//                        .frame(width: 50)
//                        .font(.largeTitle)
//                        .fontWeight(.bold)
//                        .foregroundStyle(isOvernight ? .white : Color(red: 0.12, green: 0.12, blue: 0.13, opacity: 1.0))
//                    
//                    Spacer(minLength: 0)
//                    
//                    if isOvernight {
//                        Image(systemName: "moon.fill")
//                            .font(.callout)
//                            .padding(.horizontal, 4)
//                            .padding(.vertical, 4)
//                            .foregroundStyle(.indigo)
//                            .background(Color(red: 0.67, green: 0.61, blue: 0.86, opacity: 1.0))
//                            .clipShape(RoundedRectangle(cornerRadius: 8))
//                            .glassEffect(in: .rect(cornerRadius: 8))
//                    } else {
//                        Image(systemName: "sun.max.fill")
//                            .font(.callout)
//                            .padding(.horizontal, 4)
//                            .padding(.vertical, 4)
//                            .background(Color(red: 1.00, green: 0.96, blue: 0.85, opacity: 1.0))
//                            .foregroundStyle(Color(red: 1.00, green: 0.73, blue: 0.20, opacity: 1.0))
//                            .clipShape(RoundedRectangle(cornerRadius: 8))
//                            .glassEffect(in: .rect(cornerRadius: 8))
//                    }
//                }
//                
//                VStack(alignment: .trailing, spacing: 7) {
//                    Spacer(minLength: 0)
//                    let workDurations = endTime.timeIntervalSince(startTime)
//                    let workDurationsOfHour = Int(workDurations / 3600)
//                    let workDurationsOfMinutes = (Int(workDurations) % 3600) / 60
//                    
//                    HStack {
//                        Text(" \(workDurationsOfHour) 小时 \(workDurationsOfMinutes) 分钟 ")
//                            .font(.headline)
//                            .fontWeight(.bold)
//                            .foregroundStyle(isOvernight ? Color(red: 1.00, green: 0.62, blue: 0.04, opacity: 1.0) : Color(red: 0.00, green: 0.48, blue: 1.00, opacity: 1.0))
//                    }
//                    
//                    HStack {
//                        Spacer(minLength: 0)
//                        Text("\(startTime, format: .dateTime.hour().minute()) ")
//                            .font(.callout)
//                            .foregroundStyle(isOvernight ? Color(red: 0.85, green: 0.85, blue: 0.90, opacity: 1.0): Color(red: 0.35, green: 0.33, blue: 0.30, opacity: 1.0))
//                        Image(systemName: "chevron.right.dotted.chevron.right")
//                            .frame(maxWidth: 1)
//                            .offset(x: -1)
//                            .font(.caption2)
//                            .foregroundStyle(isOvernight ? Color(red: 0.85, green: 0.85, blue: 0.90, opacity: 1.0): Color(red: 0.35, green: 0.33, blue: 0.30, opacity: 1.0))
//                        HStack (alignment: .center, spacing: 8) {
//                            Text("\(endTime, format: .dateTime.hour().minute())")
//                                .font(.callout)
//                                .foregroundStyle(isOvernight ? Color(red: 0.85, green: 0.85, blue: 0.90, opacity: 1.0): Color(red: 0.35, green: 0.33, blue: 0.30, opacity: 1.0))
//                            if isOvernight {
//                                Text("次")
//                                    .font(.caption)
//                                    .fontWeight(.semibold)
//                                    .padding(.horizontal, 3)
//                                    .padding(.vertical, 2)
//                                    .background(Color.indigo.opacity(0.99))
//                                    .foregroundStyle(.white)
//                                    .clipShape(RoundedRectangle(cornerRadius: 6))
//                            }
//                        }
//                        
//                        
//                    }
//                    .foregroundStyle(isOvernight ? .secondary: .secondary)
//
//                    
//                }
//            }
////            .frame(maxWidth: cardMaxWidth, maxHeight: .infinity)
//            .padding(EdgeInsets(top: 10, leading: 15, bottom: 10, trailing: 15))
//        }
//        .contentShape(Rectangle())
//
//    }
//}
//
//
//
////#Preview {
////    EditTab()
////        .environment(\.locale, .init(identifier: "zh-Hans-CN"))
////        .modelContainer(PreviewData.container)
//
////        .modelContainer(for: PreviewListData.container, inMemory: true)
//}
