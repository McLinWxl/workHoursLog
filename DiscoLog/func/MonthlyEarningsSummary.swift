//
//  MonthlyEarningsSummary.swift
//  DiscoLog
//
//  Created by McLin on 2025/10/25.
//


//
//  MonthlyEarningsCalculator.swift
//

import Foundation

/// Aggregated monthly result for UI.
struct MonthlyEarningsSummary: Hashable {
    let period: DateInterval
    let hours: BucketHours
    let amountRegular: Decimal
    let amountWorkdayOT: Decimal
    let amountRestDayOT: Decimal
    let amountHolidayOT: Decimal
    var amountTotal: Decimal { amountRegular + amountWorkdayOT + amountRestDayOT + amountHolidayOT }
    /// Project-level statements (key = project.id or nil for unassigned).
    let byProject: [UUID?: PayrollStatement]
    /// True if there exist unassigned logs that were skipped due to missing default payroll.
    let hasUnassignedButNoDefault: Bool
}

struct MonthlyEarningsCalculator {
    let engine = CompensationEngine()

    /// Summarize a month window. Unassigned logs require a default payroll; otherwise they are skipped.
    func summarize(
        logs: [WorkLog],
        monthAnchor: Date,
        defaultPayroll: PayrollConfig?
    ) -> MonthlyEarningsSummary {
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: monthAnchor.yearInt, month: monthAnchor.monthInt, day: 1))!
        let end   = cal.date(byAdding: .month, value: 1, to: start)!
        let period = DateInterval(start: start, end: end)

        // Group by project id (nil for unassigned).
        let grouped = Dictionary(grouping: logs) { (log: WorkLog) in log.project?.id }
        var byProject: [UUID?: PayrollStatement] = [:]

        var accHours = BucketHours()
        var amtReg: Decimal = 0
        var amtWot: Decimal = 0
        var amtRot: Decimal = 0
        var amtHot: Decimal = 0

        var hasUnassignedButNoDefault = false

        for (key, group) in grouped {
            let cfg: PayrollConfig?
            if key != nil {
                // per-project config
                guard let anyCfg = group.first?.project?.payroll else { continue }
                cfg = anyCfg
            } else {
                // unassigned
                cfg = defaultPayroll
                if cfg == nil { hasUnassignedButNoDefault = true }
            }
            guard let useCfg = cfg else { continue }

            // Filter invalid ranges and compute
//            let cleaned = group.filter { $0.endTime >= $0.startTime }
//            guard !cleaned.isEmpty else { continue }
            
//            print(group.count)

            let stmt = engine.computeStatement(logs: group, period: period, cfg: useCfg)
            byProject[key] = stmt

            // Accumulate
            accHours.regular   += stmt.hours.regular
            accHours.workdayOT += stmt.hours.workdayOT
            accHours.restDayOT += stmt.hours.restDayOT
            accHours.holidayOT += stmt.hours.holidayOT

            amtReg += stmt.amountRegular.rounded(scale: 2)
            amtWot += stmt.amountWorkdayOT.rounded(scale: 2)
            amtRot += stmt.amountRestDayOT.rounded(scale: 2)
            amtHot += stmt.amountHolidayOT.rounded(scale: 2)
        }

        return MonthlyEarningsSummary(
            period: period,
            hours: accHours,
            amountRegular: amtReg,
            amountWorkdayOT: amtWot,
            amountRestDayOT: amtRot,
            amountHolidayOT: amtHot,
            byProject: byProject,
            hasUnassignedButNoDefault: hasUnassignedButNoDefault
        )
    }
}


extension Decimal {
    func rounded(scale: Int, mode: NSDecimalNumber.RoundingMode = .bankers) -> Decimal {
        var result = Decimal()
        var value = self
        NSDecimalRound(&result, &value, scale, mode)
        return result
    }
}
