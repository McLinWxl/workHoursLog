//
//  CalendarCardTab.swift
//  DiscoLog
//
//  Created by McLin on 2025/10/24.
//


import SwiftUI
import SwiftData

enum LogFilterMode: String, CaseIterable, Identifiable {
    case all = "全部"
    case month = "按月"
    var id: Self { self }
}

struct YearMonth: Hashable {
    let year: Int
    let month: Int
}

struct CalendarCardTab: View {
    @Query(sort: [SortDescriptor(\WorkLogs.startTime, order: .forward)])
    private var allLogs: [WorkLogs]

    @State private var selectedYear = Date().yearInt
    @State private var selectedMonth = Date().monthInt
    @State private var showFilterPanel = false
    
    @State private var modalType: ModalType?
    @State private var addDay: Date?  //
    
    @Environment(\.colorScheme) private var colorScheme

    

    var body: some View {
        let today = Date().startOfDay
        let firstMonth = allLogs.first?.startTime.startOfMonth ?? today.startOfMonth
        let monthOptions = Date.monthsAscending(from: firstMonth, to: today)
        
        let monthDate = Calendar.current.date(from: DateComponents(year: selectedYear, month: selectedMonth, day: 1)) ?? Date().startOfMonth
        
        
        let m0 = monthDate.startOfMonth
        let m1 = monthDate.startOfNextMonth
        let inMonth = allLogs.filter { $0.startTime >= m0 && $0.startTime < m1 }
        let _ = inMonth.reduce(0.0) { acc, log in
            acc + max(0, log.endTime.timeIntervalSince(log.startTime))
        }
        
        NavigationStack {
            ScrollView {
                SummaryCard(monthDate: monthDate)
                    .navigationTitle("工时记录")
                    .padding(.vertical, 40)

                
                            
                MonthSection(
                    monthDate: monthDate,
                    allLogs: allLogs,
                    onTapLog: { modalType = .editLog($0) },
                    onTapRestDay: { day in
                        addDay = day
                        modalType = .addLog(defaultDate: day)
                    }
                )
                .padding(.horizontal, 5)
                .padding(.bottom, 40)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            selectedYear = Date().yearInt
                            selectedMonth = Date().monthInt
                        } label: {
                            Label("回到本月", systemImage: "arrow.uturn.left")
                        }

                        // 分组列出所有可选月（按年分组）
                        let grouped = Dictionary(grouping: monthOptions, by: { $0.yearInt })
                        ForEach(grouped.keys.sorted(by: >), id: \.self) { y in
                            Section("\(String(y))年") {
                                ForEach(grouped[y]!.sorted(by: { $0.monthInt > $1.monthInt }), id: \.self) { m in
                                    Button {
                                        selectedYear = m.yearInt
                                        selectedMonth = m.monthInt
                                    } label: {
                                        HStack {
                                            Text("\(String(format: "%02d", m.monthInt)) 月")
                                            if m.yearInt == selectedYear && m.monthInt == selectedMonth {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } label: {
                        Label("选择年月", systemImage: "calendar")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        modalType = .addLog(defaultDate: Date())
                    } label: {
                        Label("添加", systemImage: "square.and.pencil")
                    }
                }
                
            }
            .sheet(item: $modalType) {sheet in
                ModalSheetView(modal: sheet)
                    .presentationDetents([.medium,  .large])
                    .presentationDragIndicator(.visible)
            }
            .animation(.snappy, value: showFilterPanel)
//            .navigationBarTitleDisplayMode(.inline)
            
            HStack{
                Button {
                    selectedMonth -= 1
                } label: {
                    Text("\(Image(systemName: "arrowtriangle.backward.fill")) \(String(selectedMonth-1))月")
                        .foregroundStyle(colorScheme == .dark ? .white : .black)

                        .font(.callout)
                        .padding()
                }
                .glassEffect()
                
                Spacer(minLength: 0)
                
                NavigationLink (value: YearMonth(year: selectedYear, month: selectedMonth)) {
                    Text("详细记录")
                        .foregroundStyle(.white)
                        .font(.callout.bold())
                        .padding()
                        .glassEffect(.regular.tint(.orange.opacity(0.9)).interactive())
                }
                .navigationDestination(for: YearMonth.self) { target in
                    EditList(year: target.year, month: target.month)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Menu {
                                    Button {
                                        selectedYear = Date().yearInt
                                        selectedMonth = Date().monthInt
                                    } label: {
                                        Label("回到本月", systemImage: "arrow.uturn.left")
                                    }

                                    // 分组列出所有可选月（按年分组）
                                    let grouped = Dictionary(grouping: monthOptions, by: { $0.yearInt })
                                    ForEach(grouped.keys.sorted(by: >), id: \.self) { y in
                                        Section("\(String(y))年") {
                                            ForEach(grouped[y]!.sorted(by: { $0.monthInt > $1.monthInt }), id: \.self) { m in
                                                Button {
                                                    selectedYear = m.yearInt
                                                    selectedMonth = m.monthInt
                                                } label: {
                                                    HStack {
                                                        Text("\(String(format: "%02d", m.monthInt)) 月")
                                                        if m.yearInt == selectedYear && m.monthInt == selectedMonth {
                                                            Image(systemName: "checkmark")
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    Label("选择年月", systemImage: "calendar")
                                }
                            }

                            ToolbarItem(placement: .topBarTrailing) {
                                Button {
                                    modalType = .addLog(defaultDate: Date())
                                } label: {
                                    Label("添加", systemImage: "square.and.pencil")
                                }
                            }
                        }

                }
                
                Spacer(minLength: 0)
                
                Button {
                    selectedMonth += 1
                } label: {
                    Text("\(String(selectedMonth+1))月 \(Image(systemName: "arrowtriangle.forward.fill"))")
                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                        .font(.callout)
                        .padding()
                }
                .glassEffect()
            }
            .sheet(item: $modalType) {sheet in
                ModalSheetView(modal: sheet)
                    .presentationDetents([.medium,  .large])
                    .presentationDragIndicator(.visible)
            }
            .animation(.snappy, value: showFilterPanel)
        
            .padding(.horizontal, 22)
            .padding(.bottom)
        }
    }
}


struct SummaryCard: View {
    let monthDate: Date
    @Query private var allLogs: [WorkLogs] 
    @State private var showExplanation = false

    private var monthLogs: [WorkLogs] {
        allLogs.filter {
            Calendar.current.isDate($0.startTime, equalTo: monthDate, toGranularity: .month)
        }
    }
    
    private var totalHours: Double {
        monthLogs.reduce(0) { $0 + $1.endTime.timeIntervalSince($1.startTime) / 3600 }
    }
    
    private var workDays: Int {
        let days = Set(monthLogs.map { Calendar.current.startOfDay(for: $0.startTime) })
        return days.count
    }
    
    private var workHourRatio: Double {
        let calendar = Calendar.current
        let today = Date()
        
        guard let range = calendar.range(of: .day, in: .month, for: monthDate) else { return 0 }
        
        let allDays = range.compactMap { day -> Date? in
            calendar.date(from: DateComponents(year: monthDate.yearInt, month: monthDate.monthInt, day: day))
        }
        
        let validDays: [Date]
        if calendar.isDate(monthDate, equalTo: today, toGranularity: .month) {
            validDays = allDays.filter { $0 <= today }
        } else {
            validDays = allDays
        }
        
        let workdays = validDays.filter {
            let weekday = calendar.component(.weekday, from: $0)
            return (2...6).contains(weekday) // 2=Monday, 6=Friday
        }.count
        
        let standardHours = Double(workdays) * 8.0
        
        return standardHours > 0 ? totalHours / standardHours : 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(String(monthDate.yearInt))年\(String(monthDate.monthInt))月工时记录")
                    .font(.title3)
                    .fontWeight(.semibold)
//                Spacer()
//                Image(systemName: "chart.bar.fill")
//                    .foregroundStyle(.blue)
            }
            
            Divider()
            
            HStack() {
                VStack(alignment: .leading) {
                    Text("总工时")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f 小时", totalHours))
                        .font(.title3)
                        .fontWeight(.bold)
                }
                Spacer(minLength: 0)
                VStack(alignment: .leading) {
                    Text("工作天数")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(workDays) 天")
                        .font(.title3)
                        .fontWeight(.bold)
                }
                Spacer(minLength: 0)

                VStack(alignment: .leading) {
                    HStack(spacing: 4) {
                        Text("工时强度")
                            .font(.caption).foregroundStyle(.secondary)
                        Button {
                            showExplanation.toggle()
                        } label: {
                            Image(systemName: "questionmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .alert("工时强度计算说明", isPresented: $showExplanation) {
                            Button("确定", role: .cancel) { }
                        } message: {
                            Text("""
                            工时强度 = 当月总工时 ÷ 标准工时 × 100%
                            • 当月总工时：该月所有记录的工时长度。
                            • 标准工时：按工作日(未考虑节假日) × 8 小时计算。
                            • 超过 100% 表示工时超出标准。
                            """)
                        }
                    }
                    
                    Text(String(format: "%.0f%%", workHourRatio * 100))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(workHourRatio > 1 ? .orange : .blue)
                }
            }
            
            CustomProgressBar(ratio: workHourRatio)
                .frame(height: 10)
                .clipShape(Capsule())
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.clear)
                .glassEffect(in: .rect(cornerRadius: 20))
//                .fill(.ultraThinMaterial)
//                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
        )
        .padding(.horizontal, 10)
    }
}

struct CustomProgressBar: View {
    /// 实际占比（1 = 100%，支持到 4 = 400%）
    var ratio: Double
    /// 轨道颜色
    var track: Color = .gray.opacity(0.2)
    /// 分段颜色（顺序对应 0–100%、100–200%、…）
    var colors: [Color] = [.green, .blue, .orange, .red]
    /// 高度与圆角
    var height: CGFloat = 10
    var cornerRadius: CGFloat = 10
    /// 动画
    var animation: Animation = .easeOut(duration: 0.45)

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let clamped = max(0, min(ratio, Double(colors.count))) // 0...4

            ZStack(alignment: .leading) {
                // 轨道
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(track)

                // 叠加层：每段都从起点开始绘制，覆盖在前一段之上
                ForEach(colors.indices, id: \.self) { i in
                    // 第 i 段（0-based）的局部进度：0~1
                    // 例如 ratio = 2.5 → 第0段=1、第1段=1、第2段=0.5、其余=0
                    let segmentProgress = min(max(clamped - Double(i), 0), 1)
                    if segmentProgress > 0 {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(colors[i])
                            .frame(width: w * segmentProgress)
                            .animation(animation, value: segmentProgress)
                            .transition(.opacity)
                    }
                }
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .accessibilityLabel("工时强度")
        .accessibilityValue("\(Int(ratio * 100))%")
    }
}

fileprivate struct EditList: View {
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
        
        let days = Date.daysInMonth(year: year, month: month).reversed()
        let grouped = Dictionary(grouping: workLogs, by: { $0.startTime.startOfDay })
        
        let columns = Array(repeating: GridItem(.flexible()), count: 2)

        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {           // ← 行间距
                ForEach(days, id: \.self) { day in
                    let logs = (grouped[day] ?? []).sorted { $0.startTime < $1.startTime }

//                    VStack(alignment: .leading, spacing: 10) {   // ← 同一天内的卡片间距
                    if logs.isEmpty {
                        restCard(startTime: day)
                            .onTapGesture { modalType = .addLog(defaultDate: day) }
                    } else {
                        ForEach(logs) { log in
                            workLogCard(workLog: log)
                                .onTapGesture { modalType = .editLog(log) }
                        }
                    }
//                    }
//                    .padding(.horizontal, 0)
                }
            }
            .padding(.horizontal, 7)
        }
        .sheet(item: $modalType) { sheet in
            ModalSheetView(modal: sheet)
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

fileprivate struct restCard: View {
    
    private var startTime: Date
    private let cardCorner: CGFloat = 10

    
    init(startTime: Date) {
        self.startTime = startTime
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cardCorner)
//                .frame(width: width)
                .foregroundStyle(
                    LinearGradient(colors: [Color(red: 0.83, green: 0.92, blue: 0.90, opacity: 1.0),
                                            Color(red: 0.72, green: 0.83, blue: 0.80, opacity: 1.0)
                                             ]
                                   , startPoint: .topLeading
                                   , endPoint: .bottomTrailing
                      )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cardCorner)
                        .stroke(Color.white.opacity(0.8), lineWidth: 2)
                )
                .shadow(color: Color.black.opacity(0.18), radius: 4, x: 0, y: 2)
                .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 4)

            
            VStack{
                HStack {
                    Text(String(format: "%02d", startTime.dayInt))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(Color(red: 0.12, green: 0.13, blue: 0.13, opacity: 1.0))
                        .frame(width: 50)
                    
                    Spacer(minLength: 0)

                    Image(systemName: "cup.and.saucer.fill")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 8)
                        .background(Color(red: 0.92, green: 0.96, blue: 0.94, opacity: 1.0))
                        .foregroundStyle(Color(red: 0.35, green: 0.70, blue: 0.65, opacity: 1.0))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .glassEffect(in: .rect(cornerRadius: 8))
                }
                Spacer(minLength: 0)
                HStack {
                    Spacer(minLength: 0)
                    Text("今日休息")
                        .font(.callout)
                        .foregroundStyle(Color(red: 0.36, green: 0.38, blue: 0.37, opacity: 1.0))
                        .bold()
                }
            }
//            .frame(width: width)
            .padding(EdgeInsets(top: 10, leading: 15, bottom: 10, trailing: 15))
        }
        
        .contentShape(Rectangle())



    }
}

fileprivate struct workLogCard: View {
    private var workLog: WorkLogs

    private var startTime: Date
    private var endTime: Date
    
    private let cardCorner: CGFloat = 10
    
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
            RoundedRectangle(cornerRadius: cardCorner)
//                .frame(maxWidth: cardMaxWidth, maxHeight: .infinity)
                .foregroundStyle(
                    isOvernight
                    ? LinearGradient(
                        colors: [
                            Color(red: 0.52, green: 0.45, blue: 0.80, opacity: 1.0),
                            Color(red: 0.35, green: 0.28, blue: 0.65, opacity: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                      )
                    : LinearGradient(
                        colors: [
                            Color(red: 1.00, green: 0.93, blue: 0.75, opacity: 1.0),
                            Color(red: 1.00, green: 0.85, blue: 0.56, opacity: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                      )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cardCorner)
                        .stroke(Color.white.opacity(0.8), lineWidth: 2)
                )
                .shadow(color: Color.black.opacity(0.18), radius: 4, x: 0, y: 2)
                .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 4)
//                .glassEffect(in: .rect(cornerRadius: 17))
                
            VStack (alignment: .trailing) {
                HStack {
                    Text(String(format: "%02d", startTime.dayInt))
                        .frame(width: 50)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(isOvernight ? .white : Color(red: 0.12, green: 0.12, blue: 0.13, opacity: 1.0))
                    
                    Spacer(minLength: 0)
                    
                    if isOvernight {
                        Image(systemName: "moon.fill")
                            .font(.callout)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 4)
                            .foregroundStyle(.indigo)
                            .background(Color(red: 0.67, green: 0.61, blue: 0.86, opacity: 1.0))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .glassEffect(in: .rect(cornerRadius: 8))
                    } else {
                        Image(systemName: "sun.max.fill")
                            .font(.callout)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 4)
                            .background(Color(red: 1.00, green: 0.96, blue: 0.85, opacity: 1.0))
                            .foregroundStyle(Color(red: 1.00, green: 0.73, blue: 0.20, opacity: 1.0))
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
                            .foregroundStyle(isOvernight ? Color(red: 1.00, green: 0.62, blue: 0.04, opacity: 1.0) : Color(red: 0.00, green: 0.48, blue: 1.00, opacity: 1.0))
                    }
                    
                    HStack {
                        Spacer(minLength: 0)
                        Text("\(startTime, format: .dateTime.hour().minute()) ")
                            .font(.callout)
                            .foregroundStyle(isOvernight ? Color(red: 0.85, green: 0.85, blue: 0.90, opacity: 1.0): Color(red: 0.35, green: 0.33, blue: 0.30, opacity: 1.0))
                        Image(systemName: "chevron.right.dotted.chevron.right")
                            .frame(maxWidth: 1)
                            .offset(x: -1)
                            .font(.caption2)
                            .foregroundStyle(isOvernight ? Color(red: 0.85, green: 0.85, blue: 0.90, opacity: 1.0): Color(red: 0.35, green: 0.33, blue: 0.30, opacity: 1.0))
                        HStack (alignment: .center, spacing: 8) {
                            Text("\(endTime, format: .dateTime.hour().minute())")
                                .font(.callout)
                                .foregroundStyle(isOvernight ? Color(red: 0.85, green: 0.85, blue: 0.90, opacity: 1.0): Color(red: 0.35, green: 0.33, blue: 0.30, opacity: 1.0))
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
//            .frame(maxWidth: cardMaxWidth, maxHeight: .infinity)
            .padding(EdgeInsets(top: 10, leading: 15, bottom: 10, trailing: 15))
        }
        .contentShape(Rectangle())

    }
}

fileprivate struct MonthSection: View {
    let monthDate: Date
    let allLogs: [WorkLogs]
    var onTapLog: (WorkLogs) -> Void
    var onTapRestDay: (Date) -> Void
    
    private let cellHeight: CGFloat = 56

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                ForEach(weekdaySymbolsCn(), id: \.self) { w in
                    Text(w).font(.caption.bold()).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
//            .padding(.bottom, 7)

            let grid = Date.calendarGridDays(for: monthDate)
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(Array(grid.enumerated()), id: \.offset) { _, d in
                    if let day = d {
                        let logs = logs(startingOn: day)
                        DayCell(
                            day: day,
                            logsOfDay: logs,
                            isToday: Calendar.current.isDateInToday(day),
                            isFuture: day.startOfDay > Date().startOfDay,
                            onTapLog: {
                                if let first = logs.first { onTapLog(first) }
                            },
                            onTapRest: { onTapRestDay(day) }
                        )
                        .frame(height: cellHeight)
                    } else {
                        Color.clear.frame(height: cellHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }

    private func logs(startingOn day: Date) -> [WorkLogs] {
        let key = day.startOfDay
        return allLogs
            .filter { $0.startTime.startOfDay == key }
            .sorted { $0.startTime < $1.startTime }
    }

    private func weekdaySymbolsCn() -> [String] {
        let base = ["一","二","三","四","五","六","日"]
        let cal = Calendar.current
        let shift = (cal.firstWeekday == 1) ? 6 : cal.firstWeekday - 2
        return Array(base[shift...] + base[..<shift])
    }
}

fileprivate struct DayCell: View {
    let day: Date
    let logsOfDay: [WorkLogs]
    let isToday: Bool
    let isFuture: Bool
    var onTapLog: () -> Void
    var onTapRest: () -> Void
    

    private var hasWork: Bool { !logsOfDay.isEmpty }
    private var hasOvernight: Bool {
        logsOfDay.contains { !Calendar.current.isDate($0.startTime, inSameDayAs: $0.endTime) }
    }
    private var totalSeconds: TimeInterval {
        logsOfDay.reduce(0) { $0 + $1.endTime.timeIntervalSince($1.startTime) }
    }

    var body: some View {
        let (hh, mm) = hAndM(from: totalSeconds)

        ZStack {
            if isFuture {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(backgroundFill)
                    .frame(height: 50)
            }
            
            if isToday {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(backgroundFill)
                    .frame(height: 50)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.8), lineWidth: 2.5)
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: 4, x: 0, y: 2)
                    .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 4)
                    .overlay(
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                            .offset(x: 13, y: -13)
                    )
                    
            }
            
            if !isToday && !isFuture {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(backgroundFill)
                    .frame(height: 50)
//                    .glassEffect(in: .rect(cornerRadius: 12))
            }


            VStack(spacing: 3) {
                HStack(spacing: 6) {
                    Text(String(format: "%02d", day.dayInt))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(foregroundPrimary)
                    Spacer(minLength: 0)
                }

                HStack {
                    Spacer(minLength: 0)
                    if hasWork {
                        if isFuture {
                            let decimalHours = Double(hh) + Double(mm) / 60.0
                            let formatted = decimalHours.truncatingRemainder(dividingBy: 1) == 0
                                ? String(format: "%.0fh", decimalHours)
                                : String(format: "%.1fh", decimalHours)
                            Text(formatted)
                                .font(.caption2)
                                .lineLimit(1)
                                .foregroundStyle(Color(red: 0.36, green: 0.38, blue: 0.37, opacity: 1.0))
                        } else {
                            let decimalHours = Double(hh) + Double(mm) / 60.0
                            let formatted = decimalHours.truncatingRemainder(dividingBy: 1) == 0
                                ? String(format: "%.0fh", decimalHours)
                                : String(format: "%.1fh", decimalHours)
                            Text(formatted)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(foregroundAccent)
                        }

                    } else {
                        if isFuture {
                            Text("")
                                .font(.caption)
                                .foregroundStyle(foregroundAccent)
                        } else {
                            Text("休")
                                .font(.caption)
                                .foregroundStyle(foregroundAccent)
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            if hasWork {
                onTapLog()
            } else {
                onTapRest()   // ⬅️ 点击休息日 → 添加工时
            }
        }
    }

    // 颜色方案（与之前一致）
    private var backgroundFill: some ShapeStyle {
        if isFuture {
            return AnyShapeStyle(Color(red: 0.85, green: 0.85, blue: 0.90, opacity: 1.0))
        }
        if !hasWork {
            return AnyShapeStyle(LinearGradient(colors: [
                Color(red: 0.83, green: 0.92, blue: 0.90, opacity: 1.0),
                Color(red: 0.72, green: 0.83, blue: 0.80, opacity: 1.0)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing))
        }
        if hasOvernight {
            return AnyShapeStyle(LinearGradient(
                colors: [
                    Color(red: 0.52, green: 0.45, blue: 0.80, opacity: 1.0),
                    Color(red: 0.35, green: 0.28, blue: 0.65, opacity: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              ))
        } else {
            return AnyShapeStyle(LinearGradient(
                colors: [
                    Color(red: 1.00, green: 0.93, blue: 0.75, opacity: 1.0),
                    Color(red: 1.00, green: 0.85, blue: 0.56, opacity: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              ))
        }
    }
    private var foregroundPrimary: Color { hasWork ? (hasOvernight ? .white : Color(red: 0.12, green: 0.12, blue: 0.13, opacity: 1.0)) : Color(red: 0.12, green: 0.13, blue: 0.13, opacity: 1.0)
 }
    private var foregroundAccent: Color { hasWork ? (hasOvernight ? Color(red: 1.00, green: 0.62, blue: 0.04, opacity: 1.0) : Color(red: 0.00, green: 0.48, blue: 1.00, opacity: 1.0)) : Color(red: 0.36, green: 0.38, blue: 0.37, opacity: 1.0) }

    private func hAndM(from seconds: TimeInterval) -> (Int, Int) {
        let total = max(0, Int(seconds))
        return (total / 3600, (total % 3600) / 60)
    }
}

//#Preview {
//    CalendarCardTab()
//        .environment(\.locale, .init(identifier: "zh-Hans-CN"))
//        .modelContainer(PreviewData.container)
//
////        .modelContainer(for: PreviewListData.container, inMemory: true)
//}
//
#Preview {
    @Previewable @StateObject var userSettings = UserSettings()
    @Previewable @StateObject var store = ModelStore(cloudEnabled: false)

    NavigationStack {
        ContentView()
            .environmentObject(userSettings)
            .environmentObject(store)
            .preferredColorScheme(userSettings.theme.colorScheme)
            .environment(\.locale, .init(identifier: "zh-Hans-CN"))
    }
    .modelContainer(PreviewData.container)
}

