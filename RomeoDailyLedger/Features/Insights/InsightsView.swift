import Charts
import SwiftUI

struct InsightsView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.appCurrencyCode) private var currencyCode
    @State private var model: InsightsViewModel
    @State private var yearText = ""
    let theme: AppTheme
    let typography: AppTypography.Style
    let motion: MotionPolicy

    init(
        repository: LedgerRepository,
        theme: AppTheme,
        typography: AppTypography.Style,
        motion: MotionPolicy
    ) {
        _model = State(initialValue: InsightsViewModel(repository: repository))
        self.theme = theme
        self.typography = typography
        self.motion = motion
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if model.errorMessage != nil {
                    Text(AppLocalization.text("error.loadInsights", language: language))
                        .font(AppTypography.body(typography))
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("insights-error")
                }
                monthSummary
                monthlyChartSection
                categoryChartSection
            }
            .padding(28)
            .frame(maxWidth: 980, alignment: .leading)
        }
        .fadingAtTopEdge()
        .foregroundStyle(theme.primaryText.color)
        .background(theme.canvas.color)
        .task {
            synchronizeYearText()
            await model.load()
        }
        .onChange(of: model.displayedMonth) { _, _ in synchronizeYearText() }
        .animation(monthAnimation, value: model.displayedMonth)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(AppLocalization.text("nav.insights.title", language: language))
                    .font(AppTypography.display(typography))
                Text(model.displayedMonth, format: .dateTime.year().month(.wide).locale(language.locale))
                    .font(AppTypography.body(typography))
                    .foregroundStyle(theme.secondaryText.color)
            }
            HStack(spacing: 10) {
                CommitOnEndEditingTextField(
                    text: $yearText,
                    placeholder: AppLocalization.text("calendar.year", language: language),
                    accessibilityIdentifier: "insights-year",
                    onCommit: commitYear
                )
                .frame(width: 72)
                Picker(AppLocalization.text("calendar.month", language: language), selection: monthBinding) {
                    ForEach(1...12, id: \.self) { Text(monthSymbols[$0 - 1]).tag($0) }
                }
                .labelsHidden().frame(width: 110).accessibilityIdentifier("insights-month")
                Button(AppLocalization.text("insights.thisMonth", language: language)) { Task { await model.selectCurrentMonth() } }
                    .accessibilityIdentifier("insights-current-month")
                Spacer(minLength: 0)
            }
        }
    }

    private var monthBinding: Binding<Int> { Binding(get: { model.calendar.component(.month, from: model.displayedMonth) }, set: { month in Task { await model.select(year: model.displayedYear, month: month) } }) }

    private var monthSymbols: [String] {
        var calendar = model.calendar
        calendar.locale = language.locale
        return calendar.monthSymbols
    }

    private func synchronizeYearText() {
        yearText = String(model.displayedYear)
    }

    private func commitYear(_ input: String) {
        guard let year = CalendarViewModel.validatedYear(from: input) else {
            synchronizeYearText()
            return
        }
        Task { await model.select(year: year, month: model.calendar.component(.month, from: model.displayedMonth)) }
    }

    private var monthSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppLocalization.text("insights.monthOverview", language: language))
                .font(AppTypography.title(typography))
            HStack(spacing: 12) {
                summaryMetric(title: AppLocalization.text("entry.income", language: language), value: model.report.income, accent: theme.primaryAccent.color)
                summaryMetric(title: AppLocalization.text("entry.expense", language: language), value: model.report.expense, accent: theme.secondaryAccent.color)
                summaryMetric(title: AppLocalization.text("summary.net.label", language: language), value: model.report.net, accent: theme.primaryText.color)
            }
            Text(monthSummaryText)
                .font(AppTypography.body(typography))
                .foregroundStyle(theme.secondaryText.color)
                .accessibilityIdentifier("insights-month-summary")
        }
    }

    private func summaryMetric(title: String, value: Decimal, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppTypography.caption(typography))
                .foregroundStyle(theme.secondaryText.color)
            Text(LedgerFormatting.amount(value, currencyCode: currencyCode))
                .font(AppTypography.title(typography))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface.color, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private var monthlyChartSection: some View {
        chartCard(title: AppLocalization.text("insights.monthlyChart.title", language: language), summary: monthSummaryText) {
            if model.report.isEmpty {
                emptyChartState(AppLocalization.text("insights.monthlyChart.empty", language: language), identifier: "insights-monthly-empty-state")
            } else {
                Chart(monthBars) { item in
                    BarMark(
                        x: .value(AppLocalization.text("chart.type", language: language), item.title),
                        y: .value(AppLocalization.text("field.amount", language: language), item.chartValue)
                    )
                    .foregroundStyle(item.color)
                    .annotation(position: .top) {
                        Text(LedgerFormatting.amount(item.amount, currencyCode: currencyCode))
                            .font(AppTypography.caption(typography))
                            .foregroundStyle(theme.primaryText.color)
                    }
                }
                .chartYAxisLabel(AppLocalization.text("field.amount", language: language))
                .frame(height: 190)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(AppLocalization.text("accessibility.monthlyChart", language: language))
                .accessibilityValue(monthSummaryText)
            }
        }
    }

    private var categoryChartSection: some View {
        chartCard(title: AppLocalization.text("insights.categoryChart.title", language: language), summary: categorySummaryText) {
            if model.report.categories.isEmpty {
                emptyChartState(AppLocalization.text("insights.categoryChart.empty", language: language), identifier: "insights-category-empty-state")
            } else {
                Chart(model.report.categories) { category in
                    BarMark(
                        x: .value(AppLocalization.text("field.amount", language: language), chartValue(category.amount)),
                        y: .value(AppLocalization.text("field.category", language: language), categoryAxisLabel(category))
                    )
                    .foregroundStyle(category.kind == .income ? theme.primaryAccent.color : theme.secondaryAccent.color)
                    .annotation(position: .trailing) {
                        Text(percentage(category.share))
                            .font(AppTypography.caption(typography))
                            .foregroundStyle(theme.secondaryText.color)
                    }
                }
                .chartXAxisLabel(AppLocalization.text("field.amount", language: language))
                .frame(minHeight: 190, idealHeight: CGFloat(model.report.categories.count) * 34)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(AppLocalization.text("accessibility.categoryChart", language: language))
                .accessibilityValue(categorySummaryText)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(model.report.categories) { category in
                        HStack {
                            Text(categoryAxisLabel(category))
                            Spacer()
                            Text(AppLocalization.format("insights.category.share", language: language, LedgerFormatting.amount(category.amount, currencyCode: currencyCode), percentage(category.share)))
                                .foregroundStyle(theme.secondaryText.color)
                        }
                        .font(AppTypography.body(typography))
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func chartCard<Content: View>(title: String, summary: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(AppTypography.title(typography))
            Text(summary)
                .font(AppTypography.caption(typography))
                .foregroundStyle(theme.secondaryText.color)
            content()
        }
        .padding(18)
        .background(theme.surface.color, in: RoundedRectangle(cornerRadius: 14))
    }

    private func emptyChartState(_ message: String, identifier: String) -> some View {
        Text(message)
            .font(AppTypography.body(typography))
            .foregroundStyle(theme.secondaryText.color)
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .center)
            .accessibilityLabel(message)
            .accessibilityIdentifier(identifier)
    }

    private var monthBars: [MonthBar] {
        [
            MonthBar(title: AppLocalization.text("entry.income", language: language), amount: model.report.income, color: theme.primaryAccent.color),
            MonthBar(title: AppLocalization.text("entry.expense", language: language), amount: model.report.expense, color: theme.secondaryAccent.color),
        ]
    }

    private var monthSummaryText: String {
        AppLocalization.format("insights.monthSummary", language: language, LedgerFormatting.amount(model.report.income, currencyCode: currencyCode), LedgerFormatting.amount(model.report.expense, currencyCode: currencyCode), LedgerFormatting.amount(model.report.net, currencyCode: currencyCode))
    }

    private var categorySummaryText: String {
        guard !model.report.categories.isEmpty else { return AppLocalization.text("insights.categorySummary.empty", language: language) }
        return model.report.categories.map {
            AppLocalization.format("insights.categorySummary.item", language: language, categoryAxisLabel($0), LedgerFormatting.amount($0.amount, currencyCode: currencyCode), percentage($0.share))
        }.joined(separator: AppLocalization.text("list.separator", language: language)) + AppLocalization.text("sentence.period", language: language)
    }

    private func categoryAxisLabel(_ category: InsightsCategorySummary) -> String {
        AppLocalization.format("insights.categoryAxis", language: language, AppLocalization.text(category.kind == .income ? "entry.income" : "entry.expense", language: language), model.displayName(for: category, language: language))
    }

    private func percentage(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "0%"
    }

    /// Charts plots the already aggregated Decimal result; no monetary arithmetic
    /// is performed after this display-boundary conversion.
    private func chartValue(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }

    private var monthAnimation: Animation? {
        guard motion.effectiveIntensity > 0 else { return nil }
        return motion.usesSpring ? .snappy(duration: motion.duration) : .easeOut(duration: motion.duration)
    }
}

private struct MonthBar: Identifiable {
    let title: String
    let amount: Decimal
    let color: Color

    var id: String { title }
    var chartValue: Double { NSDecimalNumber(decimal: amount).doubleValue }
}
