//
//  SettingsView.swift
//  WorkSession
//
//  Updated for struct-based PayrollConfig on 2025/10/25
//

import SwiftUI
import SwiftData

// MARK: - Alert model

struct AlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

// MARK: - Root Settings

struct SettingsView: View {
    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var modelStore: ModelStore
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var systemScheme

    // Logs & Projects
    @Query(sort: [SortDescriptor(\WorkLog.startTime, order: .forward)])
    private var allLogs: [WorkLog]
    @Query(sort: [SortDescriptor(\Project.sortOrder), SortDescriptor(\Project.createdAt)])
    private var projects: [Project]

    @State private var showNewProject = false
    @State private var editingProject: Project?
    @State private var alertItem: AlertItem?
    
    @State private var payrollDraft: PayrollConfig = PayrollConfig(
        mode: .standardHours,
        periodKind: .monthly,
        dailyRegularHours: 8,
        hoursPerWorkday: 8,
        rateTable: .demo
    )
    
    @State private var hasUnsavedChanges = false
    @State private var justSaved = false

    // Aggregates
    private var recordedDays: Int {
        Set(allLogs.map { $0.startTime.startOfDay }).count
    }
    private var totalHoursText: String {
        let hours = allLogs.reduce(0) { $0 + max(0, $1.endTime.timeIntervalSince($1.startTime))/3600 }
        return String(format: "%.1f", hours)
    }

    var body: some View {
        NavigationStack {
            
            Form {
                
                Section {
                    HStack(spacing: 8) {
                        StatCard(title: "记录", value: "\(recordedDays)天")
                        Spacer(minLength: 0)
                        StatCard(title: "总计工时", value: "\(totalHoursText) 小时")
                    }
                    .listRowBackground(Color.clear) // 去掉背景
                    .listRowInsets(EdgeInsets())    // 去掉内边距
                }
                .scrollContentBackground(.hidden)   // 隐藏整个 Form 的底色
                .background(Color.clear)
                // Dashboard
                

                // Appearance
                Section("显示外观") {
                    Picker("外观", selection: $settings.theme) {
                        ForEach(UserSettings.Theme.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                // Sync
                Section("数据同步") {
                    Toggle(isOn: Binding(
                        get: { settings.iCloudSyncEnabled },
                        set: { newValue in Task { await toggleCloud(newValue) } }
                    )) {
                        Label("iCloud 同步", systemImage: "cloud")
                    }
                }

                // Defaults
                Section {
                    DatePicker("默认开始时间", selection: $settings.defaultStart, displayedComponents: .hourAndMinute)
                    DatePicker("默认结束时间", selection: $settings.defaultEnd, displayedComponents: .hourAndMinute)
                } header: {
                    Text("记录偏好")
                } footer: {
                    Text("若结束时间早于或等于开始时间，则视为跨日记录。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                // Projects + Payroll
                Section {
                    HStack {
                        Label("项目与计薪", systemImage: "briefcase.fill")
                        Spacer()
                        Button {
                            showNewProject = true
                        } label: {
                            Label("新建项目", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.borderless)
                    }
                    ProjectList(
                        projects: projects,
                        onEdit: { editingProject = $0 },
                        onToggleArchive: toggleArchive(_:),
                        onDelete: deleteProject(_:)
                    )
                    
                    Picker("默认项目", selection: Binding<UUID?>(
                        get: { settings.defaultProjectID },
                        set: { settings.defaultProjectID = $0 }
                    )) {
                        Text("无").tag(UUID?.none)
                        ForEach(projects.filter { !$0.isArchived }, id: \.id) { prj in
                            HStack(spacing: 6) {
                                Text(prj.name)
                            }
                            .tag(Optional.some(prj.id))
                        }
                    }
                } header: {
                    Text("项目与薪酬策略")
                } footer: {
                    Text("新建工时记录时，采用默认项目。如项目未选定或被删除，则自动替补为列表首相（如有）。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                
                
                // Default payroll configuration for unassigned logs
                Section(header: Text("默认计薪策略"),
                        footer: Text("用于未绑定项目的记录。若不设置，未分配项目的记录不会计入收入统计。")
                            .font(.footnote).foregroundStyle(.secondary)
                ) {

                    Picker("工作制度", selection: $payrollDraft.mode) {
                        
                        ForEach(WorkMode.allCases) { m in
                            Text(label(for: m)).tag(m)
                        }
                        
                    }

                    // 工时阈值
                    if payrollDraft.mode == .standardHours {
                        Stepper(value: $payrollDraft.dailyRegularHours, in: 0...24, step: 0.5) {
                            HStack {
                                Text("每日工时")
                                Spacer()
                                Text(String(format: "%.1f 小时", payrollDraft.dailyRegularHours))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if payrollDraft.mode == .comprehensiveHours {
                        Stepper(value: $payrollDraft.hoursPerWorkday, in: 0...24, step: 0.5) {
                            HStack {
                                Text("日均工时")
                                Spacer()
                                Text(String(format: "%.1f 小时/天", payrollDraft.hoursPerWorkday))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // 基础时薪与倍数
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("基础时薪")
                            Spacer()
                            TextField("¥", value: $payrollDraft.rateTable.basePerHour, format: .number)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                                .frame(width: 80)
                                .textFieldStyle(.roundedBorder)
                                .submitLabel(.done)
                                .onSubmit { hideKeyboard() }
//                                .toolbar {
//                                    ToolbarItemGroup(placement: .bottomBar) {
//                                        Spacer()
//                                        Button("完成") { hideKeyboard() }
//                                    }
//                                }
                            Text("元/小时")
                                .foregroundStyle(.secondary)
                        }

                        Divider().padding(.vertical, 4)

                        Group {
                            HStack {
                                Text("工作日加班倍数")
                                Spacer()
                                Stepper(value: $payrollDraft.rateTable.multipliers.workday, in: 1...5, step: 0.1) {
                                    Text(String(format: "×%.1f", payrollDraft.rateTable.multipliers.workday))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical,5)

                            HStack {
                                Text("休息日加班倍数")
                                Spacer()
                                Stepper(value: $payrollDraft.rateTable.multipliers.restDay, in: 1...5, step: 0.1) {
                                    Text(String(format: "×%.1f", payrollDraft.rateTable.multipliers.restDay))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical,5)

                            HStack {
                                Text("节假日加班倍数")
                                Spacer()
                                Stepper(value: $payrollDraft.rateTable.multipliers.holiday, in: 1...5, step: 0.1) {
                                    Text(String(format: "×%.1f", payrollDraft.rateTable.multipliers.holiday))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical,5)
                        }
                    }
                    // Actions
                    HStack {
                        Button("重置策略") {
                            payrollDraft.rateTable = .demo
                            payrollDraft.mode = .standardHours
                            payrollDraft.dailyRegularHours = 8
                            payrollDraft.hoursPerWorkday = 8
                            hasUnsavedChanges = true
                            justSaved = false
                        }
                        Spacer()
                        
                        Button(justSaved ? "已保存" : "请保存") {
                            settings.defaultPayroll = payrollDraft
                            hasUnsavedChanges = false
                            justSaved = true
                            // “已保存”状态 2 秒后自动恢复为“保存”
//                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
//                                justSaved = false
//                            }
                        }
                        .disabled(!hasUnsavedChanges)

                        .buttonStyle(.borderedProminent)
                    }
                    .onChange(of: payrollDraft) { _ in
                        hasUnsavedChanges = true
                        justSaved = false
                    }
                }
                .onAppear {
                    // Hydrate draft from settings if present
                    if let cfg = settings.defaultPayroll { payrollDraft = cfg }
                }

                // About
                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("关于工时记", systemImage: "info.circle.fill")
                    }
                }
            }
            .navigationTitle("设置")
        }
        // New project
        .sheet(isPresented: $showNewProject) {
            NavigationStack {
                ProjectEditor(
                    project: nil,
                    onCancel: { showNewProject = false },
                    onSave: { prj in
                        modelContext.insert(prj)
                        try? modelContext.save()
                        showNewProject = false
                    }
                )
            }
        }
        // Edit existing project
        .sheet(item: $editingProject) { prj in
            NavigationStack {
                ProjectEditor(
                    project: prj,
                    onCancel: { editingProject = nil },
                    onSave: { updated in
                        // Write back edited value fields
                        prj.name        = updated.name
                        prj.emojiTag    = updated.emojiTag
                        prj.colorTag    = updated.colorTag
                        prj.isArchived  = updated.isArchived
                        prj.sortOrder   = updated.sortOrder
                        prj.payroll     = updated.payroll
                        try? modelContext.save()
                        editingProject = nil
                    }
                )
            }
        }
        .alert(item: $alertItem) { a in
            Alert(title: Text(a.title), message: Text(a.message), dismissButton: .default(Text("确定")))
        }
        .preferredColorScheme(settings.theme.colorScheme)
    }

    private func label(for mode: WorkMode) -> String {
        switch mode {
//        case .fixedSalary:        return "固定薪资（仅统计）"
        case .standardHours:      return "标准工时（按日阈值）"
        case .comprehensiveHours: return "综合工时（按月额度）"
        }
    }
    
    // MARK: - Actions

    @MainActor
    private func toggleCloud(_ on: Bool) async {
        do {
            try modelContext.save()
            let old = modelContext.autosaveEnabled
            modelContext.autosaveEnabled = false
            defer { modelContext.autosaveEnabled = old }
            try await modelStore.switchCloud(to: on)
            settings.iCloudSyncEnabled = on
        } catch {
            alertItem = .init(title: "切换失败", message: error.localizedDescription)
        }
    }

    private func toggleArchive(_ p: Project) {
        p.isArchived.toggle()
        try? modelContext.save()
    }

    private func deleteProject(_ p: Project) {
        // Consider integrity rules before actual deletion.
        modelContext.delete(p)
        try? modelContext.save()
    }

    private var schemeDescription: String {
        switch settings.theme {
        case .system: return systemScheme == .dark ? "深色（跟随系统）" : "浅色（跟随系统）"
        case .light:  return "浅色"
        case .dark:   return "深色"
        }
    }
}

// MARK: - Project List

fileprivate struct ProjectList: View {
    let projects: [Project]
    let onEdit: (Project) -> Void
    let onToggleArchive: (Project) -> Void
    let onDelete: (Project) -> Void

    var body: some View {
        ForEach(projects) { prj in
            HStack(spacing: 10) {
                ProjectBadge(colorHex: prj.colorTag, emoji: prj.emojiTag)
                VStack(alignment: .leading, spacing: 4) {
                    Text(prj.name).font(.headline)
                    Text(summary(for: prj.payroll))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if prj.isArchived {
                    Text("已归档")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.thinMaterial, in: Capsule())
                }
                Menu {
                    Button("编辑") { onEdit(prj) }
                    Button(prj.isArchived ? "取消归档" : "归档") { onToggleArchive(prj) }
                    Divider()
                    Button("删除", role: .destructive) { onDelete(prj) }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func summary(for cfg: PayrollConfig) -> String {
        let mode: String = {
            switch cfg.mode {
//            case .fixedSalary:        return "固定薪"
            case .standardHours:      return "标准工时"
            case .comprehensiveHours: return "综合工时"
            }
        }()
        let m = cfg.rateTable.multipliers
        return String(
            format: "%@ · %.2f元/小时\n倍率: 工作日×%.2f 休息日×%.2f 法定×%.2f",
            mode, cfg.rateTable.basePerHour, m.workday, m.restDay, m.holiday
        )
    }
}

fileprivate struct ProjectBadge: View {
    let colorHex: String?
    let emoji: String?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: colorHex ?? "#7B61FF").opacity(0.15))
                .frame(width: 38, height: 38)
            Text(emoji ?? "🗂️")
                .font(.title3)
        }
    }
}

// MARK: - Project Editor
/// Editor builds a value-type draft; when saving, caller persists (insert/update).

fileprivate struct ProjectEditor: View {
    @Environment(\.dismiss) private var dismiss

    // Value draft (decoupled from SwiftData until onSave)
    @State private var draft: ProjectValueDraft

    let onCancel: () -> Void
    let onSave: (Project) -> Void

    init(project: Project?, onCancel: @escaping () -> Void, onSave: @escaping (Project) -> Void) {
        if let p = project {
            _draft = State(initialValue: .from(project: p))
        } else {
            _draft = State(initialValue: .new())
        }
        self.onCancel = onCancel
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section("基本信息") {
                TextField("项目名称", text: $draft.name)
                EmojiField(title: "图标", text: $draft.emojiTag)


                    ColorPicker(
                        "颜色",
                        selection: Binding(
                            get: { Color(hex: draft.colorTag)},
                            set: { draft.colorTag = $0.hexRGBString() }
                        ),
                        supportsOpacity: false // 仅存 RGB；若要 A 通道请改为 true 并用 ARGB 方法
                    )
                

                Toggle("归档", isOn: $draft.isArchived)
            }

            Section("计薪策略") {
                PayrollConfigForm(config: $draft.payroll)
            }
        }
        .navigationTitle(draft.name.isEmpty ? "新建项目" : "编辑项目")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("取消") { onCancel() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("保存") {
                    guard !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    let prj = draft.materialize()
                    onSave(prj)
                }
                .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

// Value draft bridging SwiftData @Model <-> struct PayrollConfig
fileprivate struct ProjectValueDraft {
    var name: String
    var emojiTag: String
    var colorTag: String
    var isArchived: Bool
    var sortOrder: Int
    var payroll: PayrollConfig

    static func new() -> Self {
        .init(name: "",
              emojiTag: "",
              colorTag: "#7B61FF",
              isArchived: false,
              sortOrder: 0,
              payroll: PayrollConfig(mode: .standardHours,
                                     periodKind: .monthly,
                                     dailyRegularHours: 8,
                                     hoursPerWorkday: 8,
                                     rateTable: .demo))
    }

    static func from(project p: Project) -> Self {
        .init(name: p.name,
              emojiTag: p.emojiTag ?? "",
              colorTag: p.colorTag ?? "#7B61FF",
              isArchived: p.isArchived,
              sortOrder: p.sortOrder,
              payroll: p.payroll)
    }

    func materialize() -> Project {
        let prj = Project(name: name,
                          colorTag: colorTag,
                          payroll: payroll)
        prj.emojiTag   = emojiTag.isEmpty ? nil : emojiTag
        prj.isArchived = isArchived
        prj.sortOrder  = sortOrder
        return prj
    }
}

// MARK: - Payroll Config Form (struct-based)

fileprivate struct PayrollConfigForm: View {
    @Binding var config: PayrollConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("工作制", selection: $config.mode) {
//                Text("固定薪").tag(WorkMode.fixedSalary)
                Text("标准工时").tag(WorkMode.standardHours)
                Text("综合工时").tag(WorkMode.comprehensiveHours)
            }
            .pickerStyle(.segmented)

            // Shared rate table
            RateTableSection(rate: $config.rateTable)

            // Mode-specific knobs
            Group {
                if config.mode == .standardHours {
                    Stepper(value: $config.dailyRegularHours, in: 0...24, step: 0.5) {
                        Text("单日常规工时：\(fmtH(config.dailyRegularHours)) 小时")
                    }
                } else if config.mode == .comprehensiveHours {
                    Stepper(value: $config.hoursPerWorkday, in: 0...24, step: 0.5) {
                        Text("工作日认定：\(fmtH(config.hoursPerWorkday)) 小时/日")
                    }
                    Text("综合工时：加班在结算周期（月）统一评估。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("固定薪：不计算加班，记录仅用于统计。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            
        }
    }

    private func fmtH(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", v) : String(format: "%.1f", v)
    }
}

fileprivate struct RateTableSection: View {
    @Binding var rate: RateTable

    var body: some View {
        Section {
            HStack {
                Text("基础时薪")
                Spacer()
                TextField("¥", value: $rate.basePerHour, format: .number)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .frame(width: 80)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .onSubmit { hideKeyboard() }
//                    .toolbar {
//                        ToolbarItemGroup(placement: .bottomBar) {
//                            Spacer()
//                            Button("完成") { hideKeyboard() }
//                        }
//                    }
                Text("元/小时")
                    .foregroundStyle(.secondary)
            }
            
            Group {
                HStack {
                    Text("工作日加班倍数")
                    Spacer()
                    Stepper(value: $rate.multipliers.workday, in: 1...5, step: 0.1) {
                        Text(String(format: "×%.1f", rate.multipliers.workday))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical,5)
                
                HStack {
                    Text("休息日加班倍数")
                    Spacer()
                    Stepper(value: $rate.multipliers.restDay, in: 1...5, step: 0.1) {
                        Text(String(format: "×%.1f", rate.multipliers.restDay))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical,5)
                
                HStack {
                    Text("节假日加班倍数")
                    Spacer()
                    Stepper(value: $rate.multipliers.holiday, in: 1...5, step: 0.1) {
                        Text(String(format: "×%.1f", rate.multipliers.holiday))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical,5)
            }
        } header: {
            Text("计薪与倍率")
        }
    }
}

fileprivate struct MultiplierField: View {
    let title: String
    @Binding var value: Double
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("×", value: $value, formatter: decimalFormatter)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 120)
        }
    }
}

// MARK: - Small Inputs

fileprivate struct EmojiField: View {
    let title: String
    @Binding var text: String
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("如：🛠️", text: $text)
                .multilineTextAlignment(.trailing)
                .frame(width: 140)
        }
    }
}

fileprivate struct ColorHexField: View {
    let title: String
    @Binding var hex: String
    var body: some View {
        HStack(spacing: 10) {
            Text(title)
            Spacer()
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(hex: hex))
                .frame(width: 26, height: 26)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3)))
            TextField("#RRGGBB", text: $hex)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .multilineTextAlignment(.trailing)
                .frame(width: 120)
        }
    }
}

// MARK: - Components

fileprivate struct StatCard: View {
    let title: String
    let value: String

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading) {
            Text(value).font(.title2.bold())
            Spacer(minLength: 0)
            Text(title).font(.footnote).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 27).fill(scheme == .dark ? Color.gray.opacity(0.22) : .white))
    }
}

// MARK: - About

struct AboutView: View {
    
    @Environment(\.colorScheme) private var systemScheme

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
    }
    var body: some View {
        List {
            VStack {
                HStack {
                    Spacer(minLength: 0)
                    if systemScheme == .dark {
                        Image("AppIconDisplayDark").resizable().frame(width: 118, height: 150)
                    } else {
                        Image("AppIconDisplay").resizable().frame(width: 118, height: 150)
                    }
                    Spacer(minLength: 0)
                }
                
                Text("版本\(version)").font(.callout.bold()).foregroundStyle(.secondary)
            }
            .listRowBackground(Color.clear)
            Section("感谢支持") {
                Text("欢迎任何意见或建议 - wangxinlin525@gmail.com").font(.footnote).foregroundStyle(.secondary)
                Text("开源地址：https://github.com/McLinWxl/workHoursLog").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("关于工时记")
    }
}

fileprivate let decimalFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.minimumFractionDigits = 0
    f.maximumFractionDigits = 2
    return f
}()

fileprivate extension Color {
    init(hex: String) {
        // Accept "#RRGGBB" or "RRGGBB"
        let s = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var hexNumber: UInt64 = 0
        let ok = Scanner(string: s).scanHexInt64(&hexNumber)
        let r, g, b: Double
        if ok && s.count == 6 {
            r = Double((hexNumber & 0xFF0000) >> 16) / 255
            g = Double((hexNumber & 0x00FF00) >> 8) / 255
            b = Double(hexNumber & 0x0000FF) / 255
        } else {
            r = 0.48; g = 0.38; b = 1.0
        }
        self = Color(red: r, green: g, blue: b)
    }
}
// MARK: - Preview

#Preview {
    @Previewable @StateObject var userSettings = UserSettings()

    NavigationStack {
        SettingsView()
            .environmentObject(userSettings)
            .environment(\.locale, .init(identifier: "zh-Hans-CN"))
            .modelContainer(for: WorkLog.self, inMemory: true)
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}


fileprivate extension Color {
    /// Create a Color from a "#RRGGBB" or "RRGGBBAA" hex string.
    init?(hexRGB: String) {
        let hex = hexRGB.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard let intVal = Int(hex, radix: 16) else { return nil }

        let r, g, b, a: Double
        switch hex.count {
        case 6:
            (r, g, b, a) = (
                Double((intVal >> 16) & 0xFF) / 255.0,
                Double((intVal >> 8) & 0xFF) / 255.0,
                Double(intVal & 0xFF) / 255.0,
                1.0
            )
        case 8:
            (r, g, b, a) = (
                Double((intVal >> 24) & 0xFF) / 255.0,
                Double((intVal >> 16) & 0xFF) / 255.0,
                Double((intVal >> 8) & 0xFF) / 255.0,
                Double(intVal & 0xFF) / 255.0
            )
        default:
            return nil
        }
        self.init(red: r, green: g, blue: b, opacity: a)
    }

    /// Convert Color to "#RRGGBB"
    func hexRGBString() -> String {
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        #elseif canImport(AppKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
        NSColor(self).usingColorSpace(.deviceRGB)?
            .getRed(&r, green: &g, blue: &b, alpha: &a)
        #endif

        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
