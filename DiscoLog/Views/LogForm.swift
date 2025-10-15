//
//  LogForm.swift
//  DiscoLog
//
//  Created by McLin on 2025/10/13.
//

import SwiftUI
import SwiftData

struct LogForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State var workLog: WorkLogs
    @State var isEdit: Bool
    
    @State private var startTime_: Date
    @State private var endTime_: Date
    
    @State private var baseDate: Date = Calendar.current.startOfDay(for: .now)
    
    @State private var startClock: Date = .now
    @State private var endClock: Date = .now.addingTimeInterval(3600)
    
    @State private var askDelete = false
    @State private var revertTask: Task<Void, Never>? = nil
    
     private var isOvernight: Bool {
         let cal = Calendar.current
         let s = cal.dateComponents([.hour, .minute], from: startClock)
         let e = cal.dateComponents([.hour, .minute], from: endClock)
         let sMins = (s.hour ?? 0) * 60 + (s.minute ?? 0)
         let eMins = (e.hour ?? 0) * 60 + (e.minute ?? 0)
         return eMins <= sMins
     }
    

    init(workLog: WorkLogs, isEdit: Bool) {
        self.workLog = workLog
        self.isEdit = isEdit
        self.startTime_ = workLog.startTime
        self.endTime_ = workLog.endTime
    }
    
    var body: some View {
        let workDurations = endTime_.timeIntervalSince(startTime_)
        let workDurationsOfHour = Int(workDurations / 3600)
        let workDurationsOfMinutes = (Int(workDurations) % 3600) / 60

        NavigationStack {
            Form {
                VStack {
                    DatePicker("选择日期", selection: $baseDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .environment(\.locale, .init(identifier: "zh-Hans-CN"))
                    
                    Divider()
                    
                    HStack (alignment: .center) {
                        Text("开始时间")
                            .foregroundStyle(.secondary)
                            .frame(height: 80)
                            .padding(.leading, 20)
                        Spacer(minLength: 0)
                        TimeWheel(date: $startClock)
                            .padding(.trailing, 15)
                    }
                    .offset(y: 10)
                    
                    HStack (alignment: .center) {
                        if isOvernight {
                            HStack{
                                OvernightBadge()
                                Text("结束时间")
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 15)
                                    .offset(x: -15)
                                Spacer(minLength: 0)
                            }
                            
                        } else {
                            Text("结束时间")
                                .foregroundStyle(.secondary)
                                .padding(.leading, 20)
                            Spacer(minLength: 0)
                        }
                        
                        TimeWheel(date: $endClock)
                            .padding(.trailing, 15)
                    }
                }
                .onAppear {
                    baseDate   = Calendar.current.startOfDay(for: startTime_)
                    startClock = startTime_
                    endClock   = endTime_
                    recompute()
                }
                .onChange(of: baseDate) { recompute() }
                .onChange(of: startClock) {  recompute() }
                .onChange(of: endClock) { recompute() }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isEdit {
                        Button {
                            if askDelete {
                                modelContext.delete(workLog)
                                try? modelContext.save()
                                dismiss()
                            } else {
                                askDelete = true
//                                withAnimation(.bouncy) { askDelete = true }
                                scheduleRevertIfNeeded()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: askDelete ? "trash.fill" : "trash")
                                if askDelete {
                                    Text("确认删除")
                                        .font(.subheadline)
                                        .bold()
                                }
                            }
                        }
                        .tint(.red)
                    } else {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                        }
                    }
                }
            }
            .onDisappear {
                // 防止状态泄漏到下次进来
                askDelete = false
                revertTask?.cancel()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .confirm) {
                        workLog.startTime = startTime_
                        workLog.endTime = endTime_
                        modelContext.insert(workLog)
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                ZStack {
                    Rectangle()
                        .frame(maxWidth: .infinity, maxHeight: 50)
                        .opacity(0)
                        .glassEffect(in: .rect(cornerRadius: 25))
                    HStack {
                        Text(startTime_, format: .dateTime.year().month().day())
                            .foregroundStyle(.secondary)
                            .offset(x: 20)
                        Spacer(minLength: 0)
                        Text("\(workDurationsOfHour) 小时 \(workDurationsOfMinutes) 分钟 ")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.orange)
                            .offset(x: -20)
                    }
                }
                .padding(EdgeInsets(top: 10, leading: 17, bottom: 0, trailing: 17))
            }
        }
    }
    
    private func scheduleRevertIfNeeded() {
        revertTask?.cancel()
        revertTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            withAnimation(.snappy) { askDelete = false }
        }
    }
    
    private func recompute() {
        let cal = Calendar.current
        startTime_ = merge(base: baseDate, clock: startClock, cal: cal)

        var endBase = baseDate
        if isOvernight { endBase = cal.date(byAdding: .day, value: 1, to: baseDate)! }
        endTime_ = merge(base: endBase, clock: endClock, cal: cal)
    }

    private func merge(base: Date, clock: Date, cal: Calendar) -> Date {
        let d = cal.dateComponents([.year, .month, .day], from: base)
        let t = cal.dateComponents([.hour, .minute, .second], from: clock)
        var c = DateComponents()
        c.year = d.year; c.month = d.month; c.day = d.day
        c.hour = t.hour; c.minute = t.minute; c.second = t.second ?? 0
        return cal.date(from: c) ?? base
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
                .frame(width: 22, height: 22)
                .shadow(color: .orange.opacity(0.2), radius: 1)

            Image(systemName: "moon.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.orange)
        }
        .padding(.leading, 4)
    }
}

struct TimeWheel: View {
    @Binding var date: Date
    private let hours = Array(0...23)
    private let minutes = stride(from: 0, through: 59, by: 1).map { $0 }

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

#Preview {
    let workLog = WorkLogs(startTime: Date().addingTimeInterval(-28800), endTime: Date())
    LogForm(workLog: workLog, isEdit: true)
        .environment(\.locale, .init(identifier: "zh-Hans-CN"))
}
