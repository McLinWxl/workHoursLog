//
//  SettingsView.swift
//  DiscoLog
//
//  Created by McLin on 2025/10/19.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @EnvironmentObject var settings: UserSettings
    @Environment(\.colorScheme) private var systemScheme

    // 读取所有日志用于统计
    @Query(sort: [SortDescriptor(\WorkLogs.startTime)]) private var allLogs: [WorkLogs]

    // MARK: - 汇总指标（按开始日期归属）
    private var recordedDays: Int {
        let days = Set(allLogs.map { $0.startTime.startOfDay })
        return days.count
    }
    private var totalHours: Double {
        let totalSeconds = allLogs.reduce(0.0) { acc, log in
            acc + max(0, log.endTime.timeIntervalSince(log.startTime))
        }
        return totalSeconds / 3600.0
    }
    private var totalHoursText: String {
        String(format: "%.1f", totalHours)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 8) {
                        StatCard(
                            title: "记录",
                            value: "\(recordedDays)天",
                        )
                        Spacer(minLength: 0)
                        StatCard(
                            title: "总计工时",
                            value: "\(totalHoursText) 小时",
                        )
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Color.clear)
                }
                

                // 显示设置
                Section(header: Text("显示外观")) {
                    Picker("外观", selection: $settings.theme) {
                        ForEach(UserSettings.Theme.allCases) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // 偏好设置
                Section(header: Text("记录偏好")) {
                    DatePicker("默认开始时间",
                               selection: $settings.defaultStart,
                               displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)

                    DatePicker("默认结束时间",
                               selection: $settings.defaultEnd,
                               displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)

                    Text("若结束时间早于或等于开始时间，则视为跨日记录。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                // 关于软件
                Section() {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("关于工时记", systemImage: "info.circle.fill")
                    }
                }

                // 恢复默认
                Section {
                    Button(role: .destructive) {
                        settings.theme = .system
                        settings.defaultStart = UserSettings.makeTime(hour: 9, minute: 0)
                        settings.defaultEnd   = UserSettings.makeTime(hour: 18, minute: 0)
                    } label: {
                        Text("恢复默认设置")
                    }
                }
            }
            .preferredColorScheme(settings.theme.colorScheme)
            .navigationTitle("设置")
            
        }
    }

    private var schemeDescription: String {
        switch settings.theme {
        case .system:
            return systemScheme == .dark ? "深色（跟随系统）" : "浅色（跟随系统）"
        case .light: return "浅色"
        case .dark:  return "深色"
        }
    }
}

fileprivate struct StatCard: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading) {
            Text(value)
                .font(.title2.bold())
            Spacer(minLength: 0)
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)

        .background(
            RoundedRectangle(cornerRadius: 27)
                .fill(scheme == .dark ? Color.gray.opacity(0.22) : .white)
        )
//        .shadow(radius: 8, y: 4)
    }
}

struct AboutView: View {
    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        ?? "DiscoLog"
    }
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
    }
    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
    }

    var body: some View {
        List {
            VStack {
                HStack {
                    Spacer(minLength: 0)
                    Image("AppIconDisplay")
                        .resizable()
                        .frame(width: 140, height: 140)
                    Spacer(minLength: 0)
                }
                Text("版本\(version)")
                    .font(.callout.bold())
                    .foregroundStyle(.secondary)

            }
            
            .listRowBackground(Color.clear)
            
//            Section("作者声明") {
//                HStack {
//                    Text("免费")
//                    Spacer(minLength: 0)
//                    Text("支持性内购不影响功能和体验")
//                        .foregroundStyle(.secondary)
//                }
//                
//                HStack {
//                    Text("无广告")
//                    Spacer(minLength: 0)
//                    Text("不添加任何形式的广告")
//                        .foregroundStyle(.secondary)
//                }
//                
//                HStack {
//                    Text("持续更新")
//                    Spacer(minLength: 0)
//                    Text("数据备份及多设备同步")
//                        .foregroundStyle(.secondary)
//                }
//            }
            
            
            Section("后续计划") {
                HStack {
                    Text("数据冲突的解决")
                    Spacer(minLength: 0)
                    Text("工时记录不重叠")
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("更多自定义设置")
                    Spacer(minLength: 0)
                    Text("自动记录、夜班分界")
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("iCloud支持")
                    Spacer(minLength: 0)
                    Text("数据备份及多设备同步")
                        .foregroundStyle(.secondary)
                }
            }

            Section("感谢支持") {
//                Text("感谢使用工时记")
                Text("欢迎任何意见或建议 - wangxinlin525@gmail.com")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("关于工时记")
    }
}

// MARK: - Utilities


#Preview {
    @Previewable @StateObject var userSettings = UserSettings()

    NavigationStack {
        SettingsView()
            .environmentObject(userSettings)
            .environment(\.locale, .init(identifier: "zh-Hans-CN"))
            .modelContainer(for: WorkLogs.self, inMemory: true)
    }
//    
//    AboutView()
}
