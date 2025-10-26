//
//  CalendarCardTab.swift (Refactored)
//  WorkSession
//
//

import SwiftUI
import SwiftData

// MARK: - Route model

struct YearMonth: Hashable, Codable, Identifiable {
    let year: Int
    let month: Int
    var id: String { "\(year)-\(month)" }
}

// MARK: - Main Tab

struct CalendarCardTab: View {
    // Keep a global ascending query; local views will filter/slice efficiently.
    @Query(sort: [SortDescriptor(\WorkLog.startTime, order: .forward)])
    private var allLogs: [WorkLog]

    @State private var year = Date().yearInt
    @State private var month = Date().monthInt
    @State private var modal: ModalType?
//    @State private var addDay: Date?

    @Environment(\.colorScheme) private var cs
    @EnvironmentObject var settings: UserSettings

    var body: some View {
        let today       = Date().startOfDay
        let firstMonth  = (allLogs.first?.startTime ?? today).startOfMonth
        let monthItems  = Date.monthsAscending(from: firstMonth, to: today)
        let currentYM   = DateComponents(calendar: .current, year: year, month: month).date?.startOfMonth ?? today.startOfMonth
        let monthLogs   = logs(in: currentYM, from: allLogs)

        NavigationStack {
            
            ScrollView {
                MonthSection(
                    monthDate: currentYM,
                    allLogs: allLogs, // MonthSection does its own per-day slicing
                    onTapLog: { modal = .editLog($0) },
                    onTapRestDay: { day in
//                        addDay = day
                        modal  = .addLog(defaultDate: day)
                    }
                )
                .padding(.horizontal, 7)

                .padding(.vertical, 12)
                
                Divider()
                
                Group {
                    SummaryCard(monthDate: currentYM, monthLogs: monthLogs)
                        .navigationTitle("工时记录")
                        .navigationBarTitleDisplayMode(.inline)



                    MonthlyEarningsCard(
                        monthDate: currentYM,
                        logs: monthLogs, // intersect month
                        defaultPayroll: settings.defaultPayroll
                    )
                }
                .padding(.horizontal, 7)

            }
            .safeAreaInset(edge: .bottom, content: {
                HStack {
                    Button {
                        shiftMonth(by: -1)
                    } label: {
                        Text("\(Image(systemName: "arrowtriangle.backward.fill")) \(prevMonthLabel())月")
                            .foregroundStyle(cs == .dark ? .white : .black)
                            .font(.callout)
                            .padding()
                    }
                    .glassEffect()
                    .padding()

                    Spacer(minLength: 0)

                    NavigationLink(value: YearMonth(year: year, month: month)) {
                        Text("详细记录")
                            .foregroundStyle(.white)
                            .font(.callout.bold())
                            .padding()
                            .glassEffect(.regular.tint(.orange.opacity(0.9)).interactive())
                    }
                    .navigationDestination(for: YearMonth.self) { target in
                        EditList(year: target.year, month: target.month, onRequestNewLog: {
                            modal = .addLog(defaultDate: Date())
                        })
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                MonthPickerMenu(
                                    selectedYear: $year,
                                    selectedMonth: $month,
                                    options: monthItems
                                )
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                Button { modal = .addLog(defaultDate: Date()) } label: {
                                    Label("添加", systemImage: "square.and.pencil")
                                }
                            }
                        }
                    }

                    Spacer(minLength: 0)

                    Button {
                        shiftMonth(by: 1)
                    } label: {
                        Text("\(nextMonthLabel())月 \(Image(systemName: "arrowtriangle.forward.fill"))")
                            .foregroundStyle(cs == .dark ? .white : .black)
                            .font(.callout)
                            .padding()
                    }
                    .glassEffect()
                    .padding()

                }
            })
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonthPickerMenu(
                        selectedYear: $year,
                        selectedMonth: $month,
                        options: monthItems
                    )
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { modal = .addLog(defaultDate: Date()) } label: {
                        Label("添加", systemImage: "square.and.pencil")
                    }
                }
            }
            .safeSheet(item: $modal) { sheet in
                ModalSheetView(modal: sheet)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }

            // Bottom nav row
            
        }
    }

    // MARK: - Local helpers

    /// Slice logs that intersect the month [startOfMonth, startOfNextMonth).
    private func logs(in month: Date, from all: [WorkLog]) -> [WorkLog] {
        let m0 = month.startOfMonth
        let m1 = month.startOfNextMonth
        return all.filter { $0.startTime < m1 && $0.endTime > m0 }
    }

    private func shiftMonth(by delta: Int) {
        if let d = Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)),
           let new = Calendar.current.date(byAdding: .month, value: delta, to: d) {
            year  = new.yearInt
            month = new.monthInt
        }
    }

    private func prevMonthLabel() -> String {
        if let d = Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)),
           let p = Calendar.current.date(byAdding: .month, value: -1, to: d) {
            return String(p.monthInt)
        }
        return String(max(1, month - 1))
    }

    private func nextMonthLabel() -> String {
        if let d = Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)),
           let n = Calendar.current.date(byAdding: .month, value: 1, to: d) {
            return String(n.monthInt)
        }
        return String(min(12, month + 1))
    }
}

// MARK: - Month Picker (reused in two toolbars)

fileprivate struct MonthPickerMenu: View {
    @Binding var selectedYear: Int
    @Binding var selectedMonth: Int
    let options: [Date] // months ascending

    var body: some View {
        Menu {
            Button {
                let now = Date()
                selectedYear  = now.yearInt
                selectedMonth = now.monthInt
            } label: {
                Label("回到本月", systemImage: "arrow.uturn.left")
            }

            let grouped = Dictionary(grouping: options, by: { $0.yearInt })
            ForEach(grouped.keys.sorted(by: >), id: \.self) { y in
                Section("\(y)年") {
                    ForEach(grouped[y]!.sorted(by: { $0.monthInt > $1.monthInt }), id: \.self) { m in
                        Button {
                            selectedYear  = m.yearInt
                            selectedMonth = m.monthInt
                        } label: {
                            HStack {
                                Text(String(format: "%02d 月", m.monthInt))
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
}

// MARK: - Summary Card

struct MonthlyEarningsCard: View {
    let monthDate: Date
    let logs: [WorkLog]
    var defaultPayroll: PayrollConfig?

    private let calc = MonthlyEarningsCalculator()

    // @State private var summary: MonthlyEarningsSummary?

    private var summary: MonthlyEarningsSummary? {
        let s = calc.summarize(logs: logs, monthAnchor: monthDate, defaultPayroll: defaultPayroll)
        return (s.hours.totalHours() > 0 || s.amountTotal > 0) ? s : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(String(monthDate.yearInt))年\(monthDate.monthInt)月收入统计")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                if let s = summary {
                    Text(s.amountTotal, format: .currency(code: "CNY"))
                        .font(.title3).bold()
                        .foregroundStyle(.orange)
                }
            }

            Divider()

            if let s = summary {
                Grid(horizontalSpacing: 12, verticalSpacing: 8) {
                    row("正班收入",          hours: s.hours.regular,   amount: s.amountRegular)
                    row("工作日加班",     hours: s.hours.workdayOT, amount: s.amountWorkdayOT)
                    row("休息日加班",    hours: s.hours.restDayOT, amount: s.amountRestDayOT)
                    row("节假日加班",     hours: s.hours.holidayOT, amount: s.amountHolidayOT)
                }
                if s.hasUnassignedButNoDefault {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text("存在暂未设置项目的工时，请设置默认计薪策略，并保存（若需使用默认策略，也请点击保存）。")
                        Spacer()
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            } else {
                Text("本月暂无记录或暂未设置所属项目")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.clear)
                .glassEffect(in: .rect(cornerRadius: 20))
        )
    }
    private func row(_ title: String, hours: Double, amount: Decimal) -> some View {
        GridRow {
            Text(title).gridColumnAlignment(.leading)
            Spacer(minLength: 0)
            Text(String(format: "%.1f 小时", hours))
                .padding(.horizontal)
                .gridColumnAlignment(.leading)
            Text(amount, format: .currency(code: "CNY")).fontWeight(.semibold)
                .gridColumnAlignment(.leading)
        }
    }

    private func currency(_ v: Double) -> String {
        String(format: "¥%.2f", v)
    }
}

struct SummaryCard: View {
    let monthDate: Date
    let monthLogs: [WorkLog]
    @State private var showExplanation = false

    private var totalHours: Double {
        monthLogs.reduce(0) { $0 + $1.duration / 3600 }
    }

    private var workDaysCount: Int {
        Set(monthLogs.map { $0.startTime.startOfDay }).count
    }

    /// Work intensity = totalHours / (workdays(weekdays) * 8h)
    private var workHourRatio: Double {
        let cal = Calendar.current
        let today = Date()
        guard let range = cal.range(of: .day, in: .month, for: monthDate) else { return 0 }

        let allDays: [Date] = range.compactMap { day -> Date? in
            cal.date(from: DateComponents(year: monthDate.yearInt, month: monthDate.monthInt, day: day))
        }

        let validDays: [Date] = cal.isDate(monthDate, equalTo: today, toGranularity: .month)
        ? allDays.filter { $0 <= today }
        : allDays

        let workdays = validDays.filter { cal.isWeekday($0) }.count
        let standardHours = Double(workdays) * 8.0
        return standardHours > 0 ? totalHours / standardHours : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(String(monthDate.yearInt))年\(monthDate.monthInt)月工时记录")
                    .font(.title3)
                    .fontWeight(.semibold)
            }

            Divider()

            HStack {
                StatBlock(title: "总工时", value: String(format: "%.1f 小时", totalHours))
                Spacer(minLength: 0)
                StatBlock(title: "工作天数", value: "\(workDaysCount) 天")
                Spacer(minLength: 0)
                VStack(alignment: .leading) {
                    HStack(spacing: 4) {
                        Text("工时强度").font(.caption).foregroundStyle(.secondary)
                        Button { showExplanation.toggle() } label: {
                            Image(systemName: "questionmark.circle.fill")
                                .font(.caption).foregroundStyle(.secondary)
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
                        .font(.title3).fontWeight(.bold)
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
        )
    }

    private struct StatBlock: View {
        let title: String
        let value: String
        var body: some View {
            VStack(alignment: .leading) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.title3).fontWeight(.bold)
            }
        }
    }
}

// MARK: - Month Section

fileprivate struct MonthSection: View {
    let monthDate: Date
    let allLogs: [WorkLog]
    var onTapLog: (WorkLog) -> Void
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

            let grid = Date.calendarGridDays(for: monthDate)
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(Array(grid.enumerated()), id: \.offset) { _, cell in
                    if let day = cell {
                        let logs = logs(startingOn: day)
                        DayCell(
                            day: day,
                            logsOfDay: logs,
                            isToday: Calendar.current.isDateInToday(day),
                            isFuture: day.startOfDay > Date().startOfDay,
                            onTapLog: { if let first = logs.first { onTapLog(first) } },
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

    private func logs(startingOn day: Date) -> [WorkLog] {
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

// MARK: - Day Cell

fileprivate struct DayCell: View {
    let day: Date
    let logsOfDay: [WorkLog]
    let isToday: Bool
    let isFuture: Bool
    var onTapLog: () -> Void
    var onTapRest: () -> Void
    @Environment(\.colorScheme) private var systemScheme


    private var hasWork: Bool { !logsOfDay.isEmpty }
    private var hasOvernight: Bool { logsOfDay.contains { $0.isOvernight } }
    private var totalSeconds: TimeInterval { logsOfDay.reduce(0) { $0 + $1.duration } }

    var body: some View {
        let (hh, mm) = secondsToHM(totalSeconds)

        ZStack {
            if isFuture {
                RoundedRectangle(cornerRadius: 12)
                    .fill(systemScheme == .dark ?
                          Color(red: 0.32, green: 0.35, blue: 0.39, opacity: 1.0):
                            Color(red: 0.90, green: 0.91, blue: 0.93, opacity: 1.0)).frame(height: 50)
            }

            if isToday {
                RoundedRectangle(cornerRadius: 12)
                    .fill(backgroundFill)
                    .frame(height: 50)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.8), lineWidth: 2.5))
                    .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)
                    .shadow(color: .black.opacity(0.10), radius: 10, x: 0, y: 4)
                    .overlay(Circle().fill(Color.orange).frame(width: 8, height: 8).offset(x: 13, y: -13))
            }

            if !isToday && !isFuture {
                RoundedRectangle(cornerRadius: 12).fill(backgroundFill).frame(height: 50)
            }

            VStack(spacing: 3) {
                HStack(spacing: 6) {
                    Text(String(format: "%02d", day.dayInt))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(primaryText)
                    Spacer(minLength: 0)
                }

                HStack {
                    Spacer(minLength: 0)
                    if hasWork {
                        let decimal = Double(hh) + Double(mm) / 60.0
                        let formatted = decimal.truncatingRemainder(dividingBy: 1) == 0
                        ? String(format: "%.0fh", decimal)
                        : String(format: "%.1fh", decimal)
                        Text(formatted)
                            .font(.caption.weight(isFuture ? .regular : .semibold))
                            .foregroundStyle(accentText)
                    } else {
                        if isFuture {
                            Text("").font(.caption)
                        } else {
                            Text("休").font(.caption).foregroundStyle(accentText)
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture { hasWork ? onTapLog() : onTapRest() }
    }

    // Colors
    private var backgroundFill: some ShapeStyle {
        if !hasWork {
            return AnyShapeStyle(LinearGradient(colors: [
                Color(red: 0.83, green: 0.92, blue: 0.90, opacity: 1.0),
                Color(red: 0.72, green: 0.83, blue: 0.80, opacity: 1.0)
            ], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        if hasOvernight {
            return AnyShapeStyle(LinearGradient(colors: [
                Color(red: 0.52, green: 0.45, blue: 0.80, opacity: 1.0),
                Color(red: 0.35, green: 0.28, blue: 0.65, opacity: 1.0)
            ], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        return AnyShapeStyle(LinearGradient(colors: [
            Color(red: 1.00, green: 0.93, blue: 0.75, opacity: 1.0),
            Color(red: 1.00, green: 0.85, blue: 0.56, opacity: 1.0)
        ], startPoint: .topLeading, endPoint: .bottomTrailing))
    }

    private var primaryText: Color {
        guard hasWork else { return Color(red: 0.12, green: 0.13, blue: 0.13, opacity: 1.0) }
        return hasOvernight ? .white : Color(red: 0.12, green: 0.12, blue: 0.13, opacity: 1.0)
    }

    private var accentText: Color {
        guard hasWork else { return Color(red: 0.36, green: 0.38, blue: 0.37, opacity: 1.0) }
        return hasOvernight
        ? Color(red: 1.00, green: 0.62, blue: 0.04, opacity: 1.0)
        : Color(red: 0.00, green: 0.48, blue: 1.00, opacity: 1.0)
    }

    private func secondsToHM(_ s: TimeInterval) -> (Int, Int) {
        let total = max(0, Int(s))
        return (total / 3600, (total % 3600) / 60)
    }
}

// MARK: - Cards

fileprivate struct RestCard: View {
    private let startTime: Date
    private let cardCorner: CGFloat = 10

    init(startTime: Date) { self.startTime = startTime }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cardCorner)
                .foregroundStyle(LinearGradient(colors: [
                    Color(red: 0.83, green: 0.92, blue: 0.90, opacity: 1.0),
                    Color(red: 0.72, green: 0.83, blue: 0.80, opacity: 1.0)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: cardCorner).stroke(Color.white.opacity(0.8), lineWidth: 2))
                .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)
                .shadow(color: .black.opacity(0.10), radius: 10, x: 0, y: 4)

            VStack {
                HStack {
                    Text(String(format: "%02d", startTime.dayInt))
                        .font(.largeTitle).fontWeight(.bold)
                        .foregroundStyle(Color(red: 0.12, green: 0.13, blue: 0.13, opacity: 1.0))
                        .frame(width: 50)
                    Spacer(minLength: 0)
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.caption).fontWeight(.semibold)
                        .padding(.horizontal, 6).padding(.vertical, 8)
                        .background(Color(red: 0.92, green: 0.96, blue: 0.94, opacity: 1.0))
                        .foregroundStyle(Color(red: 0.35, green: 0.70, blue: 0.65, opacity: 1.0))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .glassEffect(in: .rect(cornerRadius: 8))
                }
                Spacer(minLength: 0)
                HStack {
                    Spacer(minLength: 0)
                    Text("今日休息").font(.callout).bold()
                        .foregroundStyle(Color(red: 0.36, green: 0.38, blue: 0.37, opacity: 1.0))
                }
            }
            .padding(EdgeInsets(top: 10, leading: 15, bottom: 10, trailing: 15))
        }
        .contentShape(Rectangle())
    }
}

fileprivate struct WorkLogCard: View {
    private let log: WorkLog
    private let cardCorner: CGFloat = 10

    init(log: WorkLog) { self.log = log }

    private var isOvernight: Bool { log.isOvernight }
    private var startTime: Date { log.startTime }
    private var endTime: Date { log.endTime }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cardCorner)
                .foregroundStyle(
                    isOvernight
                    ? LinearGradient(colors: [
                        Color(red: 0.52, green: 0.45, blue: 0.80, opacity: 1.0),
                        Color(red: 0.35, green: 0.28, blue: 0.65, opacity: 1.0)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [
                        Color(red: 1.00, green: 0.93, blue: 0.75, opacity: 1.0),
                        Color(red: 1.00, green: 0.85, blue: 0.56, opacity: 1.0)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .overlay(RoundedRectangle(cornerRadius: cardCorner).stroke(Color.white.opacity(0.8), lineWidth: 2))
                .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)
                .shadow(color: .black.opacity(0.10), radius: 10, x: 0, y: 4)

            VStack (alignment: .trailing) {
                HStack {
                    Text(String(format: "%02d", startTime.dayInt))
                        .frame(width: 50)
                        .font(.largeTitle).fontWeight(.bold)
                        .foregroundStyle(isOvernight ? .white : Color(red: 0.12, green: 0.12, blue: 0.13, opacity: 1.0))
                    Spacer(minLength: 0)
                    if isOvernight {
                        Badge(icon: "moon.fill",
                              fg: .indigo,
                              bg: Color(red: 0.67, green: 0.61, blue: 0.86, opacity: 1.0))
                    } else {
                        Badge(icon: "sun.max.fill",
                              fg: Color(red: 1.00, green: 0.73, blue: 0.20, opacity: 1.0),
                              bg: Color(red: 1.00, green: 0.96, blue: 0.85, opacity: 1.0))
                    }
                }

                VStack(alignment: .trailing, spacing: 7) {
                    Spacer(minLength: 0)
                    let hm = durationHM(log.duration)
                    HStack {
                        Text(" \(hm.h) 小时 \(hm.m) 分钟 ")
                            .font(.headline).fontWeight(.bold)
                            .foregroundStyle(isOvernight
                                             ? Color(red: 1.00, green: 0.62, blue: 0.04, opacity: 1.0)
                                             : Color(red: 0.00, green: 0.48, blue: 1.00, opacity: 1.0))
                    }
                    HStack {
                        Spacer(minLength: 0)
                        Text(startTime, format: .dateTime.hour().minute())
                            .font(.callout)
                            .foregroundStyle(isOvernight ? Color(white: 0.88) : Color(red: 0.35, green: 0.33, blue: 0.30, opacity: 1.0))
                        Image(systemName: "chevron.right.dotted.chevron.right")
                            .font(.caption2)
                            .foregroundStyle(isOvernight ? Color(white: 0.88) : Color(red: 0.35, green: 0.33, blue: 0.30, opacity: 1.0))
                            .frame(maxWidth: 1).offset(x: -1)
                        HStack (alignment: .center, spacing: 8) {
                            Text(endTime, format: .dateTime.hour().minute())
                                .font(.callout)
                                .foregroundStyle(isOvernight ? Color(white: 0.88) : Color(red: 0.35, green: 0.33, blue: 0.30, opacity: 1.0))
                            if isOvernight {
                                Text("次")
                                    .font(.caption).fontWeight(.semibold)
                                    .padding(.horizontal, 3).padding(.vertical, 2)
                                    .background(Color.indigo.opacity(0.99))
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .padding(EdgeInsets(top: 10, leading: 15, bottom: 10, trailing: 15))
        }
        .contentShape(Rectangle())
    }

    private struct Badge: View {
        let icon: String; let fg: Color; let bg: Color
        var body: some View {
            Image(systemName: icon)
                .font(.callout)
                .padding(.horizontal, 4).padding(.vertical, 4)
                .foregroundStyle(fg)
                .background(bg)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .glassEffect(in: .rect(cornerRadius: 8))
        }
    }

    private func durationHM(_ seconds: TimeInterval) -> (h: Int, m: Int) {
        let total = max(0, Int(seconds))
        return (total / 3600, (total % 3600) / 60)
    }
}

// MARK: - Edit List (month detail)

fileprivate struct EditList: View {
    let year: Int
    let month: Int
    var onRequestNewLog: () -> Void

    @State private var modal: ModalType?
    @Query private var workLogs: [WorkLog]

    init(year: Int, month: Int, onRequestNewLog: @escaping () -> Void) {
        self.year = year
        self.month = month
        self.onRequestNewLog = onRequestNewLog

        let (m0, m1) = Self.monthBounds(year: year, month: month)
        let predicate = #Predicate<WorkLog> { log in
            log.startTime < m1 && log.endTime > m0
        }
        _workLogs = Query(filter: predicate, sort: [SortDescriptor(\WorkLog.startTime, order: .reverse)])
    }

    var body: some View {
        let days = Date.daysInMonth(year: year, month: month).reversed()
        let grouped = Dictionary(grouping: workLogs, by: { $0.startTime.startOfDay })
        let columns = Array(repeating: GridItem(.flexible()), count: 2)

        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(days, id: \.self) { day in
                    let logs = (grouped[day] ?? []).sorted { $0.startTime < $1.startTime }
                    if logs.isEmpty {
                        RestCard(startTime: day)
                            .onTapGesture { modal = .addLog(defaultDate: day) }
                    } else {
                        ForEach(logs) { log in
                            WorkLogCard(log: log)
                                .onTapGesture { modal = .editLog(log) }
                        }
                    }
                }
            }
            .padding(.horizontal, 7)
        }
        .safeSheet(item: $modal) { sheet in
            ModalSheetView(modal: sheet)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            // optional hook to expose "add" from toolbar in parent
        }
    }

    private static func monthBounds(year: Int, month: Int) -> (Date, Date) {
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date().startOfMonth
        let next  = cal.date(byAdding: .month, value: 1, to: start) ?? start.startOfNextMonth
        return (start, next)
    }
}

// MARK: - Progress Bar (kept)

struct CustomProgressBar: View {
    var ratio: Double
    var track: Color = .gray.opacity(0.2)
    var colors: [Color] = [.green, .blue, .orange, .red]
    var height: CGFloat = 10
    var cornerRadius: CGFloat = 10
    var animation: Animation = .easeOut(duration: 0.45)

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let clamped = max(0, min(ratio, Double(colors.count)))

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: cornerRadius).fill(track)
                ForEach(colors.indices, id: \.self) { i in
                    let progress = min(max(clamped - Double(i), 0), 1)
                    if progress > 0 {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(colors[i])
                            .frame(width: w * progress)
                            .animation(animation, value: progress)
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

// MARK: - Preview

//#Preview {
//    @Previewable @StateObject var userSettings = UserSettings()
//    @Previewable var previewContainer = PreviewSeed.container() // in-memory SwiftData
//    @Previewable var store = try? ModelStore(cloudEnabled: false)
//
//    NavigationStack {
//        CalendarCardTab()
//            .environmentObject(userSettings)
//            .preferredColorScheme(userSettings.theme.colorScheme)
//            .environment(\.locale, .init(identifier: "zh-Hans-CN"))
//    }
//    .modelContainer(previewContainer)
//}
#Preview {
    @Previewable @StateObject var userSettings = UserSettings()
    @Previewable var previewContainer = PreviewSeed.container()
    @Previewable var store = try? ModelStore(cloudEnabled: false)

    NavigationStack {
        ContentView()
            .environmentObject(userSettings)
//            .preferredColorScheme(userSettings.theme.colorScheme)
            .environment(\.locale, .init(identifier: "zh-Hans-CN"))
    }
    .modelContainer(previewContainer)
}


// MARK: - Local Utilities (scoped to this file)

fileprivate extension View {
    /// Single sheet attachment to avoid duplications.
    func safeSheet<Item: Identifiable>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> some View
    ) -> some View {
        self.sheet(item: item) { content($0) }
    }
}

fileprivate extension Calendar {
    func isWeekday(_ date: Date) -> Bool {
        let w = component(.weekday, from: date)
        // 2...6 == Monday...Friday in gregorian (1 is Sunday)
        return (2...6).contains(w)
    }
}

//fileprivate extension Date {
//    var yearInt: Int { Calendar.current.component(.year, from: self) }
//    var monthInt: Int { Calendar.current.component(.month, from: self) }
//    var dayInt: Int { Calendar.current.component(.day, from: self) }
//    var startOfDay: Date { Calendar.current.startOfDay(for: self) }
//    var startOfMonth: Date {
//        let cal = Calendar.current
//        let comps = cal.dateComponents([.year, .month], from: self)
//        return cal.date(from: comps) ?? self
//    }
//    var startOfNextMonth: Date {
//        Calendar.current.date(byAdding: .month, value: 1, to: startOfMonth) ?? self
//    }
//
//    /// Asc list of month anchors inclusive.
//    static func monthsAscending(from start: Date, to end: Date) -> [Date] {
//        let cal = Calendar.current
//        var out: [Date] = []
//        var cur = start.startOfMonth
//        let limit = end.startOfMonth
//        while cur <= limit {
//            out.append(cur)
//            cur = cal.date(byAdding: .month, value: 1, to: cur) ?? limit.addingTimeInterval(1)
//        }
//        return out
//    }
//
//    /// 7xN calendar grid for the month; `nil` pads the first row.
//    static func calendarGridDays(for month: Date) -> [Date?] {
//        let cal = Calendar.current
//        let start = month.startOfMonth
//        let range = cal.range(of: .day, in: .month, for: start) ?? 1...30
//        let firstWeekday = cal.component(.weekday, from: start) // 1=Sun
//        let leading = (firstWeekday + 5) % 7 // target Mon=0...Sun=6
//
//        var grid: [Date?] = Array(repeating: nil, count: leading)
//        for day in range {
//            let d = cal.date(byAdding: .day, value: day - 1, to: start) ?? start
//            grid.append(d)
//        }
//        // pad tail to multiple of 7 (optional; visual consistency)
//        while grid.count % 7 != 0 { grid.append(nil) }
//        return grid
//    }
//
//    /// All day anchors of a month.
//    static func daysInMonth(year: Int, month: Int) -> [Date] {
//        let cal = Calendar.current
//        let start = cal.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
//        let range = cal.range(of: .day, in: .month, for: start) ?? 1...30
//        return range.compactMap { day in
//            cal.date(from: DateComponents(year: year, month: month, day: day))
//        }
//    }
//}

