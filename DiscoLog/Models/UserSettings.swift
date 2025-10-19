import SwiftUI
import Combine

final class UserSettings: ObservableObject {

    enum Theme: String, CaseIterable, Identifiable {
        case system = "自动"
        case light  = "浅色"
        case dark   = "深色"

        var id: String { rawValue }

        /// 用于 .preferredColorScheme
        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light:  return .light
            case .dark:   return .dark
            }
        }
    }

    // MARK: - Published Properties (持久化到 UserDefaults)
    @Published var theme: Theme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: Keys.theme) }
    }

    /// 仅用到「时分」，日期部分不重要
    @Published var defaultStart: Date {
        didSet { UserDefaults.standard.set(defaultStart, forKey: Keys.defaultStart) }
    }

    @Published var defaultEnd: Date {
        didSet { UserDefaults.standard.set(defaultEnd, forKey: Keys.defaultEnd) }
    }

    // MARK: - Init / Defaults
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
    }

    // MARK: - Public Helpers
    /// 将默认“开始时间”的时分，合成到指定日期上
    func start(on day: Date) -> Date {
        combine(defaultTime: defaultStart, with: day)
    }

    /// 将默认“结束时间”的时分，合成到指定日期上；若结束≤开始，则自动跨日 +1 天
    func end(on day: Date) -> Date {
        let s = start(on: day)
        var e = combine(defaultTime: defaultEnd, with: day)
        if e <= s {
            e = Calendar.current.date(byAdding: .day, value: 1, to: e)!
        }
        return e
    }

    /// 生成“今天某时某分”的 Date（仅用于初始化默认值）
    static func makeTime(hour: Int, minute: Int) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = hour; comps.minute = minute; comps.second = 0
        return Calendar.current.date(from: comps)!
    }

    // MARK: - Private
    private func combine(defaultTime: Date, with day: Date) -> Date {
        let cal = Calendar.current
        let t = cal.dateComponents([.hour, .minute, .second], from: defaultTime)
        var d = cal.dateComponents([.year, .month, .day], from: day)
        d.hour = t.hour; d.minute = t.minute; d.second = 0
        return cal.date(from: d)!
    }

    private struct Keys {
        static let theme        = "UserSettings.theme"
        static let defaultStart = "UserSettings.defaultStart"
        static let defaultEnd   = "UserSettings.defaultEnd"
    }
}
