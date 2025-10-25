//
//  CompensationEngine.swift
//  WorkSession
//
//  Classifies work logs and computes pay buckets.
//  Flags on WorkLog override calendar inference.
//

import Foundation
import SwiftData

// MARK: - Calendar Abstraction

/// Pluggable calendar for basic weekend rule. Holidays default to false.
protocol WorkCalendar {
    func isHoliday(_ date: Date) -> Bool
    func isWeekend(_ date: Date) -> Bool
    func isWorkday(_ date: Date) -> Bool
    func workdays(in month: Date, calendar: Calendar) -> Int
}

/// Default: weekends as rest days, no special holidays.
struct DefaultWorkCalendar: WorkCalendar {
    func isHoliday(_ date: Date) -> Bool { false }
    func isWeekend(_ date: Date) -> Bool {
        let wd = Calendar.current.component(.weekday, from: date) // 1=Sun ... 7=Sat
        return wd == 1 || wd == 7
    }
    func isWorkday(_ date: Date) -> Bool { !isWeekend(date) && !isHoliday(date) }

    func workdays(in month: Date, calendar: Calendar = .current) -> Int {
        guard
            let range = calendar.range(of: .day, in: .month, for: month),
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: month))
        else { return 0 }
        return range.compactMap { day -> Int? in
            guard let d = calendar.date(byAdding: .day, value: day - 1, to: start) else { return nil }
            return isWorkday(d) ? 1 : nil
        }.count
    }
}

// MARK: - Buckets

enum PayBucket: String, CaseIterable, Hashable {
    case regular
    case overtimeWorkday
    case overtimeRestDay
    case overtimeHoliday
}

struct BucketHours: Hashable {
    var regular: Double = 0
    var workdayOT: Double = 0
    var restDayOT: Double = 0
    var holidayOT: Double = 0

    mutating func add(_ bucket: PayBucket, hours: Double) {
        let h = max(0, hours)
        switch bucket {
        case .regular:          regular  += h
        case .overtimeWorkday:  workdayOT += h
        case .overtimeRestDay:  restDayOT += h
        case .overtimeHoliday:  holidayOT += h
        }
    }

    func totalHours() -> Double { regular + workdayOT + restDayOT + holidayOT }
}

struct PayrollStatement: Hashable {
    var period: DateInterval
    var hours: BucketHours
    var amountRegular: Double
    var amountWorkdayOT: Double
    var amountRestDayOT: Double
    var amountHolidayOT: Double
    var amountTotal: Double
}

// MARK: - Engine

struct CompensationEngine {
    var calendar: Calendar = .current
    var workCalendar: WorkCalendar = DefaultWorkCalendar()

    // Public API
    func computeStatement(
        logs: [WorkLog],
        period: DateInterval,
        cfg: PayrollConfig
    ) -> PayrollStatement {
        let sliced = sliceLogsByDay(logs, limitedTo: period)
        let buckets = classifyAndAccumulate(sliced: sliced, cfg: cfg, monthAnchor: period.start)

        let rt = cfg.rateTable
        let amtRegular     = buckets.regular   * rt.basePerHour
        let amtWorkdayOT   = buckets.workdayOT * rt.basePerHour * rt.multipliers.workday
        let amtRestDayOT   = buckets.restDayOT * rt.basePerHour * rt.multipliers.restDay
        let amtHolidayOT   = buckets.holidayOT * rt.basePerHour * rt.multipliers.holiday
        let total          = amtRegular + amtWorkdayOT + amtRestDayOT + amtHolidayOT

        return PayrollStatement(
            period: period,
            hours: buckets,
            amountRegular: amtRegular,
            amountWorkdayOT: amtWorkdayOT,
            amountRestDayOT: amtRestDayOT,
            amountHolidayOT: amtHolidayOT,
            amountTotal: total
        )
    }

    // MARK: Classification

    private func classifyAndAccumulate(
        sliced: [DaySlice],
        cfg: PayrollConfig,
        monthAnchor: Date
    ) -> BucketHours {
        switch cfg.mode {
//        case .fixedSalary:
//            // Reporting only: treat everything as regular hours.
//            var b = BucketHours()
//            b.add(.regular, hours: sliced.reduce(0.0) { $0 + $1.hours })
//            return b

        case .standardHours:
            return classifyStandardHours(sliced: sliced, dailyRegular: cfg.dailyRegularHours)

        case .comprehensiveHours:
            return classifyComprehensive(sliced: sliced,
                                         monthAnchor: monthAnchor,
                                         hoursPerWorkday: cfg.hoursPerWorkday)
        }
    }

    /// Standard hours: per-day regular up to threshold, remainder as OT.
    /// Day type resolution priority:
    ///   1) slice flags (isHoliday / isRestDay) -> if any slice marks holiday/rest, the whole day follows that type
    ///   2) fallback to weekend rule (DefaultWorkCalendar)
    private func classifyStandardHours(sliced: [DaySlice], dailyRegular: Double) -> BucketHours {
        var b = BucketHours()
        let grouped = Dictionary(grouping: sliced, by: \.dayKey)

        for (_, daySlices) in grouped {
            // Resolve day type with explicit flags first.
            let explicitHoliday = daySlices.contains { $0.isHoliday }
            let explicitRest    = daySlices.contains { $0.isRestDay }

            let day = daySlices.first?.day ?? Date()
            
            
            let isHolidayDay = explicitHoliday
            let isRestDay    = !isHolidayDay && explicitRest

            var remainingRegular = (isHolidayDay || isRestDay) ? 0.0 : max(0, dailyRegular)

            for s in daySlices.sorted(by: { $0.start < $1.start }) {
                let h = s.hours
                if isHolidayDay {
                    b.add(.overtimeHoliday, hours: h)
                } else if isRestDay {
                    b.add(.overtimeRestDay, hours: h)
                } else {
                    let reg = min(remainingRegular, h)
                    let ot  = max(0, h - reg)
                    if reg > 0 { b.add(.regular,         hours: reg) }
                    if ot  > 0 { b.add(.overtimeWorkday, hours: ot ) }
                    remainingRegular -= reg
                }
            }
        }
        return b
    }

    /// Comprehensive: monthly regular quota = workdays * hoursPerWorkday.
    /// Slice-level flags still override for holiday/rest OT classification.
    private func classifyComprehensive(
        sliced: [DaySlice],
        monthAnchor: Date,
        hoursPerWorkday: Double
    ) -> BucketHours {
        var b = BucketHours()

        // Monthly regular quota (based on calendar workdays, not per-log flags)
        let workdayCount = max(0, workCalendar.workdays(in: monthAnchor, calendar: calendar))
        var remainingRegular = Double(workdayCount) * max(0, hoursPerWorkday)

        for s in sliced.sorted(by: { $0.start < $1.start }) {
            // Resolve slice type: flags first, then weekend fallback
            if s.isHoliday {
                b.add(.overtimeHoliday, hours: s.hours)
                continue
            }
            if s.isRestDay {
                b.add(.overtimeRestDay, hours: s.hours)
                continue
            }
            // Workday: consume remaining monthly regular quota
            let reg = min(remainingRegular, s.hours)
            let ot  = max(0, s.hours - reg)
            if reg > 0 { b.add(.regular,         hours: reg) }
            if ot  > 0 { b.add(.overtimeWorkday, hours: ot ) }
            remainingRegular -= reg
        }
        return b
    }

    // MARK: Slicing

    /// Represents a portion of a WorkLog confined within a single day.
    private struct DaySlice: Hashable {
        let start: Date
        let end: Date
        let isRestDay: Bool     // explicit flag from WorkLog
        let isHoliday: Bool     // explicit flag from WorkLog

        var hours: Double { max(0, end.timeIntervalSince(start) / 3600) }
        var day: Date { Calendar.current.startOfDay(for: start) }
        var dayKey: String { DateFormatter.yyyyMMdd.string(from: day) }
    }

    /// Split logs by day and crop to the given period.
    /// Explicit flags are carried to each slice (cross-day logs duplicate flags).
    private func sliceLogsByDay(_ logs: [WorkLog], limitedTo period: DateInterval) -> [DaySlice] {
        var out: [DaySlice] = []
        for log in logs {
            let clampedStart = max(log.startTime, period.start)
            let clampedEnd   = min(log.endTime, period.end)
            guard clampedEnd > clampedStart else { continue }

            var s = clampedStart
            while s < clampedEnd {
                let sod = calendar.startOfDay(for: s)
                let eod = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: sod) ?? clampedEnd
                let sliceEnd = min(eod, clampedEnd)
                out.append(DaySlice(start: s,
                                    end: sliceEnd,
                                    isRestDay: log.isRestDay,
                                    isHoliday: log.isHoliday))
                s = calendar.date(byAdding: .second, value: 1, to: sliceEnd) ?? clampedEnd
            }
        }
        return out
    }
}

// MARK: - Utilities

private extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let f = DateFormatter()
        f.calendar = .current
        f.locale = .current
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
