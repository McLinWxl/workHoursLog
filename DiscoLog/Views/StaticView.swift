//
//  StaticView.swift
//  DiscoLog
//

import SwiftUI
import SwiftData

// MARK: - Date Utilities
fileprivate extension Date {


    static func calendarGridDays(for monthDate: Date) -> [Date?] {
        let cal = Calendar.current
        let start = monthDate.startOfMonth
        let range = cal.range(of: .day, in: .month, for: start)!
        let firstWeekdayIndex = cal.component(.weekday, from: start) // 1..7
        let firstWeekday = cal.firstWeekday
        let leading = ((firstWeekdayIndex - firstWeekday) + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: leading)
        days += range.map { day -> Date? in
            cal.date(from: DateComponents(year: start.yearInt, month: start.monthInt, day: day))!
        }

        // 补齐到 35 或 42
        let base = 35
        if days.count > base {
            days += Array(repeating: nil, count: 42 - days.count)
        } else if days.count < base {
            days += Array(repeating: nil, count: base - days.count)
        }
        return days
    }
}

// MARK: - 主视图：年热力图（两行） + 月日历
struct StaticView: View {
    @Query(sort: [SortDescriptor(\WorkLogs.startTime, order: .forward)])
    private var allLogs: [WorkLogs]

    @State private var modalType: ModalType?
    @State private var selectedYear: Int = Date().yearInt
    @State private var selectedMonth: Int = Date().monthInt
    @State private var addDay: Date?  // 点击“休息日”时记录日期，用于唤起添加 Sheet

    var body: some View {
        let today = Date().startOfDay
        let firstMonth = allLogs.first?.startTime.startOfMonth ?? today.startOfMonth
        let monthOptions = Date.monthsAscending(from: firstMonth, to: today)
        let monthDate = Calendar.current.date(from: DateComponents(year: selectedYear, month: selectedMonth, day: 1)) ?? Date().startOfMonth
        
        
        let m0 = monthDate.startOfMonth
        let m1 = monthDate.startOfNextMonth
        let inMonth = allLogs.filter { $0.startTime >= m0 && $0.startTime < m1 }
        let totalSeconds = inMonth.reduce(0.0) { acc, log in
            acc + max(0, log.endTime.timeIntervalSince(log.startTime))
        }
        
        
        NavigationStack {
            ScrollView {
                VStack(spacing: 17) {
                    Divider()
                    
                    MonthSection(
                        monthDate: monthDate,
                        allLogs: allLogs,
                        onTapLog: { modalType = .editLog($0) },
                        onTapRestDay: { day in
                            addDay = day
                            modalType = .addLog(defaultDate: day)
                        }
                    )
                    
                    Divider()
                    
                    YearHeatmap2Rows(year: selectedYear, allLogs: allLogs)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
            }
            .navigationTitle("\(String(format: "当月总计工时：%.1f小时", totalSeconds/3600))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            selectedYear = Date().yearInt
                            selectedMonth = Date().monthInt
                        } label: {
                            Label("回到本月", systemImage: "arrow.uturn.left")
                        }

                        let grouped = Dictionary(grouping: monthOptions, by: { $0.yearInt })
                        ForEach(grouped.keys.sorted(by: >), id: \.self) { y in
                            Section("\(y)年") {
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
            .sheet(item: $modalType) { sheet in
                sheet
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }

    }
}

// MARK: - 年热力图（两行：1-6月，7-12月；不可交互；自适应宽度）
fileprivate struct YearHeatmap2Rows: View {
    let year: Int
    let allLogs: [WorkLogs]

    var body: some View {
        let screenWidth = UIScreen.main.bounds.width

        
        VStack(alignment: .leading, spacing: 10) {
            Text("\(String(year)) 年工时热力图")
                .font(.headline.bold())
                .foregroundStyle(.primary)

            
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.clear)
                    .frame(height: screenWidth / 1.8 + 15)
                    .glassEffect(in: .rect(cornerRadius: 12))
                
                VStack(spacing: 0) {
                    HalfYearHeatmap(year: year, halfIndex: 0, allLogs: allLogs) // 1–6 月
                    HalfYearHeatmap(year: year, halfIndex: 1, allLogs: allLogs) // 7–12 月
                }
                .offset(y: 20)
                .padding(.horizontal, 5)
//                .frame(height: screenWidth/2)
//                .glassEffect(in: .rect(cornerRadius: 12))
            }
        }
    }
}

/// 单个月份的小热力图（7 列对齐；高度随周数自适应）
fileprivate struct HalfYearHeatmap: View {
    let year: Int
    /// 0 表示 1–6 月；1 表示 7–12 月
    let halfIndex: Int
    let allLogs: [WorkLogs]

    private func halfRange(year: Int, halfIndex: Int) -> (start: Date, end: Date) {
        let cal = Calendar.current
        let startMonth = (halfIndex == 0) ? 1 : 7
        let endMonth = startMonth + 5

        let monthStart = cal.date(from: DateComponents(year: year, month: startMonth, day: 1))!
        let monthEndDay = cal.range(of: .day, in: .month,
                                    for: cal.date(from: DateComponents(year: year, month: endMonth, day: 1))!)!.upperBound - 1
        let monthEnd = cal.date(from: DateComponents(year: year, month: endMonth, day: monthEndDay))!

        // 对齐到周（firstWeekday）
        let firstW = cal.firstWeekday // 1..7
        let startWeekday = cal.component(.weekday, from: monthStart)
        let startOffset = (startWeekday - firstW + 7) % 7
        let alignedStart = cal.date(byAdding: .day, value: -startOffset, to: monthStart)!

        let endWeekday = cal.component(.weekday, from: monthEnd)
        let endOffset = (firstW + 6 - endWeekday + 7) % 7 // 补到该周最后一天
        let alignedEnd = cal.date(byAdding: .day, value: endOffset, to: monthEnd)! // 包含

        return (alignedStart.startOfDay, alignedEnd.startOfDay)
    }

    private func dailyTotalsOfYear(_ year: Int) -> ([Date: Double], Double) {
        let cal = Calendar.current
        let yStart = cal.date(from: DateComponents(year: year, month: 1, day: 1))!.startOfDay
        let yEnd   = cal.date(from: DateComponents(year: year, month: 12, day: 31))!.startOfDay
        let yearLogs = allLogs.filter {
            let d = $0.startTime.startOfDay
            return d >= yStart && d <= yEnd
        }
        var dict: [Date: Double] = [:]
        for l in yearLogs {
            let k = l.startTime.startOfDay
            dict[k, default: 0] += max(0, l.endTime.timeIntervalSince(l.startTime)) / 3600.0
        }
        let maxHours = max(1.0, dict.values.max() ?? 0)
        return (dict, maxHours)
    }

    /// 半年范围内（1–6 或 7–12）
    private func inThisHalf(_ date: Date) -> Bool {
        let m = date.monthInt
        return halfIndex == 0 ? (1...6).contains(m) : (7...12).contains(m)
    }

    /// 是否在这一列顶部显示月份标签：该列第一天属于本半年，且为该月的**前 7 日**（近似“本月首周”）
    private func shouldShowMonthLabel(_ firstDayOfColumn: Date) -> Bool {
        guard inThisHalf(firstDayOfColumn) else { return false }
        return firstDayOfColumn.dayInt <= 7
    }

    private func monthLabel(_ date: Date) -> String {
        String(format: "%d月", date.monthInt)
    }

    var body: some View {
        let (totals, _) = dailyTotalsOfYear(year)
        let (start, end) = halfRange(year: year, halfIndex: halfIndex)

        // 连续天（含 end）
        let days: [Date] = stride(from: start, through: end, by: 86_400).map { $0 }
        // 列数 = 周数
        let columns = Int(ceil(Double(days.count) / 7.0))

        GeometryReader { geo in
            let spacing: CGFloat = 3
            let totalSpacing = spacing * CGFloat(columns - 1)
            let cellSize = (geo.size.width - totalSpacing) / CGFloat(columns)
            let cellHeight = cellSize

            ZStack(alignment: .topLeading) {

                HStack(spacing: spacing) {
                    ForEach(0..<columns, id: \.self) { c in
                        VStack(spacing: spacing) {
                            ForEach(0..<7, id: \.self) { r in
                                let idx = c * 7 + r
                                if idx < days.count {
                                    let d = days[idx]
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(color(for: d, totals: totals))
                                        .frame(width: cellSize, height: cellHeight)
                                        
                                } else {
                                    Color.clear.frame(width: cellSize, height: cellHeight)
                                }
                            }
                        }
                    }
                }

                let cal = Calendar.current
                let monthsRange = (halfIndex == 0 ? 1...6 : 7...12)

                ForEach(Array(monthsRange), id: \.self) { m in
                    if let firstOfMonth = cal.date(from: DateComponents(year: year, month: m, day: 1)) {
                        // 与半年的对齐起点差几天
                        let dayOffset = max(0, cal.dateComponents([.day], from: start, to: firstOfMonth).day ?? 0)
                        let colIndex = dayOffset / 7  // 该月第一天落在第几列（按周）

                        if (cal.component(.day, from: firstOfMonth) <= 7) && colIndex < columns {
                            let x = CGFloat(colIndex) * (cellSize + spacing)

                            Text(String(format: "%d月", m))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .minimumScaleFactor(0.8)
                                .offset(x: x, y: -15) // 在整行坐标上定位
                        }
                    }
                }
            }
        }
//        .frame(height: 7 * 13)
    }

    private func color(for day: Date, totals: [Date: Double]) -> Color {
        if !inThisHalf(day) { return .clear }

        let hours = totals[day.startOfDay] ?? 0
        if hours <= 0.01 { return Color.gray.opacity(0.18) }

        let thresholds: [Double] = [
            0.5, 1, 1.5, 2, 3, 4, 5, 6,
            6.5, 7.0, 7.25, 7.5, 7.75,
            8.0, 8.25, 8.5, 8.75,
            9.0, 9.25, 9.5, 9.75,
            10, 11, 12, 14, 16, 20
        ]
        let opacities: [Double] = [
            0.06, 0.09, 0.12, 0.15, 0.20, 0.25, 0.30, 0.35,
            0.40, 0.45, 0.50, 0.54, 0.58,
            0.62, 0.66, 0.70, 0.74,
            0.78, 0.81, 0.84, 0.87,
            0.90, 0.92, 0.94, 0.96, 0.98, 0.99, 1.00
        ]
        let idx = thresholds.firstIndex(where: { hours <= $0 }) ?? (opacities.count - 1)
        return Color.orange.opacity(opacities[idx])
    }
}

// MARK: - 月份视图片段（未来日期置灰；点击休息日→添加）
fileprivate struct MonthSection: View {
    let monthDate: Date
    let allLogs: [WorkLogs]
    var onTapLog: (WorkLogs) -> Void
    var onTapRestDay: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            
            HStack {
                Text("\(String(monthDate.yearInt))年\(String(format: "%d", monthDate.monthInt))月工时")
                    .font(.headline.bold())
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
            }

            HStack {
                ForEach(weekdaySymbolsCn(), id: \.self) { w in
                    Text(w).font(.caption2.bold()).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .offset(y: 7)

            let grid = Date.calendarGridDays(for: monthDate)
            LazyVGrid(columns: columns, spacing: 6) {
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
                    } else {
                        Color.clear.frame(height: 58)
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

// MARK: - Preview
#Preview {
    NavigationStack {
        StaticView()
            .environment(\.locale, .init(identifier: "zh-Hans-CN"))
            .modelContainer(PreviewListData.container)
    }
}
