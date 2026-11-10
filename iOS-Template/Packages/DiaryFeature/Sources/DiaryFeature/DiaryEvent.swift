import Foundation

public enum DiaryEvent {
    case addEntryTapped
    case entryTextSubmitted(String)
    case deleteEntry(UUID)
    case listSelected(UUID)
    case addListTapped
    case listNameSubmitted(String)
    case deleteList(UUID)
    case listSettingsTapped(UUID)
    case heatmapColorSelected(String)
    case streakTrackingChanged(Bool)
    case deleteCurrentListRequested
    case deleteCurrentListConfirmed
    case progressChartStyleToggled
}
