import SwiftUI

struct CalendarView: View {
    @State private var model = CalendarViewModel()
    @State private var entries: [LedgerEntry] = []
    @State private var errorMessage: String?
    @State private var editingEntry: LedgerEntry?
    let repository: LedgerRepository
    let theme: AppTheme
    let typography: AppTypography.Style

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("日历").font(AppTypography.display(typography))
                    Text(model.displayedMonth, format: .dateTime.year().month(.wide))
                        .font(AppTypography.body(typography))
                        .foregroundStyle(theme.secondaryText.color)
                }
                Spacer()
                Button("上个月") { model.moveMonth(by: -1) }
                    .accessibilityIdentifier("calendar-previous-month")
                Button("今天") {
                    model.selectedDate = .now
                    model.displayedMonth = model.calendar.dateInterval(of: .month, for: .now)!.start
                    Task { await loadEntries() }
                }
                .accessibilityIdentifier("calendar-today")
                Button("下个月") { model.moveMonth(by: 1) }
                    .accessibilityIdentifier("calendar-next-month")
            }
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol).font(AppTypography.caption(typography)).foregroundStyle(theme.secondaryText.color)
                }
                ForEach(model.monthGrid()) { day in
                    Button {
                        model.selectedDate = day.date
                        Task { await loadEntries() }
                    } label: {
                        Text(day.date, format: .dateTime.day())
                            .frame(maxWidth: .infinity, minHeight: 34)
                            .foregroundStyle(day.isInDisplayedMonth ? theme.primaryText.color : theme.secondaryText.color.opacity(0.55))
                            .background(model.calendar.isDate(day.date, inSameDayAs: model.selectedDate) ? theme.primaryAccent.color.opacity(0.18) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(day.date.formatted(date: .long, time: .omitted))
                    .accessibilityAddTraits(model.calendar.isDate(day.date, inSameDayAs: model.selectedDate) ? .isSelected : [])
                    .accessibilityValue(model.calendar.isDate(day.date, inSameDayAs: model.selectedDate) ? "已选择" : "未选择")
                    .accessibilityIdentifier("calendar-day-\(Int(day.date.timeIntervalSince1970))")
                }
            }
            .padding(14)
            .background(theme.surface.color, in: RoundedRectangle(cornerRadius: 14))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("月历")
            .accessibilityIdentifier("calendar-grid")
            Divider()
            Text(model.selectedDate, format: .dateTime.year().month().day())
                .font(AppTypography.title(typography))
            let summary = SelectionSummary(entries: entries)
            HStack(spacing: 16) {
                Text("当日收入 \(LedgerFormatting.amount(summary.income))")
                    .accessibilityIdentifier("calendar-day-income")
                Text("当日支出 \(LedgerFormatting.amount(summary.expense))")
                    .accessibilityIdentifier("calendar-day-expense")
            }
            .font(AppTypography.caption(typography))
            .foregroundStyle(theme.secondaryText.color)
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            } else if entries.isEmpty {
                Text("当天没有账目")
                    .foregroundStyle(theme.secondaryText.color)
                    .accessibilityIdentifier("calendar-empty-state")
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(entries) { entry in
                            Button {
                                editingEntry = entry
                            } label: {
                                HStack(spacing: 12) {
                                    Text(entry.kind == .income ? "收入" : "支出")
                                        .font(AppTypography.caption(typography))
                                        .foregroundStyle(theme.secondaryText.color)
                                    Text(entry.note.isEmpty ? "无备注" : entry.note)
                                    Spacer()
                                    Text(LedgerFormatting.amount(entry.amount))
                                }
                                .padding(12)
                                .background(theme.surface.color, in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(entry.kind == .income ? "收入" : "支出") \(entry.note.isEmpty ? "无备注" : entry.note) \(LedgerFormatting.amount(entry.amount))")
                            .accessibilityIdentifier("calendar-entry-\(entry.id.uuidString.lowercased())")
                            .contextMenu {
                                Button("编辑账目") { editingEntry = entry }
                            }
                        }
                    }
                }
                .accessibilityIdentifier("calendar-entry-list")
            }
            Spacer(minLength: 0)
        }
        .padding(28)
        .foregroundStyle(theme.primaryText.color)
        .background(theme.canvas.color)
        .task {
            try? await repository.seedDefaultsIfNeeded()
            await loadEntries()
        }
        .sheet(item: $editingEntry) { entry in
            EntryEditorView(entry: entry, repository: repository, theme: theme, typography: typography) {
                await loadEntries()
            }
        }
    }

    private var weekdaySymbols: [String] {
        let symbols = model.calendar.shortStandaloneWeekdaySymbols
        let split = model.calendar.firstWeekday - 1
        return Array(symbols[split...] + symbols[..<split])
    }

    private func loadEntries() async {
        do {
            entries = try await repository.entries(in: model.dayInterval(containing: model.selectedDate))
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
