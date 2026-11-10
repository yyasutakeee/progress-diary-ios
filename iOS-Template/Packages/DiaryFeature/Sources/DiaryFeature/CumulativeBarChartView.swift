import SwiftUI

public struct CumulativeBarChartView: View {
    public let monthlyTotals: [DiaryMonthlyTotalItem]
    public let barColor: Color

    private let barWidth: CGFloat = 28
    private let barSpacing: CGFloat = 8
    private let maxBarHeight: CGFloat = 48
    private let chartHeight: CGFloat = 90

    public init(monthlyTotals: [DiaryMonthlyTotalItem], barColor: Color) {
        self.monthlyTotals = monthlyTotals
        self.barColor = barColor
    }

    public var body: some View {
        if monthlyTotals.isEmpty {
            emptyState
        } else {
            scrollableBars
        }
    }

    private var emptyState: some View {
        Text("No entries yet")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: chartHeight)
    }

    private var scrollableBars: some View {
        ScrollViewReader { scrollViewProxy in
            ScrollView(.horizontal, showsIndicators: false) {
                barsRow
            }
            .frame(height: chartHeight)
            .task(id: monthlyTotals.last?.id) {
                await scrollToLatestMonth(using: scrollViewProxy)
            }
        }
    }

    private var barsRow: some View {
        HStack(alignment: .bottom, spacing: barSpacing) {
            ForEach(monthlyTotals) { item in
                monthColumn(item)
                    .id(item.id)
            }
        }
        .padding(.horizontal, 4)
    }

    private func monthColumn(_ item: DiaryMonthlyTotalItem) -> some View {
        VStack(spacing: 2) {
            Text("\(item.total)")
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
            RoundedRectangle(cornerRadius: 4)
                .fill(barColor)
                .frame(width: barWidth, height: barHeight(for: item.total))
            Text(item.monthLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()
            Text(item.yearLabel ?? " ")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .fixedSize()
        }
        .frame(minWidth: barWidth)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.monthLabel) \(item.yearLabel ?? ""): \(item.total) total")
    }

    private func barHeight(for total: Int) -> CGFloat {
        let largestTotal: Int = max(monthlyTotals.map { $0.total }.max() ?? 1, 1)
        let ratio: CGFloat = CGFloat(total) / CGFloat(largestTotal)
        return max(maxBarHeight * ratio, 2)
    }

    private func scrollToLatestMonth(using scrollViewProxy: ScrollViewProxy) async {
        await Task.yield()
        guard let latestID: String = monthlyTotals.last?.id else { return }
        scrollViewProxy.scrollTo(latestID, anchor: .trailing)
    }
}
