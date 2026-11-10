import Combine
import Foundation
import DiaryFeature

@MainActor
final class DiaryViewStore: DiaryViewModel {
    @Published private(set) var lists: [DiaryListItem] = []
    @Published private(set) var entriesByListID: [UUID: [DiaryEntryItem]] = [:]
    @Published private(set) var activeDayKeysByListID: [UUID: Set<String>] = [:]
    @Published private(set) var monthlyTotalsByListID: [UUID: [DiaryMonthlyTotalItem]] = [:]
    @Published private(set) var progressChartStyle: ProgressChartStyle = .heatmap
    @Published private(set) var streakByListID: [UUID: DiaryStreakItem] = [:]
    @Published private(set) var selectedListStreak: DiaryStreakItem? = nil
    @Published private(set) var selectedListID: UUID? = nil
    @Published private(set) var currentListName: String = ""
    @Published private(set) var editingListID: UUID? = nil
    @Published var isShowingAddEntry: Bool = false
    @Published var isShowingAddList: Bool = false
    @Published var isShowingListSettings: Bool = false
    @Published var isShowingDeleteListConfirmation: Bool = false

    private let appStore: AppStore
    private var cancellables: Set<AnyCancellable> = Set<AnyCancellable>()

    private static let dayKeyFormatter: DateFormatter = {
        let f: DateFormatter = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let monthIDFormatter: DateFormatter = {
        let f: DateFormatter = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f
    }()

    private static let monthLabelFormatter: DateFormatter = {
        let f: DateFormatter = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("MMM")
        return f
    }()

    private static let yearLabelFormatter: DateFormatter = {
        let f: DateFormatter = DateFormatter()
        f.dateFormat = "yyyy"
        return f
    }()

    private static let dateLabelFormatter: DateFormatter = {
        let f: DateFormatter = DateFormatter()
        f.dateFormat = "M.d"
        return f
    }()

    // WHY: the view store owns only the feature-facing projection while AppStore remains the shared state owner.
    init(appStore: AppStore) {
        self.appStore = appStore
        observeStoreChanges()
        recompute(from: appStore.state)
    }

    // WHY: events are the only channel views use to express intent;
    // all logic stays here so views remain purely declarative.
    func send(_ event: DiaryEvent) {
        switch event {
        case .addEntryTapped:
            isShowingAddEntry = true
        case .entryTextSubmitted(let text):
            guard let selectedListID else { return }
            appStore.addEntry(text: text, to: selectedListID)
            isShowingAddEntry = false
        case .deleteEntry(let id):
            deleteEntryMatchingID(id)
        case .listSelected(let id):
            appStore.selectList(id)
        case .addListTapped:
            isShowingAddList = true
        case .listNameSubmitted(let name):
            appStore.addList(name: name)
            isShowingAddList = false
        case .deleteList(let id):
            deleteListMatchingID(id)
        case .listSettingsTapped(let id):
            editingListID = id
            isShowingListSettings = true
        case .listRenamed(let name):
            renameEditingList(to: name)
        case .heatmapColorSelected(let colorID):
            guard let editingListID else { return }
            appStore.updateListHeatmapColor(listID: editingListID, colorID: colorID)
            isShowingListSettings = false
        case .streakTrackingChanged(let isEnabled):
            guard let editingListID else { return }
            appStore.updateListStreakEnabled(listID: editingListID, isEnabled: isEnabled)
        case .deleteCurrentListRequested:
            isShowingDeleteListConfirmation = true
        case .deleteCurrentListConfirmed:
            guard let selectedListID else { return }
            deleteListMatchingID(selectedListID)
            isShowingDeleteListConfirmation = false
        case .progressChartStyleToggled:
            appStore.toggleProgressSummaryStyle()
        }
    }

    // WHY: subscribes to didChange, not objectWillChange — this handler reads
    // state values, and objectWillChange fires before the mutation has landed.
    private func observeStoreChanges() {
        appStore.didChange
            .sink { [weak self] newState in self?.recompute(from: newState) }
            .store(in: &cancellables)
    }

    // WHY: state is a parameter so there is no route to accidentally read
    // a stale snapshot from a different moment inside this method.
    private func recompute(from state: AppState) {
        lists = state.lists.map(makeDiaryListItem)
        entriesByListID = buildEntriesByListID(from: state.entries)
        activeDayKeysByListID = buildActiveDayKeysByListID(from: state.entries)
        monthlyTotalsByListID = buildMonthlyTotalsByListID(from: state.entries)
        progressChartStyle = makeProgressChartStyle(from: state.progressSummaryStyle)
        selectedListID = state.selectedListID
        currentListName = makeCurrentListName(from: state)
        streakByListID = buildStreakByListID(from: state)
        selectedListStreak = state.selectedListID.flatMap { streakByListID[$0] }
    }

    // WHY: maps the domain value type to a display-only model so DiaryFeature
    // never needs to import domain or persistence types.
    private func makeDiaryEntryItem(from entry: DiaryEntry) -> DiaryEntryItem {
        DiaryEntryItem(
            id: entry.id,
            text: entry.text,
            dateLabel: Self.dateLabelFormatter.string(from: entry.createdAt)
        )
    }

    // WHY: maps list names into the package-owned shape so persistence identifiers stay outside the feature package.
    private func makeDiaryListItem(from list: DiaryList) -> DiaryListItem {
        DiaryListItem(id: list.id, name: list.name, heatmapColorID: list.heatmapColorID, isStreakEnabled: list.isStreakEnabled)
    }

    // WHY: computes streaks only for opted-in categories so unrelated journals stay visually unchanged.
    private func buildStreakByListID(from state: AppState) -> [UUID: DiaryStreakItem] {
        let enabledListIDs: Set<UUID> = Set(state.lists.filter { $0.isStreakEnabled }.map { $0.id })
        let entriesByListID: [UUID: [DiaryEntry]] = Dictionary(grouping: state.entries, by: { $0.listID })
        var streakByListID: [UUID: DiaryStreakItem] = [:]
        for listID: UUID in enabledListIDs {
            let streak: DiaryStreak = DiaryStreakCalculator.calculate(from: entriesByListID[listID] ?? [])
            streakByListID[listID] = DiaryStreakItem(currentDays: streak.currentDays, longestDays: streak.longestDays, hasEntryToday: streak.hasEntryToday, nextEntryDays: streak.nextEntryDays)
        }
        return streakByListID
    }

    // WHY: keeps the navigation label derived from the same state snapshot as the selected page.
    private func makeCurrentListName(from state: AppState) -> String {
        guard let selectedListID = state.selectedListID,
              let selectedList = state.lists.first(where: { $0.id == selectedListID }) else { return "Progress Diary" }
        return selectedList.name
    }

    // WHY: builds a set of date strings so the heatmap can check membership
    // in O(1) rather than scanning the full entries array per cell.
    private func buildActiveDayKeys(from entries: [DiaryEntry]) -> Set<String> {
        Set(entries.map { Self.dayKeyFormatter.string(from: $0.createdAt) })
    }

    // WHY: grouping once lets each page render its own entries without repeatedly scanning the complete domain collection.
    private func buildEntriesByListID(from entries: [DiaryEntry]) -> [UUID: [DiaryEntryItem]] {
        Dictionary(grouping: entries, by: { $0.listID }).mapValues { $0.map(makeDiaryEntryItem) }
    }

    // WHY: each heatmap needs only the dates belonging to its page, keeping list navigation and calendar state aligned.
    private func buildActiveDayKeysByListID(from entries: [DiaryEntry]) -> [UUID: Set<String>] {
        Dictionary(grouping: entries, by: { $0.listID }).mapValues { buildActiveDayKeys(from: $0) }
    }

    // WHY: each page's bar chart needs its own running total, so totals are grouped by list before accumulating.
    private func buildMonthlyTotalsByListID(from entries: [DiaryEntry]) -> [UUID: [DiaryMonthlyTotalItem]] {
        Dictionary(grouping: entries, by: { $0.listID }).mapValues { listEntries in
            let totals: [MonthlyCumulativeTotal] = MonthlyCumulativeTotalCalculator.calculate(from: listEntries)
            return totals.enumerated().map { index, total in makeDiaryMonthlyTotalItem(from: total, isFirst: index == 0) }
        }
    }

    // WHY: the year appears only where it changes or begins, keeping narrow bar labels readable;
    // months without additions carry no total so the chart leaves them empty.
    private func makeDiaryMonthlyTotalItem(from total: MonthlyCumulativeTotal, isFirst: Bool) -> DiaryMonthlyTotalItem {
        let isJanuary: Bool = Calendar.current.component(.month, from: total.monthStart) == 1
        let yearLabel: String? = (isFirst || isJanuary) ? Self.yearLabelFormatter.string(from: total.monthStart) : nil
        return DiaryMonthlyTotalItem(
            id: Self.monthIDFormatter.string(from: total.monthStart),
            monthLabel: Self.monthLabelFormatter.string(from: total.monthStart),
            yearLabel: yearLabel,
            total: total.addedCount > 0 ? total.total : nil
        )
    }

    // WHY: maps the domain preference to the package-owned chart style so the feature never sees domain types.
    private func makeProgressChartStyle(from style: ProgressSummaryStyle) -> ProgressChartStyle {
        switch style {
        case .dailyActivity: return .heatmap
        case .monthlyCumulativeTotal: return .cumulativeBars
        }
    }

    // WHY: blank or unchanged names are ignored so dismissing the settings sheet never erases or rewrites a list name.
    private func renameEditingList(to name: String) {
        let trimmedName: String = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let editingListID,
              !trimmedName.isEmpty,
              let list: DiaryList = appStore.state.lists.first(where: { $0.id == editingListID }),
              list.name != trimmedName else { return }
        appStore.renameList(listID: editingListID, name: trimmedName)
    }

    // WHY: resolves the domain entry by id before deletion so the view layer
    // only passes an opaque identifier — not a domain type.
    private func deleteEntryMatchingID(_ id: UUID) {
        guard let entry: DiaryEntry = appStore.state.entries.first(where: { $0.id == id }) else { return }
        appStore.deleteEntry(entry)
    }

    // WHY: resolving the selected domain list here keeps deletion events opaque to the feature package.
    private func deleteListMatchingID(_ id: UUID) {
        guard let list: DiaryList = appStore.state.lists.first(where: { $0.id == id }) else { return }
        appStore.deleteList(list)
    }
}
