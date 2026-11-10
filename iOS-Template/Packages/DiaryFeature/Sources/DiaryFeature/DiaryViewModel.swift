import Combine
import Foundation

@MainActor
public protocol DiaryViewModel: ObservableObject {
    var lists: [DiaryListItem] { get }
    var entriesByListID: [UUID: [DiaryEntryItem]] { get }
    var activeDayKeysByListID: [UUID: Set<String>] { get }
    var monthlyTotalsByListID: [UUID: [DiaryMonthlyTotalItem]] { get }
    var progressChartStyle: ProgressChartStyle { get }
    var streakByListID: [UUID: DiaryStreakItem] { get }
    var selectedListStreak: DiaryStreakItem? { get }
    var selectedListID: UUID? { get }
    var currentListName: String { get }
    var editingListID: UUID? { get }
    var isShowingAddEntry: Bool { get set }
    var isShowingAddList: Bool { get set }
    var isShowingListSettings: Bool { get set }
    var isShowingDeleteListConfirmation: Bool { get set }
    func send(_ event: DiaryEvent)
}
