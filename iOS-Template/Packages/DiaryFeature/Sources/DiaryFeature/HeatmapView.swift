import SwiftUI

public struct HeatmapView: View {
    public let activeDayKeys: Set<String>
    public let activeColor: Color

    private let cellSize: CGFloat = 10
    private let cellGap: CGFloat = 2

    private static let dayKeyFormatter: DateFormatter = {
        let f: DateFormatter = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    public init(activeDayKeys: Set<String>, activeColor: Color = .yellow) {
        self.activeDayKeys = activeDayKeys
        self.activeColor = activeColor
    }

    public var body: some View {
        ScrollViewReader { scrollViewProxy in
            ScrollView(.horizontal, showsIndicators: false) {
                GlassEffectContainer {
                    weeksRow
                }
                    .padding(.vertical, 4)
            }
            .task {
                await scrollToToday(using: scrollViewProxy)
            }
        }
    }

    private var weeksRow: some View {
        let weeks: [[Date?]] = buildCurrentYearWeeks()
        return HStack(alignment: .top, spacing: cellGap) {
            ForEach(weeks.indices, id: \.self) { i in
                weekColumn(weeks[i])
            }
        }
    }

    private func weekColumn(_ days: [Date?]) -> some View {
        VStack(spacing: cellGap) {
            ForEach(0..<7, id: \.self) { row in
                dayCell(days[row])
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ date: Date?) -> some View {
        if let date {
            dayCellShape(for: date)
                .id(makeDayKey(for: date))
        } else {
            dayCellShape(for: nil)
        }
    }

    private func dayCellShape(for date: Date?) -> some View {
        dayCellFill(for: date)
            .frame(width: cellSize, height: cellSize)
            .overlay {
                if let date {
                    todayRing(for: date)
                }
            }
    }

    @ViewBuilder
    private func todayRing(for date: Date) -> some View {
        if isToday(date) {
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color.primary, lineWidth: 2)
                .frame(width: cellSize + 2, height: cellSize + 2)
        }
    }

    @ViewBuilder
    private func dayCellFill(for date: Date?) -> some View {
        if let date, isDayActive(date) {
            Color.clear
                .glassEffect(.regular.tint(activeColor), in: RoundedRectangle(cornerRadius: 2))
        } else {
            RoundedRectangle(cornerRadius: 2)
                .fill(date == nil ? Color.clear : Color(.systemFill))
        }
    }

    private func isDayActive(_ date: Date) -> Bool {
        activeDayKeys.contains(makeDayKey(for: date))
    }

    private func isToday(_ date: Date) -> Bool {
        makeDayKey(for: date) == makeDayKey(for: Date())
    }

    private func makeDayKey(for date: Date) -> String {
        Self.dayKeyFormatter.string(from: date)
    }

    private func scrollToToday(using scrollViewProxy: ScrollViewProxy) async {
        await Task.yield()
        scrollViewProxy.scrollTo(makeDayKey(for: Date()), anchor: .center)
    }

    private func buildCurrentYearWeeks() -> [[Date?]] {
        let calendar: Calendar = Calendar.current
        let year: Int = calendar.component(.year, from: Date())
        return buildWeeks(forYear: year, using: calendar)
    }

    private func buildWeeks(forYear year: Int, using calendar: Calendar) -> [[Date?]] {
        guard
            let start: Date = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
            let end: Date = calendar.date(from: DateComponents(year: year, month: 12, day: 31))
        else { return [] }
        return collectWeeks(from: start, through: end, using: calendar)
    }

    private func collectWeeks(from start: Date, through end: Date, using calendar: Calendar) -> [[Date?]] {
        let leadingPadding: Int = calendar.component(.weekday, from: start) - 1
        var weeks: [[Date?]] = []
        var currentWeek: [Date?] = Array(repeating: nil, count: leadingPadding)
        var date: Date = start

        while date <= end {
            currentWeek.append(date)
            if currentWeek.count == 7 {
                weeks.append(currentWeek)
                currentWeek = []
            }
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? end
        }

        if !currentWeek.isEmpty {
            while currentWeek.count < 7 { currentWeek.append(nil) }
            weeks.append(currentWeek)
        }

        return weeks
    }
}
