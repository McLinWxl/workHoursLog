//
//  WorkMode.swift
//  DiscoLog
//
//  Created by McLin on 2025/10/25.
//


//
//  WorkMode.swift
//  WorkSession
//
//  Defines work schemes and rate configuration.
//

import Foundation

/// High-level work schemes.
enum WorkMode: String, Codable, CaseIterable, Identifiable {
//    case fixedSalary        // No overtime; reporting only
    case standardHours      // OT after 8h per day; weekends/holidays as OT
    case comprehensiveHours // OT after monthly quota (e.g., 8h * workdays)

    var id: String { rawValue }
}

/// Multipliers for overtime scenarios.
struct OvertimeMultipliers: Codable, Hashable {
    var workday: Double   // e.g., 1.5
    var restDay: Double   // e.g., 2.0
    var holiday: Double   // e.g., 3.0
}

/// Base rate and multiplier table.
struct RateTable: Codable, Hashable {
    var basePerHour: Double
    var multipliers: OvertimeMultipliers

    static let demo = RateTable(
        basePerHour: 30,
        multipliers: .init(workday: 1.5, restDay: 2.0, holiday: 3.0)
    )
}

/// Payroll period granularity.
enum PayrollPeriodKind: String, Codable {
    case monthly
}

/// Payroll config knobs.
struct PayrollConfig: Codable {
    var mode: WorkMode
    var periodKind: PayrollPeriodKind = .monthly
    var dailyRegularHours: Double = 8.0         // for standardHours
    var hoursPerWorkday: Double = 8.0           // for comprehensiveHours quota
    var rateTable: RateTable = .demo
}
