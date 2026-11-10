import SwiftUI
import SwiftData

@main
struct ProgressDiaryApp: App {
    private let modelContainer: ModelContainer
    @StateObject private var appStore: AppStore

    init() {
        let container: ModelContainer
        do {
            let configuration: ModelConfiguration = ModelConfiguration(cloudKitDatabase: .automatic)
            container = try ModelContainer(
                for: DiaryEntryRecord.self, DiaryListRecord.self,
                configurations: configuration
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        let repository: SwiftDataDiaryEntryRepository = SwiftDataDiaryEntryRepository(
            modelContext: container.mainContext
        )
        self.modelContainer = container
        let styleRepository: UserDefaultsProgressSummaryStyleRepository = UserDefaultsProgressSummaryStyleRepository()
        _appStore = StateObject(wrappedValue: AppStore(
            diaryEntryRepository: repository,
            progressSummaryStyleRepository: styleRepository
        ))
    }

    var body: some Scene {
        WindowGroup {
            DiaryHost(appStore: appStore)
        }
    }
}
