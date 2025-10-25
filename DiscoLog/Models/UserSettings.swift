//
//  UserSettings.swift
//  WorkSession
//
//

import SwiftUI
import Combine

/// App-level user preferences (theme, default time range, iCloud switch).
final class UserSettings: ObservableObject {

    // MARK: - Theme

    enum Theme: String, CaseIterable, Identifiable {
        case system = "自动"
        case light  = "浅色"
        case dark   = "深色"
        var id: String { rawValue }
        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light:  return .light
            case .dark:   return .dark
            }
        }
    }

    // MARK: - Published Preferences

    @Published var theme: Theme {
        didSet { ud.set(theme.rawValue, forKey: Keys.theme) }
    }

    /// Default clock-in time (time-of-day only; date part is ignored).
    @Published var defaultStart: Date {
        didSet { ud.set(defaultStart, forKey: Keys.defaultStart) }
    }

    /// Default clock-out time (time-of-day only; can be ≤ start, which implies overnight).
    @Published var defaultEnd: Date {
        didSet { ud.set(defaultEnd, forKey: Keys.defaultEnd) }
    }

    /// Whether to enable iCloud sync for SwiftData container.
    @Published var iCloudSyncEnabled: Bool {
        didSet { ud.set(iCloudSyncEnabled, forKey: Keys.iCloudOn) }
    }
    
    // === Default project (persist UUID to UserDefaults as String) ===
    @Published var defaultProjectID: UUID? {
        didSet {
            let s = defaultProjectID?.uuidString
            UserDefaults.standard.set(s, forKey: Keys.defaultProjectID)
        }
    }
    
    @Published var defaultPayrollData: Data? {
        didSet { UserDefaults.standard.set(defaultPayrollData, forKey: Keys.defaultPayroll) }
    }

    /// Convenience computed property to access decoded config.
    var defaultPayroll: PayrollConfig? {
        get { decodeConfig(from: defaultPayrollData) }
        set { defaultPayrollData = encodeConfig(newValue) }
    }
    // MARK: - Dependencies

    private let ud: UserDefaults
    private let calendar: Calendar

    // MARK: - Init

    init(
        ud: UserDefaults = .standard,
        calendar: Calendar = .current
    ) {
        self.ud = ud
        self.calendar = calendar

        // Theme
        if let raw = ud.string(forKey: Keys.theme),
           let t = Theme(rawValue: raw) {
            theme = t
        } else {
            theme = .system
        }

        // Default times (fallback to 09:00–18:00)
        defaultStart = (ud.object(forKey: Keys.defaultStart) as? Date)
            ?? Self.makeTime(hour: 9, minute: 0, calendar: calendar)
        defaultEnd = (ud.object(forKey: Keys.defaultEnd) as? Date)
            ?? Self.makeTime(hour: 18, minute: 0, calendar: calendar)

        // iCloud switch
        iCloudSyncEnabled = (ud.object(forKey: Keys.iCloudOn) as? Bool) ?? false
        
        if let s = ud.string(forKey: Keys.defaultProjectID), let id = UUID(uuidString: s) {
            defaultProjectID = id
        } else {
            defaultProjectID = nil
        }
        
        if let data = UserDefaults.standard.data(forKey: Keys.defaultPayroll) {
            defaultPayrollData = data
        } else {
            defaultPayrollData = nil
        }
    }

        
    
    // MARK: - Public Helpers

    /// Compose a concrete start datetime on a given day using the default start time.
    func start(on day: Date) -> Date {
        Self.combine(timeOfDay: defaultStart, with: day, calendar: calendar)
    }

    /// Compose a concrete end datetime on a given day using the default end time.
    /// If the end is not later than start, returns the next-day end (overnight).
    func end(on day: Date) -> Date {
        let s = start(on: day)
        var e = Self.combine(timeOfDay: defaultEnd, with: day, calendar: calendar)
        if e <= s {
            e = calendar.date(byAdding: .day, value: 1, to: e) ?? e
        }
        return e
    }

    /// Default interval length in hours (normalized with overnight rule).
    var defaultIntervalHours: Double {
        let today = calendar.startOfDay(for: Date())
        let s = start(on: today)
        let e = end(on: today)
        return max(0, e.timeIntervalSince(s) / 3600)
    }

    /// Batch update defaults with normalization.
    func updateDefaultTimes(start: Date, end: Date) {
        self.defaultStart = start
        self.defaultEnd = end
    }

    /// Reset to factory defaults (09:00–18:00, system theme, iCloud off).
    func reset() {
        theme = .system
        defaultStart = Self.makeTime(hour: 9, minute: 0, calendar: calendar)
        defaultEnd   = Self.makeTime(hour: 18, minute: 0, calendar: calendar)
        iCloudSyncEnabled = false
    }

    // MARK: - Private Utilities

    /// Create a time-of-day anchored to "today" (date part is irrelevant for storage).
    private static func makeTime(hour: Int, minute: Int, calendar: Calendar) -> Date {
        var comps = calendar.dateComponents([.year, .month, .day], from: Date())
        comps.hour = hour; comps.minute = minute; comps.second = 0
        return calendar.date(from: comps) ?? Date()
    }

    /// Combine a stored time-of-day with an arbitrary day to produce a concrete Date.
    private static func combine(timeOfDay: Date, with day: Date, calendar: Calendar) -> Date {
        let t = calendar.dateComponents([.hour, .minute, .second], from: timeOfDay)
        var d = calendar.dateComponents([.year, .month, .day], from: day)
        d.hour = t.hour; d.minute = t.minute; d.second = t.second ?? 0
        return calendar.date(from: d) ?? day
    }

    // MARK: - Persistence Keys

    private enum Keys {
        static let theme        = "UserSettings.theme"
        static let defaultStart = "UserSettings.defaultStart"
        static let defaultEnd   = "UserSettings.defaultEnd"
        static let iCloudOn     = "UserSettings.iCloudOn"
        static let defaultProjectID  = "UserSettings.defaultProjectID"
        static let defaultPayroll    = "UserSettings.defaultPayroll"

    }
    
    // MARK: - Codable helpers
    private func encodeConfig(_ cfg: PayrollConfig?) -> Data? {
        guard let cfg else { return nil }
        return try? JSONEncoder().encode(cfg)
    }
    private func decodeConfig(from data: Data?) -> PayrollConfig? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(PayrollConfig.self, from: data)
    }
}
