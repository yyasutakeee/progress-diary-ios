import Foundation

struct AppState {
    var lists: [DiaryList] = []
    var entries: [DiaryEntry] = []
    var selectedListID: UUID? = nil
    var progressSummaryStyle: ProgressSummaryStyle = .dailyActivity
}
