//
//  StaticView.swift
//  DiscoLog
//

import SwiftUI
import SwiftData

// MARK: - 主视图：年热力图（两行） + 月日历
struct StaticView: View {
    @Query(sort: [SortDescriptor(\WorkLogs.startTime, order: .forward)])
    private var allLogs: [WorkLogs]

    @State private var modalType: ModalType?
    @State private var selectedYear: Int = Date().yearInt
    @State private var selectedMonth: Int = Date().monthInt
    @State private var addDay: Date?  // 点击“休息日”时记录日期，用于唤起添加 Sheet
    @Environment(\.colorScheme) private var colorScheme


    var body: some View {
//        let today = Date().startOfDay
//        let firstMonth = allLogs.first?.startTime.startOfMonth ?? today.startOfMonth
//        let monthOptions = Date.monthsAscending(from: firstMonth, to: today)
        let monthDate = Calendar.current.date(from: DateComponents(year: selectedYear, month: 1, day: 1)) ?? Date().startOfMonth
        
        
        let m0 = monthDate.startOfMonth
        let m1 = monthDate.startOfNextMonth
//        let inMonth = allLogs.filter { $0.startTime >= m0 && $0.startTime < m1 }
//        let totalSeconds = inMonth.reduce(0.0) { acc, log in
//            acc + max(0, log.endTime.timeIntervalSince(log.startTime))
//        }
        
        
        NavigationStack {
            ScrollView {
                VStack {
                    HStack {
                        Text("\(String(selectedYear)) 年工时热力图")
                            .font(.headline.bold())
                            .foregroundStyle(.primary)
                        Spacer()
                            Picker("年份", selection: $selectedYear) {
                                ForEach(availableYearsFrom(allLogs), id: \.self) { y in
                                    Text("\(String(y)) 年").tag(y)
                                }
                            }
                            .foregroundStyle(colorScheme == .dark ? .white : .black)

                            .labelsHidden()
                            .pickerStyle(.menu)
                    }
                    
                
                    
                    YearHeatmap2Rows(year: selectedYear, allLogs: allLogs)
                        .frame(height: 250)
                        .padding(.vertical)

                    
                    Divider()
                    
                    MonthlyTimelineSection(selectedYear: $selectedYear, selectedMonth: $selectedMonth, allLogs: allLogs)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
            }
            .navigationTitle("工时统计")
            .toolbar {

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        modalType = .addLog(defaultDate: Date())
                    } label: {
                        Label("添加", systemImage: "square.and.pencil")
                    }
                }
            }
            .sheet(item: $modalType) { sheet in
                ModalSheetView(modal: sheet)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }

    }
    
    private func availableYearsFrom(_ logs: [WorkLogs]) -> [Int] {
        let ys = logs.map { Calendar.current.component(.year, from: $0.startTime) }
        let minY = min(ys.min() ?? Date().yearInt, Date().yearInt)
        let maxY = max(ys.max() ?? Date().yearInt, Date().yearInt)
        return Array(minY...maxY).sorted(by: >)
    }
}

// MARK: - 年热力图（两行：1-6月，7-12月；不可交互；自适应宽度）
fileprivate struct YearHeatmap2Rows: View {
    let year: Int
    let allLogs: [WorkLogs]

    var body: some View {

        GeometryReader { geo in
//            let screenWidth = geo.size.width
            VStack(alignment: .leading, spacing: 10) {
//                Text("\(String(year)) 年工时热力图")
//                    .font(.headline.bold())
//                    .foregroundStyle(.primary)

                
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                    
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
            let spacing: CGFloat = 2
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




fileprivate struct MonthlyTimelineSection: View {
    @Binding var selectedYear: Int
    @Binding var selectedMonth: Int
    let allLogs: [WorkLogs]
    
    @State private var scrollToEndTrigger = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题 + 筛选下拉
            HStack {
                Text("每日分析")
                    .font(.headline.bold())
                
                Spacer(minLength: 0)
                
                Picker("年", selection: $selectedYear) {
                    ForEach(availableYearsFrom(allLogs), id: \.self) { year in
                        Text("\(String(year))年").tag(year)
                    }
                }
                .pickerStyle(.menu)
                

                Picker("月", selection: $selectedMonth) {
                    ForEach(availableMonthFrom(allLogs), id: \.self) { m in
                        Text("\(String(m))月").tag(m)
                    }
                }
                .pickerStyle(.menu)

            }

            // 主体：时间轴视图
            MonthlyTimelineView(
                year: selectedYear,
                month: selectedMonth,
                allLogs: allLogs,
                scrollToEndTrigger: $scrollToEndTrigger
            )
            .frame(height: 260)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(alignment: .topTrailing) {
                // 悬浮按钮
                Button {
                    scrollToEndTrigger.toggle()
                } label: {
                    Image(systemName: "arrow.right.to.line")
                        .font(.title3)
                        .padding(10)
                        .background(.thinMaterial, in: Circle())
                        .shadow(radius: 2)
                }
                .padding(12)
            }
        }
        .padding(.vertical, 6)
    }
    
    private func availableYearsFrom(_ logs: [WorkLogs]) -> [Int] {
        let ys = logs.map { Calendar.current.component(.year, from: $0.startTime) }
        let minY = min(ys.min() ?? Date().yearInt, Date().yearInt)
        let maxY = max(ys.max() ?? Date().yearInt, Date().yearInt)
        return Array(minY...maxY).sorted(by: >)
    }
    
    private func availableMonthFrom(_ logs: [WorkLogs]) -> [Int] {
        let ys = logs.map { Calendar.current.component(.month, from: $0.startTime) }
        let minY = min(ys.min() ?? Date().monthInt, Date().monthInt)
        let maxY = max(ys.max() ?? Date().monthInt, Date().monthInt)
        return Array(minY...maxY).sorted(by: >)
    }
}

fileprivate struct MonthlyTimelineView: View {
    let year: Int
    let month: Int
    let allLogs: [WorkLogs]
    @Binding var scrollToEndTrigger: Bool

    private var daysOfMonth: [Date] {
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: year, month: month, day: 1))!
        let end = cal.date(byAdding: .month, value: 1, to: start)!
        return stride(from: start, to: end, by: 86_400).map { $0 }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .bottom, spacing: 4) {  // ← 间距改为 4
                    ForEach(daysOfMonth, id: \.self) { day in
                        TimelineColumn(
                            day: day,
                            logs: logsIntersecting(day: day),
                            isToday: Calendar.current.isDateInToday(day)
                        )
                        .id(day.idKey)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            .onAppear {
                if let last = daysOfMonth.last {
                    withAnimation(.snappy) {
                        proxy.scrollTo(last.idKey, anchor: .trailing)
                    }
                }
            }
            .onChange(of: scrollToEndTrigger) { _ in
                if let last = daysOfMonth.last {
                    withAnimation(.snappy) {
                        proxy.scrollTo(last.idKey, anchor: .trailing)
                    }
                }
            }
        }
    }

    private func logsIntersecting(day: Date) -> [WorkLogs] {
        allLogs.filter { $0.endTime > day.startOfDay && $0.startTime < day.endOfDay }
    }
}

fileprivate struct TimelineColumn: View {
    let day: Date
    let logs: [WorkLogs]
    let isToday: Bool

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                let height = geo.size.height
                let track = RoundedRectangle(cornerRadius: 6)
                let colWidth: CGFloat = 18

                ZStack(alignment: .top) {
                    // 背景轨道
                    track
                        .fill(Color.gray.opacity(0.12))
                        .overlay(
                            track.stroke(Color.gray.opacity(0.25), lineWidth: 1)
                        )
                        .frame(width: colWidth)

                    // 工时段
                    ForEach(segmentsInDay(day, logs: logs), id: \.self) { seg in
                        let y = CGFloat(seg.lowerBound / 24.0) * height
                        let h = max(2, CGFloat((seg.upperBound - seg.lowerBound) / 24.0) * height)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.orange)
                            .frame(width: colWidth, height: h)
//                            .glassEffect(in: .rect(cornerRadius: 6))

                            .offset(y: y)
                    }

                    // 今日高亮边框
                    if isToday {
                        RoundedRectangle(cornerRadius: 6)
//                            .frame(width: colWidth, height: height)
                            .fill(.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.red.opacity(0.8), lineWidth: 2.5)
                            )
                            .shadow(color: Color.black.opacity(0.18), radius: 4, x: 0, y: 2)
                            .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 4)
//                            .stroke(Color.orange, lineWidth: 1.5)
//                            .frame(width: colWidth, height: height)
                    }
                }
            }
            .frame(width: 22, height: 200) // 列总体高度与宽度

            // 日期标签
            VStack(spacing: 2) {
                Text(String(format: "%02d", day.dayInt))
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.primary)

                let hours = totalHoursInDay(day)
                if hours > 0 {
                    Text(String(format: "%.0fh", hours))
                        .font(.caption2)
                        .foregroundColor(.orange)
                } else {
                    Text(" ")
                        .font(.caption2)
                }
            }
            .frame(width: 22)
        }
    }

    // MARK: - 数据辅助
    private func segmentsInDay(_ day: Date, logs: [WorkLogs]) -> [ClosedRange<Double>] {
        let start = day.startOfDay
        let end = day.endOfDay
        var segs: [ClosedRange<Double>] = []
        for l in logs {
            let s = max(l.startTime, start)
            let e = min(l.endTime, end)
            guard e > s else { continue }
            let lower = s.timeIntervalSince(start) / 3600
            let upper = e.timeIntervalSince(start) / 3600
            segs.append(lower...upper)
        }
        return mergeSegments(segs)
    }

    private func totalHoursInDay(_ day: Date) -> Double {
        logs.reduce(0) { acc, l in
            let start = max(l.startTime, day.startOfDay)
            let end   = min(l.endTime, day.endOfDay)
            return acc + max(0, end.timeIntervalSince(start) / 3600)
        }
    }

    private func mergeSegments(_ segs: [ClosedRange<Double>]) -> [ClosedRange<Double>] {
        guard !segs.isEmpty else { return [] }
        let sorted = segs.sorted { $0.lowerBound < $1.lowerBound }
        var merged: [ClosedRange<Double>] = [sorted[0]]
        for seg in sorted.dropFirst() {
            if var last = merged.last, seg.lowerBound <= last.upperBound {
                last = last.lowerBound...max(last.upperBound, seg.upperBound)
                merged[merged.count - 1] = last
            } else {
                merged.append(seg)
            }
        }
        return merged
    }
}



fileprivate extension Date {
    var endOfDay: Date { Calendar.current.date(byAdding: .second, value: 86_399, to: startOfDay)! }
    var idKey: String { ISO8601DateFormatter().string(from: self) }
}
//

// MARK: - Preview
//#Preview {
//    NavigationStack {
//        StaticView()
//            .environment(\.locale, .init(identifier: "zh-Hans-CN"))
//            .modelContainer(PreviewData.container)
//    }
//}

#Preview {
    @Previewable @StateObject var userSettings = UserSettings()
    @Previewable @StateObject var store = ModelStore(cloudEnabled: false)

    NavigationStack {
        StaticView()
            .environmentObject(userSettings)
            .environmentObject(store)
            .preferredColorScheme(userSettings.theme.colorScheme)
            .environment(\.locale, .init(identifier: "zh-Hans-CN"))
    }
    .modelContainer(PreviewData.container)
}
