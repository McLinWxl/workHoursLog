//
//  StaticView.swift
//  WorkSession
//
//

import SwiftUI
import SwiftData

// MARK: - Root: Year heatmap (2 rows) + monthly timeline

struct StaticView: View {
    @Query(sort: [SortDescriptor(\WorkLog.startTime, order: .forward)])
    private var allLogs: [WorkLog]

    @State private var modal: ModalType?
    @State private var selectedYear: Int = Date().yearInt
    @State private var selectedMonth: Int = Date().monthInt
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Header: year title + picker
                    HStack {
                        Text("\(selectedYear) 年工时热力图")
                            .font(.headline.bold())
                        Spacer()
                        Picker("年份", selection: $selectedYear) {
                            ForEach(availableYears(from: allLogs), id: \.self) { y in
                                Text("\(y) 年").tag(y)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .foregroundStyle(colorScheme == .dark ? .white : .black)
                    }

                    // Year heatmap
                    let heatmap = YearHeatmapData(year: selectedYear, logs: allLogs)
                    YearHeatmapTwoRows(data: heatmap)
                        .frame(height: 250)
                        .padding(.vertical)

                    Divider()

                    // Monthly timeline
                    MonthlyTimelineSection(
                        selectedYear: $selectedYear,
                        selectedMonth: $selectedMonth,
                        allLogs: allLogs
                    )
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
            }
            .navigationTitle("工时统计")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { modal = .addLog(defaultDate: Date()) } label: {
                        Label("添加", systemImage: "square.and.pencil")
                    }
                }
            }
            .sheet(item: $modal) { sheet in
                ModalSheetView(modal: sheet)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // Years bounded by logs range and current year (descending)
    private func availableYears(from logs: [WorkLog]) -> [Int] {
        let ys = logs.map { $0.startTime.yearInt }
        let now = Date().yearInt
        let minY = min(ys.min() ?? now, now)
        let maxY = max(ys.max() ?? now, now)
        return Array(minY...maxY).sorted(by: >)
    }
}

// MARK: - Year heatmap (two halves: 1–6, 7–12)

/// Precomputed, shareable data for a full year's heatmap.
fileprivate struct YearHeatmapData {
    let year: Int
    /// Daily total hours for the year (keyed by startOfDay)
    let totals: [Date: Double]

    init(year: Int, logs: [WorkLog]) {
        self.year = year
        let cal = Calendar.current
        let yStart = cal.date(from: DateComponents(year: year, month: 1, day: 1))?.startOfDay ?? Date().startOfYear
        let yEnd   = cal.date(from: DateComponents(year: year, month: 12, day: 31))?.startOfDay ?? yStart

        // Accumulate hours by day for logs intersecting the year
        var dict: [Date: Double] = [:]
        for l in logs {
            // Fast-path reject if completely out of year
            let s = l.startTime
            guard s >= yStart && s <= yEnd.addingTimeInterval(24*3600 - 1) else { continue }
            let key = s.startOfDay
            dict[key, default: 0] += max(0, l.endTime.timeIntervalSince(l.startTime)) / 3600.0
        }
        self.totals = dict
    }
}

fileprivate struct YearHeatmapTwoRows: View {
    let data: YearHeatmapData

    var body: some View {
        GeometryReader { _ in
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                    VStack(spacing: 0) {
                        HalfYearHeatmap(halfIndex: 0, data: data) // 1–6
                        HalfYearHeatmap(halfIndex: 1, data: data) // 7–12
                    }
                    .offset(y: 20)
                    .padding(.horizontal, 5)
                }
            }
        }
    }
}

/// A 6-month heatmap aligned by weeks. Non-interactive.
fileprivate struct HalfYearHeatmap: View {
    let halfIndex: Int // 0 -> Jan–Jun, 1 -> Jul–Dec
    let data: YearHeatmapData

    var body: some View {
        let year = data.year
        let (alignedStart, alignedEnd) = halfRangeAligned(year: year, halfIndex: halfIndex)
        let days: [Date] = Date.sequenceDays(from: alignedStart, through: alignedEnd)

        // columns = number of weeks
        let columns = max(1, Int(ceil(Double(days.count) / 7.0)))

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
                                        .fill(color(for: d))
                                        .frame(width: cellSize, height: cellHeight)
                                } else {
                                    Color.clear.frame(width: cellSize, height: cellHeight)
                                }
                            }
                        }
                    }
                }

                // Month labels at the first week of each month within this half
                let monthsRange = (halfIndex == 0 ? 1...6 : 7...12)
                let cal = Calendar.current
                ForEach(Array(monthsRange), id: \.self) { m in
                    if let firstOfMonth = cal.date(from: DateComponents(year: year, month: m, day: 1)) {
                        let offsetDays = max(0, cal.dateComponents([.day], from: alignedStart, to: firstOfMonth).day ?? 0)
                        let colIndex = offsetDays / 7
                        if firstOfMonth.dayInt <= 7, colIndex < columns {
                            let x = CGFloat(colIndex) * (cellSize + spacing)
                            Text("\(m)月")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .minimumScaleFactor(0.8)
                                .offset(x: x, y: -15)
                        }
                    }
                }
            }
        }
    }

    // Inclusive aligned start/end around the half-year to full weeks
    private func halfRangeAligned(year: Int, halfIndex: Int) -> (Date, Date) {
        let cal = Calendar.current
        let startMonth = (halfIndex == 0) ? 1 : 7
        let endMonth   = startMonth + 5

        let monthStart = cal.date(from: DateComponents(year: year, month: startMonth, day: 1))?.startOfDay
            ?? Date().startOfMonth
        let endMonthStart = cal.date(from: DateComponents(year: year, month: endMonth, day: 1)) ?? monthStart
        let lastDayOfEndMonth = (cal.range(of: .day, in: .month, for: endMonthStart)?.count ?? 1)
        let monthEnd = cal.date(from: DateComponents(year: year, month: endMonth, day: lastDayOfEndMonth))?.startOfDay
            ?? endMonthStart

        let firstW = cal.firstWeekday // 1..7
        let startWeekday = cal.component(.weekday, from: monthStart)
        let startOffset = (startWeekday - firstW + 7) % 7
        let alignedStart = cal.date(byAdding: .day, value: -startOffset, to: monthStart) ?? monthStart

        let endWeekday = cal.component(.weekday, from: monthEnd)
        let endOffset = (firstW + 6 - endWeekday + 7) % 7 // pad to end of week
        let alignedEnd = cal.date(byAdding: .day, value: endOffset, to: monthEnd) ?? monthEnd
        return (alignedStart, alignedEnd)
    }

    private func isInThisHalf(_ date: Date) -> Bool {
        let m = date.monthInt
        return halfIndex == 0 ? (1...6).contains(m) : (7...12).contains(m)
    }

    private func color(for day: Date) -> Color {
        guard isInThisHalf(day) else { return .clear }
        let h = data.totals[day.startOfDay] ?? 0

        // Map hours to opacity with smooth thresholds (0 -> light gray, 8h -> solid orange).
        if h <= 0.01 { return Color.gray.opacity(0.18) }
        let capped = min(h, 12.0) // clamp for extreme days
        let opacity = 0.06 + (capped / 12.0) * (1.0 - 0.06)
        return Color.orange.opacity(opacity)
    }
}

// MARK: - Monthly timeline (horizontal bars per day)

fileprivate struct MonthlyTimelineSection: View {
    @Binding var selectedYear: Int
    @Binding var selectedMonth: Int
    let allLogs: [WorkLog]

    @State private var scrollToEndTrigger = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("每日分析").font(.headline.bold())
                Spacer(minLength: 0)
                Picker("年", selection: $selectedYear) {
                    ForEach(availableYears(from: allLogs), id: \.self) { y in
                        Text("\(y)年").tag(y)
                    }
                }
                .pickerStyle(.menu)

                Picker("月", selection: $selectedMonth) {
                    ForEach(1...12, id: \.self) { m in
                        Text("\(m)月").tag(m)
                    }
                }
                .pickerStyle(.menu)
            }

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

    private func availableYears(from logs: [WorkLog]) -> [Int] {
        let ys = logs.map { $0.startTime.yearInt }
        let now = Date().yearInt
        let minY = min(ys.min() ?? now, now)
        let maxY = max(ys.max() ?? now, now)
        return Array(minY...maxY).sorted(by: >)
    }
}

fileprivate struct MonthlyTimelineView: View {
    let year: Int
    let month: Int
    let allLogs: [WorkLog]
    @Binding var scrollToEndTrigger: Bool

    private var daysOfMonth: [Date] {
        let start = Calendar.current.date(from: DateComponents(year: year, month: month, day: 1))?.startOfDay
            ?? Date().startOfMonth
        let end = Calendar.current.date(byAdding: .month, value: 1, to: start)?.startOfDay
            ?? start.startOfNextMonth
        return Date.sequenceDays(from: start, to: end)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .bottom, spacing: 4) {
                    ForEach(daysOfMonth, id: \.self) { day in
                        TimelineColumn(
                            day: day,
                            logs: logsIntersecting(day: day),
                            isToday: Calendar.current.isDateInToday(day)
                        )
                        .id(day.isoKey)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            .onAppear {
                if let last = daysOfMonth.last {
                    withAnimation(.snappy) { proxy.scrollTo(last.isoKey, anchor: .trailing) }
                }
            }
            .onChange(of: scrollToEndTrigger) { _ in
                if let last = daysOfMonth.last {
                    withAnimation(.snappy) { proxy.scrollTo(last.isoKey, anchor: .trailing) }
                }
            }
        }
    }

    private func logsIntersecting(day: Date) -> [WorkLog] {
        let s = day.startOfDay
        let e = day.endOfDay
        return allLogs.filter { $0.endTime > s && $0.startTime < e }
    }
}

fileprivate struct TimelineColumn: View {
    let day: Date
    let logs: [WorkLog]
    let isToday: Bool

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                let height = geo.size.height
                let track = RoundedRectangle(cornerRadius: 6)
                let colWidth: CGFloat = 18

                ZStack(alignment: .top) {
                    // Track
                    track
                        .fill(Color.gray.opacity(0.12))
                        .overlay(track.stroke(Color.gray.opacity(0.25), lineWidth: 1))
                        .frame(width: colWidth)

                    // Segments
                    ForEach(daySegments(day, logs: logs), id: \.self) { seg in
                        let y = CGFloat(seg.lowerBound / 24.0) * height
                        let h = max(2, CGFloat((seg.upperBound - seg.lowerBound) / 24.0) * height)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.orange)
                            .frame(width: colWidth, height: h)
                            .offset(y: y)
                    }

                    // Today highlight
                    if isToday {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.red.opacity(0.8), lineWidth: 2.5)
                            )
                            .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)
                            .shadow(color: .black.opacity(0.10), radius: 10, x: 0, y: 4)
                    }
                }
            }
            .frame(width: 22, height: 200)

            // Labels
            VStack(spacing: 2) {
                Text(String(format: "%02d", day.dayInt))
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.primary)

                let hours = totalHoursOfDay(day, logs: logs)
                if hours > 0 {
                    Text(String(format: "%.0fh", hours))
                        .font(.caption2)
                        .foregroundColor(.orange)
                } else {
                    Text(" ").font(.caption2)
                }
            }
            .frame(width: 22)
        }
    }

    // Build merged hour segments within [0, 24] for a given day.
    private func daySegments(_ day: Date, logs: [WorkLog]) -> [ClosedRange<Double>] {
        let s = day.startOfDay, e = day.endOfDay
        let raw: [ClosedRange<Double>] = logs.compactMap { l in
            let ss = max(l.startTime, s), ee = min(l.endTime, e)
            guard ee > ss else { return nil }
            let lower = ss.timeIntervalSince(s) / 3600
            let upper = ee.timeIntervalSince(s) / 3600
            return lower...upper
        }
        return merge(raw)
    }

    private func totalHoursOfDay(_ day: Date, logs: [WorkLog]) -> Double {
        logs.reduce(0) { acc, l in
            let s = max(l.startTime, day.startOfDay)
            let e = min(l.endTime, day.endOfDay)
            return acc + max(0, e.timeIntervalSince(s) / 3600)
        }
    }

    /// Merge overlapping/adjacent ranges (in hours).
    private func merge(_ segs: [ClosedRange<Double>]) -> [ClosedRange<Double>] {
        guard !segs.isEmpty else { return [] }
        let sorted = segs.sorted { $0.lowerBound < $1.lowerBound }
        var out: [ClosedRange<Double>] = [sorted[0]]
        for s in sorted.dropFirst() {
            if var last = out.last, s.lowerBound <= last.upperBound {
                last = last.lowerBound ... max(last.upperBound, s.upperBound)
                out[out.count - 1] = last
            } else {
                out.append(s)
            }
        }
        return out
    }
}

// MARK: - Local utilities (scoped)

//fileprivate extension Date {
//
//    var startOfYear: Date {
//        let cal = Calendar.current
//        let comps = cal.dateComponents([.year], from: self)
//        return cal.date(from: comps) ?? self
//    }
//
//    static func sequenceDays(from start: Date, to end: Date) -> [Date] {
//        guard start <= end else { return [] }
//        var out: [Date] = []
//        var cur = start
//        while cur < end {
//            out.append(cur)
//            cur = Calendar.current.date(byAdding: .day, value: 1, to: cur) ?? end
//        }
//        return out
//    }
//
//    static func sequenceDays(from start: Date, through endInclusive: Date) -> [Date] {
//        guard start <= endInclusive else { return [] }
//        var out: [Date] = []
//        var cur = start
//        while cur <= endInclusive {
//            out.append(cur)
//            cur = Calendar.current.date(byAdding: .day, value: 1, to: cur) ?? endInclusive.addingTimeInterval(1)
//        }
//        return out
//    }
//
//    var isoKey: String { ISO8601DateFormatter().string(from: self) }
//}
