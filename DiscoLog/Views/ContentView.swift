//
//  ContentView.swift
//  WorkSession
//
//

import SwiftUI
import SwiftData

struct ContentView: View {
    // Prefer a single ascending query for lightweight emptiness checks.
    @Query(sort: [SortDescriptor(\WorkLog.startTime, order: .forward)])
    private var logs: [WorkLog]

    @State private var selectedTab: Int = 0
    @State private var modal: ModalType?

    var body: some View {
        TabView(selection: $selectedTab) {

            // MARK: Tab 0 - Calendar
            Tab("工时记录", systemImage: "calendar.day.timeline.leading", value: 0) {
                if logs.isEmpty {
                    EmptyStateView(
                        title: "当前没有工时记录",
                        message: "点击下方按钮快速创建你的第一条记录。",
                        actionTitle: "新增记录",
                        action: { modal = .addLog(defaultDate: Date()) }
                    )
                } else {
                    CalendarCardTab()
                }
            }

            // MARK: Tab 1 - Statistics
//            Tab("工时统计", systemImage: "chart.xyaxis.line", value: 1) {
//                if logs.isEmpty {
//                    EmptyStateView(
//                        title: "暂无可统计的数据",
//                        message: "添加至少一条工时记录后即可查看统计。",
//                        actionTitle: "新增记录",
//                        action: { modal = .addLog(defaultDate: Date()) }
//                    )
//                } else {
//                    StaticView()
//                }
//            }

            // MARK: Tab 2 - Settings
            Tab("Settings", systemImage: "gear", value: 2, role: .search) {
                SettingsView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        // Single modal host at the root
        .sheet(item: $modal) { sheet in
            ModalSheetView(modal: sheet)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Reusable Empty State

private struct EmptyStateView: View {
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)
            Image(systemName: "tray")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .padding(.top, 6)
                .glassEffect()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}

// MARK: - Preview

#Preview {
    @Previewable @StateObject var userSettings = UserSettings()
    @Previewable var previewContainer = PreviewSeed.container()
    @Previewable var store = try? ModelStore(cloudEnabled: false)

    NavigationStack {
        ContentView()
            .environmentObject(userSettings)
            .preferredColorScheme(userSettings.theme.colorScheme)
            .environment(\.locale, .init(identifier: "zh-Hans-CN"))
    }
    .modelContainer(previewContainer)
}
