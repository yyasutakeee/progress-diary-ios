import Foundation

public struct DiaryMonthlyTotalItem: Identifiable, Equatable {
    public let id: String
    public let monthLabel: String
    public let yearLabel: String?
    public let total: Int

    public init(id: String, monthLabel: String, yearLabel: String?, total: Int) {
        self.id = id
        self.monthLabel = monthLabel
        self.yearLabel = yearLabel
        self.total = total
    }
}
