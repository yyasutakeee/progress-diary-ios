import SwiftData
import Combine
import Foundation

@Model
final class DiaryEntryRecord {
    var id: UUID = UUID()
    var listID: UUID?
    var text: String = ""
    var createdAt: Date = Date()

    // WHY: initializes new records with stable identity and creation time before SwiftData inserts them.
    init(text: String) {
        self.id = UUID()
        self.listID = nil
        self.text = text
        self.createdAt = Date()
    }
}

@Model
final class DiaryListRecord {
    var id: UUID = UUID()
    var name: String = ""
    var heatmapColorID: String?
    var isStreakEnabled: Bool?
    var createdAt: Date = Date()

    // WHY: gives each persisted list its own identity so pages can remain selected across state updates.
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.heatmapColorID = "yellow"
        self.isStreakEnabled = false
        self.createdAt = Date()
    }
}

final class SwiftDataDiaryEntryRepository: DiaryEntryRepository {
    private let modelContext: ModelContext
    private let entriesSubject: CurrentValueSubject<[DiaryEntry], Never>
    private let listsSubject: CurrentValueSubject<[DiaryList], Never>

    var entriesPublisher: AnyPublisher<[DiaryEntry], Never> {
        entriesSubject.eraseToAnyPublisher()
    }

    var listsPublisher: AnyPublisher<[DiaryList], Never> {
        listsSubject.eraseToAnyPublisher()
    }

    // WHY: loads and repairs persisted data before publishers are exposed to the app store.
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.entriesSubject = CurrentValueSubject<[DiaryEntry], Never>([])
        self.listsSubject = CurrentValueSubject<[DiaryList], Never>([])
        ensureDefaultListAndPublish()
    }

    // WHY: inserts and persists immediately, then refreshes the publisher
    // so all observers see the new entry without a separate fetch trigger.
    func addEntry(text: String, to listID: UUID) {
        let record: DiaryEntryRecord = DiaryEntryRecord(text: text)
        record.listID = listID
        modelContext.insert(record)
        saveContext()
        loadAndPublishEntries()
    }

    // WHY: looks up the record by id so callers can use the plain DiaryEntry
    // value type rather than holding a reference to the @Model object.
    func deleteEntry(_ entry: DiaryEntry) {
        let id: UUID = entry.id
        let descriptor: FetchDescriptor<DiaryEntryRecord> = FetchDescriptor<DiaryEntryRecord>(
            predicate: #Predicate { $0.id == id }
        )
        guard let record: DiaryEntryRecord = try? modelContext.fetch(descriptor).first else { return }
        modelContext.delete(record)
        saveContext()
        loadAndPublishEntries()
    }

    // WHY: keeps list creation behind the repository so list persistence follows the same source-of-truth flow as entries.
    func addList(name: String) {
        let record: DiaryListRecord = DiaryListRecord(name: name)
        modelContext.insert(record)
        saveContext()
        loadAndPublishLists()
    }

    // WHY: removing a list through the repository lets its entries be removed together and keeps publishers consistent.
    func deleteList(_ list: DiaryList) {
        let id: UUID = list.id
        let descriptor: FetchDescriptor<DiaryListRecord> = FetchDescriptor<DiaryListRecord>(
            predicate: #Predicate { $0.id == id }
        )
        guard let record: DiaryListRecord = try? modelContext.fetch(descriptor).first else { return }
        let entryDescriptor: FetchDescriptor<DiaryEntryRecord> = FetchDescriptor<DiaryEntryRecord>(
            predicate: #Predicate { $0.listID == id }
        )
        let entries: [DiaryEntryRecord] = (try? modelContext.fetch(entryDescriptor)) ?? []
        entries.forEach { modelContext.delete($0) }
        modelContext.delete(record)
        saveContext()
        loadAndPublishLists()
        loadAndPublishEntries()
    }

    // WHY: updates only the name so a rename keeps the list's identity, entries, and settings intact.
    func updateListName(listID: UUID, name: String) {
        let descriptor: FetchDescriptor<DiaryListRecord> = FetchDescriptor<DiaryListRecord>(predicate: #Predicate { $0.id == listID })
        guard let record: DiaryListRecord = try? modelContext.fetch(descriptor).first else { return }
        record.name = name
        saveContext()
        loadAndPublishLists()
    }

    // WHY: persists a list's visual identity separately so changing a color never touches its entries.
    func updateListHeatmapColor(listID: UUID, colorID: String) {
        let descriptor: FetchDescriptor<DiaryListRecord> = FetchDescriptor<DiaryListRecord>(
            predicate: #Predicate { $0.id == listID }
        )
        guard let record: DiaryListRecord = try? modelContext.fetch(descriptor).first else { return }
        record.heatmapColorID = colorID
        saveContext()
        loadAndPublishLists()
    }

    // WHY: keeps the category's tracking preference alongside its other persisted settings.
    func updateListStreakEnabled(listID: UUID, isEnabled: Bool) {
        let descriptor: FetchDescriptor<DiaryListRecord> = FetchDescriptor<DiaryListRecord>(predicate: #Predicate { $0.id == listID })
        guard let record: DiaryListRecord = try? modelContext.fetch(descriptor).first else { return }
        record.isStreakEnabled = isEnabled
        saveContext()
        loadAndPublishLists()
    }

    // WHY: all mutations share one save call so none can bypass persistence.
    private func saveContext() {
        try? modelContext.save()
    }

    // WHY: re-fetches the full sorted list after every mutation so the publisher
    // always reflects the actual persisted state rather than an in-memory mirror.
    private func loadAndPublishEntries() {
        let descriptor: FetchDescriptor<DiaryEntryRecord> = FetchDescriptor<DiaryEntryRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let records: [DiaryEntryRecord] = (try? modelContext.fetch(descriptor)) ?? []
        entriesSubject.send(records.map(makeDiaryEntry))
    }

    // WHY: publishes lists in creation order so page order remains stable between launches.
    private func loadAndPublishLists() {
        let descriptor: FetchDescriptor<DiaryListRecord> = FetchDescriptor<DiaryListRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let records: [DiaryListRecord] = (try? modelContext.fetch(descriptor)) ?? []
        listsSubject.send(records.map(makeDiaryList))
    }

    // WHY: guarantees every existing entry has a valid list without requiring a destructive data reset.
    private func ensureDefaultListAndPublish() {
        let descriptor: FetchDescriptor<DiaryListRecord> = FetchDescriptor<DiaryListRecord>()
        let existingLists: [DiaryListRecord] = (try? modelContext.fetch(descriptor)) ?? []
        let defaultList: DiaryListRecord
        if let firstList: DiaryListRecord = existingLists.first {
            defaultList = firstList
        } else {
            let newList: DiaryListRecord = DiaryListRecord(name: "Progress")
            modelContext.insert(newList)
            defaultList = newList
        }
        assignMissingListColors(from: existingLists)
        assignUnownedEntries(to: defaultList.id)
        saveContext()
        loadAndPublishLists()
        loadAndPublishEntries()
    }

    // WHY: older records predate list ownership, so assigning them once preserves their history during migration.
    private func assignUnownedEntries(to listID: UUID) {
        let descriptor: FetchDescriptor<DiaryEntryRecord> = FetchDescriptor<DiaryEntryRecord>(
            predicate: #Predicate { $0.listID == nil }
        )
        let records: [DiaryEntryRecord] = (try? modelContext.fetch(descriptor)) ?? []
        records.forEach { $0.listID = listID }
    }

    // WHY: older list records have no color, so a stable fallback keeps migration additive and predictable.
    private func assignMissingListColors(from records: [DiaryListRecord]) {
        records.forEach { record in
            if record.heatmapColorID == nil { record.heatmapColorID = "yellow" }
            if record.isStreakEnabled == nil { record.isStreakEnabled = false }
        }
    }

    // WHY: converts @Model reference types into plain value types so the domain
    // layer has no dependency on SwiftData.
    private func makeDiaryEntry(from record: DiaryEntryRecord) -> DiaryEntry {
        DiaryEntry(id: record.id, listID: record.listID ?? UUID(), text: record.text, createdAt: record.createdAt)
    }

    // WHY: converts persistence references into a domain value so state remains independent of SwiftData.
    private func makeDiaryList(from record: DiaryListRecord) -> DiaryList {
        DiaryList(
            id: record.id,
            name: record.name,
            heatmapColorID: record.heatmapColorID ?? "yellow",
            isStreakEnabled: record.isStreakEnabled ?? false,
            createdAt: record.createdAt
        )
    }
}
