import SwiftUI
import SwiftData

// MARK: - HomeTab
struct HomeTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkLogs.startTime) var workLogs: [WorkLogs]

    @State private var modalType: ModalType?
    @State private var showingLogForm = false
    @State private var selectedDate: Date = .now

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                DateChooserView(selectedDate: $selectedDate)

                MonthlyView(selectedDate: $selectedDate)
            }
            .padding(.horizontal)
            .navigationTitle("Home")
        }
    }
}

// MARK: - DateChooserView
struct DateChooserView: View {
    @Binding private var selectedDate: Date

    @State private var years: [Int]
    @State private var selectedMonth: Int
    @State private var selectedYear: Int
    private let months = Date.fullMonthNames

    init(selectedDate: Binding<Date>) {
        self._selectedDate = selectedDate
        _years = State(initialValue: Array(2024...Date.now.yearInt))
        _selectedYear = State(initialValue: selectedDate.wrappedValue.yearInt)
        _selectedMonth = State(initialValue: selectedDate.wrappedValue.monthInt)
    }

    var body: some View {
        HStack(spacing: 16) {
            Picker("", selection: $selectedYear) {
                ForEach(years, id: \.self) { year in
                    Text("\(year)").tag(year)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 120)

            Picker("", selection: $selectedMonth) {
                ForEach(months.indices, id: \.self) { idx in
                    Text(months[idx]).tag(idx + 1)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 120)
        }
        .onChange(of: selectedYear) { updateDate() }
        .onChange(of: selectedMonth) { updateDate() }
    }

    private func updateDate() {
        if let newDate = Calendar.current.date(from: DateComponents(year: selectedYear, month: selectedMonth, day: 1)) {
            selectedDate = newDate
        }
    }
}

// MARK: - MonthlyView
struct MonthlyView: View {
    @Binding private var selectedDate: Date

    @State private var years: [Int]
    @State private var selectedYear: Int
    @State private var selectedMonth: Int

    private let daysOfWeek = Date.capitalizedFirstLettersOfWeekdays
    private let months = Date.fullMonthNames

    init(selectedDate: Binding<Date>) {
        self._selectedDate = selectedDate
        self._years = State(initialValue: Array(2024...Date.now.yearInt))
        self._selectedYear = State(initialValue: selectedDate.wrappedValue.yearInt)
        self._selectedMonth = State(initialValue: selectedDate.wrappedValue.monthInt)
    }

    var body: some View {
        VStack(spacing: 8) {
            CalendarView(date: selectedDate)
        }
        .onChange(of: selectedYear) { updateSelectedDate() }
        .onChange(of: selectedMonth) { updateSelectedDate() }
        .onChange(of: selectedDate) {
            selectedYear = selectedDate.yearInt
            selectedMonth = selectedDate.monthInt
        }
    }

    private func updateSelectedDate() {
        if let first = Calendar.current.date(from: DateComponents(year: selectedYear, month: selectedMonth, day: 1)) {
            selectedDate = first.startOfDay
        }
    }
}

// MARK: - CalendarView（去掉多余的 @State）
struct CalendarView: View {
    @State private var color: Color = .blue
    let date: Date

    private let daysOfWeek = Date.capitalizedFirstLettersOfWeekdays
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    private var days: [Date] { date.calendarDisplayDays }

    var body: some View {
        VStack(spacing: 8) {

            HStack {
                ForEach(daysOfWeek.indices, id: \.self) { i in
                    Text(daysOfWeek[i])
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(days, id: \.self) { day in
                    Group {
                        if day.monthInt != date.monthInt {
                            Text(" ") 
                                .frame(maxWidth: .infinity, minHeight: 40)
                        } else {
                            Text(day.formatted(.dateTime.day()))
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(
                                    Circle()
                                        .foregroundStyle(
                                            Date.now.startOfDay == day.startOfDay
                                            ? .red.opacity(0.3)
                                            : color.opacity(0.3)
                                        )
                                )
                        }
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Preview
#Preview {
    HomeTab()
        .environment(\.locale, .init(identifier: "zh-Hans-CN"))
        .modelContainer(for: WorkLogs.self, inMemory: true)
}
