import Combine
import Foundation

class AppStore: Store<AppState> {
    private let diaryEntryRepository: any DiaryEntryRepository
    private let progressSummaryStyleRepository: any ProgressSummaryStyleRepository
    private var cancellables: Set<AnyCancellable> = Set<AnyCancellable>()

    // WHY: dependency injection keeps the single state owner testable while persistence remains outside the domain state.
    init(
        diaryEntryRepository: some DiaryEntryRepository,
        progressSummaryStyleRepository: some ProgressSummaryStyleRepository
    ) {
        self.diaryEntryRepository = diaryEntryRepository
        self.progressSummaryStyleRepository = progressSummaryStyleRepository
        var initialState: AppState = AppState()
        initialState.progressSummaryStyle = progressSummaryStyleRepository.loadStyle()
        super.init(initialState: initialState)
        observeEntries()
        observeLists()
    }

    // WHY: mirrors the repository's published list into state so every observing view
    // stays reactive to inserts and deletes without touching the repository directly.
    private func observeEntries() {
        diaryEntryRepository.entriesPublisher
            .sink { [weak self] newEntries in
                guard let self else { return }
                self.setState { $0.entries = newEntries }
            }
            .store(in: &cancellables)
    }

    // WHY: list changes define the available pages and must arrive in the same state stream as entries.
    private func observeLists() {
        diaryEntryRepository.listsPublisher
            .sink { [weak self] newLists in
                guard let self else { return }
                self.setState { state in
                    state.lists = newLists
                    if state.selectedListID == nil || !newLists.contains(where: { $0.id == state.selectedListID }) {
                        state.selectedListID = newLists.first?.id
                    }
                }
            }
            .store(in: &cancellables)
    }
}

extension AppStore {
    // WHY: the store is the single door to persistence; views must not reach into the repository.
    func addEntry(text: String, to listID: UUID) {
        diaryEntryRepository.addEntry(text: text, to: listID)
    }

    // WHY: routes deletion through the store so the view layer stays unaware of persistence types.
    func deleteEntry(_ entry: DiaryEntry) {
        diaryEntryRepository.deleteEntry(entry)
    }

    // WHY: the selected list is navigation state shared by the page view and the entry actions.
    func selectList(_ listID: UUID) {
        setState { $0.selectedListID = listID }
    }

    // WHY: list creation is a domain action so the selected page can remain independent of persistence details.
    func addList(name: String) {
        diaryEntryRepository.addList(name: name)
        if let newListID: UUID = state.lists.last?.id {
            selectList(newListID)
        }
    }

    // WHY: the repository owns cascade deletion so a removed list cannot leave orphaned entries.
    func deleteList(_ list: DiaryList) {
        guard state.lists.count > 1 else { return }
        diaryEntryRepository.deleteList(list)
    }

    // WHY: routes color changes through persistence so every page observes the same saved list identity.
    func updateListHeatmapColor(listID: UUID, colorID: String) {
        diaryEntryRepository.updateListHeatmapColor(listID: listID, colorID: colorID)
    }

    // WHY: the summary style is a saved preference, so the change is persisted alongside the state update.
    func toggleProgressSummaryStyle() {
        let newStyle: ProgressSummaryStyle = state.progressSummaryStyle.toggled
        setState { $0.progressSummaryStyle = newStyle }
        progressSummaryStyleRepository.saveStyle(newStyle)
    }

    // WHY: routes the category-specific preference through the persistence boundary.
    func updateListStreakEnabled(listID: UUID, isEnabled: Bool) {
        diaryEntryRepository.updateListStreakEnabled(listID: listID, isEnabled: isEnabled)
    }
}
