import Foundation

enum ProgressSummaryStyle: String {
    case dailyActivity
    case monthlyCumulativeTotal

    var toggled: ProgressSummaryStyle {
        switch self {
        case .dailyActivity: return .monthlyCumulativeTotal
        case .monthlyCumulativeTotal: return .dailyActivity
        }
    }
}
