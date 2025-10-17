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
        let range = cal.range(of: .day, in: .month, for: start)! // 1...28/29/30/31

        let firstWeekdayIndex = cal.component(.weekday, from: start) // 1..7
        let firstWeekday = cal.firstWeekday                           // 地区相关
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

    /// 从某月份（含）到当前月份（含），按月正序（便于 Picker 显示）
    static func monthsAscending(from firstMonth: Date, to lastMonth: Date) -> [Date] {
        var arr: [Date] = []
        var cursor = firstMonth.startOfMonth
        let end = lastMonth.startOfMonth
        while cursor <= end {
            arr.append(cursor)
            cursor = Calendar.current.date(byAdding: .month, value: 1, to: cursor)!
        }
        return arr
    }
}

// MARK: - StaticView
struct StaticView: View {
    @Query(sort: [SortDescriptor(\WorkLogs.startTime, order: .forward)])
    private var allLogs: [WorkLogs]

    @State private var modalType: ModalType?
    @State private var selectedMonth: Date = Date().startOfMonth   // ⬅️ 选择的月份

    var body: some View {
        let today = Date().startOfDay
        let firstMonth = allLogs.first?.startTime.startOfMonth ?? today.startOfMonth
        let monthOptions = Date.monthsAscending(from: firstMonth, to: today) // 供选择的所有月份

        ScrollView {
            LazyVStack(spacing: 20) {
                MonthSection(monthDate: selectedMonth, allLogs: allLogs) { tappedLog in
                    modalType = .editLog(tappedLog)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
        }
        .navigationTitle("\(selectedMonth.yearInt)年\(String(format: "%02d", selectedMonth.monthInt))月")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    // 年份分组可读性更好（可选）
                    let grouped = Dictionary(grouping: monthOptions, by: { $0.yearInt })
                    // 倒序年份，让最近的在上
                    ForEach(grouped.keys.sorted(by: >), id: \.self) { y in
                        Section("\(y)年") {
                            ForEach(grouped[y]!.sorted(by: { $0.monthInt > $1.monthInt }), id: \.self) { m in
                                Button {
                                    withAnimation(.snappy) { selectedMonth = m }
                                } label: {
                                    HStack {
                                        Text("\(String(format: "%02d", m.monthInt)) 月")
                                        if m.startOfMonth == selectedMonth.startOfMonth {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    Label("选择月份", systemImage: "calendar")
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

// MARK: - Month Section
fileprivate struct MonthSection: View {
    let monthDate: Date
    let allLogs: [WorkLogs]
    var onTapLog: (WorkLogs) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 星期标题：中文“一二三四五六日”，按 firstWeekday 旋转
            HStack {
                ForEach(weekdaySymbolsCn(), id: \.self) { w in
                    Text(w)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 4)

            // 日历网格
            let grid = Date.calendarGridDays(for: monthDate)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(grid.enumerated()), id: \.offset) { _, d in
                    if let day = d {
                        DayCell(day: day,
                                logsOfDay: logs(startingOn: day),
                                onTapLog: onTapLog)
                    } else {
                        Color.clear.frame(height: 58)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }

    /// 当天（以开始时间归属）对应的所有记录
    private func logs(startingOn day: Date) -> [WorkLogs] {
        let dayStart = day.startOfDay
        return allLogs
            .filter { $0.startTime.startOfDay == dayStart }
            .sorted { $0.startTime < $1.startTime }
    }

    /// 中文星期标题：“一二三四五六日”，并根据 firstWeekday 旋转
    private func weekdaySymbolsCn() -> [String] {
        let base = ["一","二","三","四","五","六","日"]  // 周一开头
        let cal = Calendar.current
        // 将系统 firstWeekday(1=周日) 映射到以周一为 0 的偏移
        // 当 firstWeekday = 2(周一) → shift = 0；=1(周日) → shift = 6（把“日”移到最后）
        let shift: Int = {
            let fw = cal.firstWeekday // 1..7, 1=周日
            return (fw == 1) ? 6 : fw - 2
        }()
        let rotated = Array(base[shift...] + base[..<shift])
        return rotated
    }
}

// MARK: - Day Cell（保持你之前的配色与逻辑）
fileprivate struct DayCell: View {
    let day: Date
    let logsOfDay: [WorkLogs]
    var onTapLog: (WorkLogs) -> Void

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
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(backgroundFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 12).stroke(borderColor.opacity(0.15))
                )
                .frame(height: 58)

            VStack(spacing: 2) {
                HStack(spacing: 6) {
                    Text(String(format: "%02d", day.dayInt))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(foregroundPrimary)

                    if hasOvernight {
                        Image(systemName: "moon.stars.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                    Spacer(minLength: 0)
                }

                HStack(spacing: 4) {
                    if hasWork {
                        Text("\(hh)小时\(mm)分")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(foregroundAccent)
                    } else {
                        Text("休息")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 8)
        }
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            if let first = logsOfDay.first { onTapLog(first) }
        }
    }

    private var backgroundFill: some ShapeStyle {
        if !hasWork {
            return AnyShapeStyle(.thinMaterial)
        }
        if hasOvernight {
            return AnyShapeStyle(LinearGradient(
                colors: [Color.indigo.opacity(0.55), Color.purple.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        } else {
            return AnyShapeStyle(LinearGradient(
                colors: [Color.mint.opacity(0.35), Color.green.opacity(0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        }
    }
    private var borderColor: Color { hasWork ? (hasOvernight ? .purple : .green) : .gray }
    private var foregroundPrimary: Color { hasWork ? (hasOvernight ? .white : .primary) : .primary }
    private var foregroundAccent: Color { hasWork ? (hasOvernight ? .white.opacity(0.95) : .green) : .secondary }

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
