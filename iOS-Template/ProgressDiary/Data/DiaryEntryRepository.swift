import Combine
import Foundation

protocol DiaryEntryRepository {
    var entriesPublisher: AnyPublisher<[DiaryEntry], Never> { get }
    var listsPublisher: AnyPublisher<[DiaryList], Never> { get }
    func addEntry(text: String, to listID: UUID)
    func deleteEntry(_ entry: DiaryEntry)
    func addList(name: String)
    func deleteList(_ list: DiaryList)
    func updateListName(listID: UUID, name: String)
    func updateListHeatmapColor(listID: UUID, colorID: String)
    func updateListStreakEnabled(listID: UUID, isEnabled: Bool)
}
