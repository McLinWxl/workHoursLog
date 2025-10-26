//
//  LogForm.swift
//  WorkSession
//

import SwiftUI
import SwiftData

struct LogForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Model & mode
    @State private var workLog: WorkLog
    private let isEdit: Bool

    // Editing states
    @State private var baseDay: Date = Calendar.current.startOfDay(for: .now)
    
    @State private var startClock: Date = .now
    @State private var endClock: Date = .now.addingTimeInterval(3600)

    @State private var startTime: Date
    @State private var endTime: Date

    // Day flags
    @State private var isRestDayFlag: Bool
    @State private var isHolidayFlag: Bool

    // UI states
    @State private var askDelete = false
    @State private var revertTask: Task<Void, Never>? = nil
    @State private var showValidation = false

    // Projects
    @Query private var projects: [Project]
    
    @State private var selectedProjectID: UUID?
    private let prefillProjectID: UUID?


    // Payroll preview
    @State private var payPreview: PayrollStatement?
    private let engine = CompensationEngine()

    // MARK: - Init
    


    init(workLog: WorkLog, isEdit: Bool, prefillProjectID: UUID?) {
        self._workLog   = State(initialValue: workLog)
        self.isEdit     = isEdit
        self.prefillProjectID = prefillProjectID

        self._startTime = State(initialValue: workLog.startTime)
        self._endTime   = State(initialValue: workLog.endTime)
        
        let day = Calendar.current.startOfDay(for: workLog.startTime)
        self._baseDay   = State(initialValue: day)
        
//        self._selectedProjectID = State(initialValue: workLog.project?.id)

        // Flags come from model (new-log defaults were injected upstream)
        self._isRestDayFlag   = State(initialValue: workLog.isRestDay)
        self._isHolidayFlag   = State(initialValue: workLog.isHoliday)

        // Query projects (active only)
        let pred = #Predicate<Project> { $0.isArchived == false }
        let sorters = [
            SortDescriptor(\Project.sortOrder, order: .forward),
            SortDescriptor(\Project.createdAt, order: .forward)
        ]
        _projects = Query(filter: pred, sort: sorters)
        if let existing = workLog.project?.id {
            self._selectedProjectID = State(initialValue: existing)
        } else {
            self._selectedProjectID = State(initialValue: prefillProjectID)
        }
        
        
    }

    // MARK: - Computed

    private var isOvernightByClock: Bool {
        let cal = Calendar.current
        let s = cal.dateComponents([.hour, .minute], from: startClock)
        let e = cal.dateComponents([.hour, .minute], from: endClock)
        let sM = (s.hour ?? 0) * 60 + (s.minute ?? 0)
        let eM = (e.hour ?? 0) * 60 + (e.minute ?? 0)
        return eM <= sM
    }

    private var durationSeconds: TimeInterval {
        max(0, endTime.timeIntervalSince(startTime))
    }

    private var durationHM: (h: Int, m: Int) {
        let total = Int(durationSeconds)
        return (total / 3600, (total % 3600) / 60)
    }

    private var selectedProject: Project? {
        guard let id = selectedProjectID else { return nil }
        return projects.first(where: { $0.id == id })
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Project
                Section {
                    ProjectPicker(
                        projects: projects,
                        selectedID: $selectedProjectID,
                        onChange: { prj in
                            workLog.project = prj
                            recomputePayPreview()
                        }
                    )
                }footer: {
                    if selectedProject == nil {
                        Text("未选择项目将以默认统计口径计时，无法计入项目维度的薪资统计。")
                    }
                }

                // MARK: Date & Time
                Section {
                    VStack {
                        DayFlagsPicker(day: baseDay, isRestDay: $isRestDayFlag, isHoliday: $isHolidayFlag, isEdit: isEdit)
                            .onChange(of: isRestDayFlag) { _ in recomputePayPreview() }
                            .onChange(of: isHolidayFlag) { _ in recomputePayPreview() }
                        DatePicker(
                            "选择日期",
                            selection: $baseDay,
                            in: ...Calendar.current.date(byAdding: .day, value: 365, to: Date())!,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .environment(\.locale, .init(identifier: "zh-Hans-CN"))

                        Divider()

                        HStack(alignment: .center) {
                            Text("开始时间")
                                .foregroundStyle(.secondary)
                                .frame(height: 80)
                                .padding(.leading, 10)
                            Spacer(minLength: 0)
                            TimeWheel(date: $startClock)
                                .padding(.trailing, 10)
                        }
                        .offset(y: 10)

                        HStack(alignment: .center) {
                            if isOvernightByClock {
                                HStack {
                                    OvernightBadge()
                                        .offset(x: -8)
                            

                                    Text("结束时间")
                                        .foregroundStyle(.orange)
                                        .padding(.leading, 5)
                                        .offset(x: -15)
                                    Spacer(minLength: 0)
                                }
                            } else {
                                Text("结束时间")
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 10)
                                Spacer(minLength: 0)
                            }
                            TimeWheel(date: $endClock)
                                .padding(.trailing, 15)
                        }
                    }
                    .onAppear(perform: hydrateFromModel)
                    .onChange(of: baseDay) { _ in recomputeDateTimes(); recomputePayPreview() }
                    .onChange(of: startClock) { _ in recomputeDateTimes(); recomputePayPreview() }
                    .onChange(of: endClock) { _ in recomputeDateTimes(); recomputePayPreview() }
                }
                // MARK: Payroll preview
                Section {
                    if let stmt = payPreview, let prj = selectedProject {


                        PayPreviewView(statement: stmt, cfg: prj.payroll)
                    } else {
                        HStack {
                            Image(systemName: "info.circle")
                            Text("选择项目并设置时间后，将显示基于项目策略的计薪预览。")
                            Spacer()
                        }
                        .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("计薪预览")
                } footer: {
                    if selectedProject?.payroll.mode == .comprehensiveHours {
                        Text("提示：综合工时制的“单条记录”预览假定月度额度尚未消耗，最终金额以月度结算为准。")
                    }
                }
            }
            .offset(y: -30)
            .toolbar {
                // Leading
                ToolbarItem(placement: .topBarLeading) {
                    if isEdit {
                        Button {
                            if askDelete {
                                modelContext.delete(workLog)
                                try? modelContext.save()
                                dismiss()
                            } else {
                                askDelete = true
                                scheduleRevertDeleteHint()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: askDelete ? "trash.fill" : "trash")
                                if askDelete { Text("确认删除").font(.subheadline).bold() }
                            }
                        }
                        .tint(.red)
                    } else {
                        Button { dismiss() } label: { Image(systemName: "xmark") }
                    }
                }

                // Trailing
                ToolbarItem(placement: .topBarTrailing) {
                    Button { save() } label: { Image(systemName: "checkmark") }
                        .alert("时间区间无效", isPresented: $showValidation) {
                            Button("确定", role: .cancel) { }
                        } message: {
                            Text("结束时间必须晚于开始时间。")
                        }
                }
            }
            .onDisappear {
                askDelete = false
                revertTask?.cancel()
            }
            .safeAreaInset(edge: .top) {
                TopSummaryBar(date: startTime, duration: durationHM)
            }
        }
    }

    // MARK: - Lifecycle

    private func hydrateFromModel() {
        let cal = Calendar.current
        baseDay    = cal.startOfDay(for: workLog.startTime)
        startClock = workLog.startTime
        endClock   = workLog.endTime
        if let prj = workLog.project { selectedProjectID = prj.id }
        recomputeDateTimes()
        recomputePayPreview()
    }

    private func recomputeDateTimes() {
        let cal = Calendar.current
        startTime = compose(base: baseDay, clock: startClock, cal: cal)
        let endBase = isOvernightByClock ? (cal.date(byAdding: .day, value: 1, to: baseDay) ?? baseDay) : baseDay
        endTime = compose(base: endBase, clock: endClock, cal: cal)
    }

    private func compose(base: Date, clock: Date, cal: Calendar) -> Date {
        let d = cal.dateComponents([.year, .month, .day], from: base)
        let t = cal.dateComponents([.hour, .minute, .second], from: clock)
        var c = DateComponents()
        c.year = d.year; c.month = d.month; c.day = d.day
        c.hour = t.hour; c.minute = t.minute; c.second = t.second ?? 0
        return cal.date(from: c) ?? base
    }

    private func scheduleRevertDeleteHint() {
        revertTask?.cancel()
        revertTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            withAnimation(.snappy) { askDelete = false }
        }
    }

    // MARK: - Save

    private func save() {
        guard endTime > startTime else { showValidation = true; return }

        workLog.startTime = startTime
        workLog.endTime   = endTime
        workLog.isRestDay = isRestDayFlag
        workLog.isHoliday = isHolidayFlag

        // 仅在保存时，把选中的项目写回模型
        if let id = selectedProjectID,
           let prj = projects.first(where: { $0.id == id }) {
            workLog.project = prj
        } else {
            workLog.project = nil
        }

        workLog.touch()

        if !isEdit { modelContext.insert(workLog) }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            assertionFailure("Failed to save WorkLog: \(error)")
            dismiss()
        }
    }

    // MARK: - Payroll recompute

    private func recomputePayPreview() {
        guard let prj = selectedProject, endTime > startTime else {
            payPreview = nil
            return
        }
        // Temporary log carrying explicit flags; not inserted.
        let temp = WorkLog(startTime: startTime,
                           endTime: endTime,
                           syncID: workLog.syncID)
        temp.isRestDay = isRestDayFlag
        temp.isHoliday = isHolidayFlag

        let interval = DateInterval(start: startTime, end: endTime)
        payPreview = engine.computeStatement(logs: [temp], period: interval, cfg: prj.payroll)
    }
}

// MARK: - Project Picker

fileprivate struct ProjectPicker: View {
    let projects: [Project]
    @Binding var selectedID: UUID?
    var onChange: (Project?) -> Void

    var body: some View {
        Picker("选择项目", selection: Binding<UUID?>(
            get: { selectedID },
            set: { newID in
                selectedID = newID
                onChange(projects.first(where: { $0.id == newID }))
            })
        ) {
            Text("未选择").tag(UUID?.none)
            ForEach(projects, id: \.id) { prj in
                HStack(spacing: 6) {
//                    if let emoji = prj.emojiTag { Text(emoji) }
                    Text(prj.name)
                }
                .tag(Optional.some(prj.id))
            }
        }
    }
}

// MARK: - Day flags

fileprivate enum DayKind: String, CaseIterable, Identifiable {
    case workday, restDay, holiday
    var id: String { rawValue }
}

fileprivate struct DayFlagsPicker: View {
    let day: Date                       // ← 传入所选日期（用于默认值）
    let isEdit: Bool
    @Binding var isRestDay: Bool
    @Binding var isHoliday: Bool

    @State private var selection: DayKind
    @State private var userOverridden = false

    // Init derives initial selection from flags; if both false, fallback by weekend rule
    init(day: Date, isRestDay: Binding<Bool>, isHoliday: Binding<Bool>, isEdit: Bool) {
        self.day = day
        self._isRestDay = isRestDay
        self._isHoliday = isHoliday
        self.isEdit = isEdit
        var initial = Self.deriveSelection(day: day,
                                           isRest: isRestDay.wrappedValue,
                                           isHoliday: isHoliday.wrappedValue)
        if isEdit {
            initial = DayFlagsPicker.fromFlags(isRest: isRestDay.wrappedValue,
                                               isHoliday: isHoliday.wrappedValue)
        } else {
            let wd = Calendar.current.component(.weekday, from: day) // 1=Sun ... 7=Sat
            let isWeekend = (wd == 1 || wd == 7)
            
            initial = DayFlagsPicker.defaultForCreate(day: day)
        }
        _selection = State(initialValue: initial)
        
    }

    var body: some View {
        Picker("日期标记", selection: $selection) {
            Text("工作日").tag(DayKind.workday)
            Text("休息日").tag(DayKind.restDay)
            Text("节假日").tag(DayKind.holiday)
        }
        .pickerStyle(.segmented)
        .pickerStyle(.segmented)
        // 用户显式选择 → 锁定（不再应用任何默认）
        .onChange(of: selection) { newValue in
            userOverridden = true
            writeFlags(from: newValue)
        }
        // 日期变化时：
        // - Create 且用户尚未手动改动 → 根据新日期再给一次默认
        // - Edit 或用户已改动 → 不动
        .onChange(of: day) { _ in
            guard !isEdit, userOverridden == false else { return }
            selection = DayFlagsPicker.defaultForCreate(day: day)
            writeFlags(from: selection)
        }
        // 首次渲染时，同步一次当前 selection 到 flags，避免外部与内部不一致
        .onAppear {
            writeFlags(from: selection)
        }
    }

    // Weekend fallback only for defaulting; NOT used in computation
    private static func deriveSelection(day: Date, isRest: Bool, isHoliday: Bool) -> DayKind {
        if isHoliday { return .holiday }
        if isRest    { return .restDay }
        // both false → default by weekend
        let wd = Calendar.current.component(.weekday, from: day) // 1=Sun ... 7=Sat
        let isWeekend = (wd == 1 || wd == 7)
        return isWeekend ? .restDay : .workday
    }
    
    
    private func writeFlags(from kind: DayKind) {
        switch kind {
        case .workday: isHoliday = false; isRestDay = false
        case .restDay: isHoliday = false; isRestDay = true
        case .holiday: isHoliday = true;  isRestDay = false
        }
    }

    /// Edit：仅按已有标记，不做周末推断
    private static func fromFlags(isRest: Bool, isHoliday: Bool) -> DayKind {
        if isHoliday { return .holiday }
        if isRest    { return .restDay }
        return .workday
    }

    /// Create：若无标记，则按“周末休息、工作日工作”给一次性默认
    private static func defaultForCreate(day: Date) -> DayKind {
//        if isHoliday { return .holiday }
//        if isRest    { return .restDay }
        let wd = Calendar.current.component(.weekday, from: day) // 1=Sun ... 7=Sat
        let isWeekend = (wd == 1 || wd == 7)
        return isWeekend ? .restDay : .workday
    }
}
// MARK: - Pay preview

fileprivate struct PayPreviewView: View {
    let statement: PayrollStatement
    let cfg: PayrollConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading) {
                    Text("本次合计").font(.caption).foregroundStyle(.secondary)
                    Text(statement.amountTotal, format: .currency(code: "CNY")).font(.title3).fontWeight(.bold)
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text("基础时薪").font(.caption).foregroundStyle(.secondary)
                    Text(cfg.rateTable.basePerHour, format: .currency(code: "CNY")).font(.title3).fontWeight(.bold)
                }
            }
            Divider()
            Grid(horizontalSpacing: 12, verticalSpacing: 8) {
                row("正班收入", hours: statement.hours.regular, amount: statement.amountRegular)
                row("工作日加班 ×\(String(format: "%.1f ", cfg.rateTable.multipliers.workday))",
                    hours: statement.hours.workdayOT, amount: statement.amountWorkdayOT)
                row("休息日加班 ×\(String(format: "%.1f ", cfg.rateTable.multipliers.restDay))",
                    hours: statement.hours.restDayOT, amount: statement.amountRestDayOT)
                row("节假日加班 ×\(String(format: "%.1f ", cfg.rateTable.multipliers.holiday))",
                    hours: statement.hours.holidayOT, amount: statement.amountHolidayOT)
            }
        }
    }

    private func row(_ title: String, hours: Double, amount: Decimal) -> some View {
        GridRow {
            Text(title).gridColumnAlignment(.leading)
            Spacer(minLength: 0)
            Text(String(format: "%.1f 小时", hours))
                .padding(.horizontal)
            Text(amount, format: .currency(code: "CNY")).fontWeight(.semibold)
                .gridColumnAlignment(.leading)
        }
    }

//    private func currency(_ v: Decimal) -> String {
//        String(format: "¥%.2f", v)
//    }
}

// MARK: - Visual atoms

private struct TopSummaryBar: View {
    let date: Date
    let duration: (h: Int, m: Int)

    var body: some View {
        ZStack {
            Rectangle()
                .frame(maxWidth: .infinity, maxHeight: 50)
                .opacity(0)
                .glassEffect(in: .rect(cornerRadius: 25))
            HStack {
                Text(date, format: .dateTime.year().month().day())
                    .foregroundStyle(.secondary)
                    .offset(x: 20)
                Spacer(minLength: 0)
                Text("\(duration.h) 小时 \(duration.m) 分钟 ")
                    .font(.title2).fontWeight(.bold)
                    .foregroundStyle(.orange)
                    .offset(x: -20)
            }
        }
        .padding(EdgeInsets(top: 10, leading: 17, bottom: 0, trailing: 17))
    }
}

private struct OvernightBadge: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [.orange, .yellow, .orange]),
                        center: .center
                    ),
                    lineWidth: 2
                )
                .frame(width: 15, height: 15)
                .shadow(color: .orange.opacity(0.2), radius: 1)
            Image(systemName: "moon.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.orange)
        }
        .padding(.leading, 4)
    }
}

struct TimeWheel: View {
    @Binding var date: Date
    private let hours = Array(0...23)
    private let minutes = Array(0...59)

    var body: some View {
        let cal = Calendar.current
        let h = cal.component(.hour, from: date)
        let m = cal.component(.minute, from: date)

        ZStack {
            HStack(spacing: 10) {
                Picker("", selection: Binding(
                    get: { h },
                    set: { newH in
                        date = cal.date(bySettingHour: newH, minute: m, second: 0, of: date) ?? date
                    })) {
                    ForEach(hours, id: \.self) { Text(String(format: "%02d", $0)) }
                }
                .frame(width: 95, height: 90)
                .clipped()
                .pickerStyle(.wheel)

                Picker("", selection: Binding(
                    get: { m },
                    set: { newM in
                        date = cal.date(bySettingHour: h, minute: newM, second: 0, of: date) ?? date
                    })) {
                    ForEach(minutes, id: \.self) { Text(String(format: "%02d", $0)) }
                }
                .frame(width: 95, height: 90)
                .clipped()
                .pickerStyle(.wheel)
            }
            .labelsHidden()
            Text(":").font(.title2).monospaced()
        }
    }
}

// MARK: - Preview

#Preview("New Log • Prefilled Project") {
    LogFormPreviewNew()
}

#Preview("Edit Log • Existing Project") {
    LogFormPreviewEdit()
}

// MARK: - Preview Hosts

private struct LogFormPreviewNew: View {
    let container: ModelContainer
    let draft: WorkLog
    let prefillProjectID: UUID

    init() {
        // Build in-memory container & seed data
        container = PreviewSeed.container()
        let ctx = ModelContext(container)

        // 1) Seed a sample project
        let project = Project(
            name: "Assembly A",
            colorTag: "#7B61FF",
            payroll: PayrollConfig(
                mode: .standardHours,
                periodKind: .monthly,
                dailyRegularHours: 8,
                hoursPerWorkday: 8,
                rateTable: .demo
            )
        )
        ctx.insert(project)

        // 2) Create a NEW draft log (do NOT attach project here)
        draft = WorkLog(
            startTime: Date().addingTimeInterval(-2 * 3600),
            endTime:   Date(),
            
            isRestDay: false,
            isHoliday: false,
            syncID:    UUID(),
        )

        try? ctx.save()

        // 3) Only pass default project ID to the form (no relationship yet)
        prefillProjectID = project.id
    }

    var body: some View {
        LogForm(workLog: draft, isEdit: false, prefillProjectID: prefillProjectID)
            .modelContainer(container)
            .environment(\.locale, .init(identifier: "zh-Hans-CN"))
    }
}

private struct LogFormPreviewEdit: View {
    let container: ModelContainer
    let existing: WorkLog

    init() {
        container = PreviewSeed.container()
        let ctx = ModelContext(container)

        // 1) Seed a sample project
        let project = Project(
            name: "Assembly A",
            colorTag: "#7B61FF",
            payroll: PayrollConfig(
                mode: .standardHours,
                periodKind: .monthly,
                dailyRegularHours: 8,
                hoursPerWorkday: 8,
                rateTable: .demo
            )
        )
        ctx.insert(project)

        // 2) Seed an EXISTING log and attach the project (safe: both are managed)
        existing = WorkLog(
            startTime: Date().addingTimeInterval(-3 * 3600),
            endTime:   Date(),
            
            isRestDay: false,
            isHoliday: false,
            syncID:    UUID(),
        )
        ctx.insert(existing)
        existing.project = project

        try? ctx.save()
    }

    var body: some View {
        LogForm(workLog: existing, isEdit: true, prefillProjectID: nil)
            .modelContainer(container)
            .environment(\.locale, .init(identifier: "zh-Hans-CN"))
    }
}
