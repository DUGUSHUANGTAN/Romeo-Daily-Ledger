import Charts
import SwiftUI

struct InsightsView: View {
    @State private var model: InsightsViewModel
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
                if let errorMessage = model.errorMessage {
                    Text("统计加载失败：\(errorMessage)")
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
        .foregroundStyle(theme.primaryText.color)
        .background(theme.canvas.color)
        .task { await model.load() }
        .animation(monthAnimation, value: model.displayedMonth)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("统计")
                    .font(AppTypography.display(typography))
                Text(model.displayedMonth, format: .dateTime.year().month(.wide))
                    .font(AppTypography.body(typography))
                    .foregroundStyle(theme.secondaryText.color)
            }
            Spacer()
            Button("上个月") { Task { await model.moveMonth(by: -1) } }
                .accessibilityLabel("查看上个月统计")
                .accessibilityIdentifier("insights-previous-month")
            Button("下个月") { Task { await model.moveMonth(by: 1) } }
                .accessibilityLabel("查看下个月统计")
                .accessibilityIdentifier("insights-next-month")
        }
    }

    private var monthSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("本月概览")
                .font(AppTypography.title(typography))
            HStack(spacing: 12) {
                summaryMetric(title: "收入", value: model.report.income, accent: theme.primaryAccent.color)
                summaryMetric(title: "支出", value: model.report.expense, accent: theme.secondaryAccent.color)
                summaryMetric(title: "净额", value: model.report.net, accent: theme.primaryText.color)
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
            Text(LedgerFormatting.amount(value))
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
        chartCard(title: "月度收支", summary: monthSummaryText) {
            if model.report.isEmpty {
                emptyChartState("这个月还没有账目，月度图表暂无数据。", identifier: "insights-monthly-empty-state")
            } else {
                Chart(monthBars) { item in
                    BarMark(
                        x: .value("类型", item.title),
                        y: .value("金额", item.chartValue)
                    )
                    .foregroundStyle(item.color)
                    .annotation(position: .top) {
                        Text(LedgerFormatting.amount(item.amount))
                            .font(AppTypography.caption(typography))
                            .foregroundStyle(theme.primaryText.color)
                    }
                }
                .chartYAxisLabel("金额")
                .frame(height: 190)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("月度收入与支出柱状图")
                .accessibilityValue(monthSummaryText)
            }
        }
    }

    private var categoryChartSection: some View {
        chartCard(title: "分类构成", summary: categorySummaryText) {
            if model.report.categories.isEmpty {
                emptyChartState("这个月还没有分类数据，分类图表暂无内容。", identifier: "insights-category-empty-state")
            } else {
                Chart(model.report.categories) { category in
                    BarMark(
                        x: .value("金额", chartValue(category.amount)),
                        y: .value("分类", categoryAxisLabel(category))
                    )
                    .foregroundStyle(category.kind == .income ? theme.primaryAccent.color : theme.secondaryAccent.color)
                    .annotation(position: .trailing) {
                        Text(percentage(category.share))
                            .font(AppTypography.caption(typography))
                            .foregroundStyle(theme.secondaryText.color)
                    }
                }
                .chartXAxisLabel("金额")
                .frame(minHeight: 190, idealHeight: CGFloat(model.report.categories.count) * 34)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("分类金额与占比条形图")
                .accessibilityValue(categorySummaryText)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(model.report.categories) { category in
                        HStack {
                            Text(categoryAxisLabel(category))
                            Spacer()
                            Text("\(LedgerFormatting.amount(category.amount))，占\(percentage(category.share))")
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
            MonthBar(title: "收入", amount: model.report.income, color: theme.primaryAccent.color),
            MonthBar(title: "支出", amount: model.report.expense, color: theme.secondaryAccent.color),
        ]
    }

    private var monthSummaryText: String {
        "本月收入 \(LedgerFormatting.amount(model.report.income))，支出 \(LedgerFormatting.amount(model.report.expense))，净额 \(LedgerFormatting.amount(model.report.net))。"
    }

    private var categorySummaryText: String {
        guard !model.report.categories.isEmpty else { return "本月暂无分类统计。" }
        return model.report.categories.map {
            "\(categoryAxisLabel($0)) \(LedgerFormatting.amount($0.amount))，占\(percentage($0.share))"
        }.joined(separator: "；") + "。"
    }

    private func categoryAxisLabel(_ category: InsightsCategorySummary) -> String {
        "\(category.kind == .income ? "收入" : "支出") · \(model.displayName(for: category))"
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
