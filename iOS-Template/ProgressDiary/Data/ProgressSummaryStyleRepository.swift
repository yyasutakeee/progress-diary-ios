import Foundation

protocol ProgressSummaryStyleRepository {
    func loadStyle() -> ProgressSummaryStyle
    func saveStyle(_ style: ProgressSummaryStyle)
}

final class UserDefaultsProgressSummaryStyleRepository: ProgressSummaryStyleRepository {
    private let userDefaults: UserDefaults
    private let styleKey: String = "progressSummaryStyle"

    // WHY: injecting UserDefaults keeps the preference storage replaceable in tests.
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // WHY: an unknown or missing stored value falls back to the original daily view.
    func loadStyle() -> ProgressSummaryStyle {
        let rawValue: String = userDefaults.string(forKey: styleKey) ?? ""
        return ProgressSummaryStyle(rawValue: rawValue) ?? .dailyActivity
    }

    // WHY: the choice is a device-local preference, so it stays out of the CloudKit-synced model.
    func saveStyle(_ style: ProgressSummaryStyle) {
        userDefaults.set(style.rawValue, forKey: styleKey)
    }
}
