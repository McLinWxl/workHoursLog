import SwiftUI
import Combine

final class UserSettings: ObservableObject {

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

    // === 外观 ===
    @Published var theme: Theme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: Keys.theme) }
    }

    // === 默认时段（仅时分） ===
    @Published var defaultStart: Date {
        didSet { UserDefaults.standard.set(defaultStart, forKey: Keys.defaultStart) }
    }
    @Published var defaultEnd: Date {
        didSet { UserDefaults.standard.set(defaultEnd, forKey: Keys.defaultEnd) }
    }

    // MARK: - 同步开关
    @Published var iCloudSyncEnabled: Bool {
        didSet { UserDefaults.standard.set(iCloudSyncEnabled, forKey: Keys.iCloudOn) }
    }

    // MARK: Init / 读取默认值
    init() {
        let ud = UserDefaults.standard

        if let raw = ud.string(forKey: Keys.theme),
           let t = Theme(rawValue: raw) {
            theme = t
        } else {
            theme = .system
        }

        if let s = ud.object(forKey: Keys.defaultStart) as? Date {
            defaultStart = s
        } else {
            defaultStart = Self.makeTime(hour: 9, minute: 0)
        }

        if let e = ud.object(forKey: Keys.defaultEnd) as? Date {
            defaultEnd = e
        } else {
            defaultEnd = Self.makeTime(hour: 18, minute: 0)
        }

        iCloudSyncEnabled = ud.object(forKey: Keys.iCloudOn) as? Bool ?? false
    }

    // MARK: Helpers
    func start(on day: Date) -> Date { combine(defaultTime: defaultStart, with: day) }
    func end(on day: Date) -> Date {
        let s = start(on: day)
        var e = combine(defaultTime: defaultEnd, with: day)
        if e <= s { e = Calendar.current.date(byAdding: .day, value: 1, to: e)! }
        return e
    }

    static func makeTime(hour: Int, minute: Int) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = hour; comps.minute = minute; comps.second = 0
        return Calendar.current.date(from: comps)!
    }

    private func combine(defaultTime: Date, with day: Date) -> Date {
        let cal = Calendar.current
        let t = cal.dateComponents([.hour, .minute, .second], from: defaultTime)
        var d = cal.dateComponents([.year, .month, .day], from: day)
        d.hour = t.hour; d.minute = t.minute; d.second = 0
        return cal.date(from: d)!
    }

    private struct Keys {
        static let theme             = "UserSettings.theme"
        static let defaultStart      = "UserSettings.defaultStart"
        static let defaultEnd        = "UserSettings.defaultEnd"
        static let iCloudOn          = "UserSettings.iCloudOn"
    }
}
