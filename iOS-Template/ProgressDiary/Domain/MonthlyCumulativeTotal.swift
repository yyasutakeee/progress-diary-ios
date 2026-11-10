import Foundation

struct MonthlyCumulativeTotal {
    let monthStart: Date
    let addedCount: Int
    let total: Int
}

enum MonthlyCumulativeTotalCalculator {
    static func calculate(from entries: [DiaryEntry], calendar: Calendar = .current, now: Date = Date()) -> [MonthlyCumulativeTotal] {
        let entryMonthStarts: [Date] = entries.map { monthStart(of: $0.createdAt, calendar: calendar) }
        guard let firstMonth: Date = entryMonthStarts.min() else { return [] }
        let countsByMonth: [Date: Int] = Dictionary(grouping: entryMonthStarts, by: { $0 }).mapValues { $0.count }
        let lastMonth: Date = max(monthStart(of: now, calendar: calendar), entryMonthStarts.max() ?? firstMonth)
        return accumulate(countsByMonth, from: firstMonth, through: lastMonth, calendar: calendar)
    }

    private static func accumulate(_ countsByMonth: [Date: Int], from firstMonth: Date, through lastMonth: Date, calendar: Calendar) -> [MonthlyCumulativeTotal] {
        var totals: [MonthlyCumulativeTotal] = []
        var runningTotal: Int = 0
        var month: Date = firstMonth
        while month <= lastMonth {
            let addedCount: Int = countsByMonth[month] ?? 0
            runningTotal += addedCount
            totals.append(MonthlyCumulativeTotal(monthStart: month, addedCount: addedCount, total: runningTotal))
            guard let nextMonth: Date = calendar.date(byAdding: .month, value: 1, to: month) else { break }
            month = nextMonth
        }
        return totals
    }

    private static func monthStart(of date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
    }
}
