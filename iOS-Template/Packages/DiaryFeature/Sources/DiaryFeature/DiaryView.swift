import SwiftUI
import UIKit

public struct DiaryView<Model: DiaryViewModel>: View {
    @ObservedObject public var model: Model
    @State private var addEntryHapticTrigger: Int = 0

    public init(model: Model) {
        self.model = model
        Self.configureRoundedNavigationTitleFont()
    }

    public var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle(model.currentListName)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { streakBadge }
                    listMenu
                }
                .sheet(isPresented: addEntryBinding) {
                    AddEntrySheet(model: model)
                }
                .sheet(isPresented: addListBinding) {
                    AddListSheet(model: model)
                }
                .sheet(isPresented: listSettingsBinding) {
                    listSettingsSheet
                }
                .alert("Delete \(model.currentListName)?", isPresented: deleteListConfirmationBinding) {
                    Button("Cancel", role: .cancel) { }
                    Button("Delete", role: .destructive) {
                        model.send(.deleteCurrentListConfirmed)
                    }
                } message: {
                    Text("All entries in this list will be deleted.")
                }
        }
    }

    @ViewBuilder
    private var streakBadge: some View {
        if let streak: DiaryStreakItem = model.selectedListStreak {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                Text("\(streak.currentDays)")
                    .monospacedDigit()
            }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
                .accessibilityLabel("\(streak.currentDays) day streak")
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            heatmapSection
            pagedEntryLists
        }
    }

    private var heatmapSection: some View {
        HStack(alignment: .center, spacing: 4) {
            progressChart
                .frame(maxWidth: .infinity)
            progressChartStyleToggleButton
        }
            .padding(.leading)
            .padding(.trailing, 8)
            .padding(.vertical, 8)
    }

    @ViewBuilder
    private var progressChart: some View {
        switch model.progressChartStyle {
        case .heatmap:
            HeatmapView(
                activeDayKeys: activeDayKeysForSelectedList,
                activeColor: heatmapColorForSelectedList.color
            )
        case .cumulativeBars:
            CumulativeBarChartView(
                monthlyTotals: monthlyTotalsForSelectedList,
                barColor: heatmapColorForSelectedList.color
            )
        }
    }

    private var progressChartStyleToggleButton: some View {
        Button {
            model.send(.progressChartStyleToggled)
        } label: {
            Image(systemName: progressChartStyleToggleIconName)
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(progressChartStyleToggleAccessibilityLabel)
    }

    private var progressChartStyleToggleIconName: String {
        switch model.progressChartStyle {
        case .heatmap: return "chart.bar.fill"
        case .cumulativeBars: return "square.grid.3x3.fill"
        }
    }

    private var progressChartStyleToggleAccessibilityLabel: String {
        switch model.progressChartStyle {
        case .heatmap: return "Show cumulative monthly chart"
        case .cumulativeBars: return "Show heatmap"
        }
    }

    private var pagedEntryLists: some View {
        TabView(selection: selectedListBinding) {
            ForEach(model.lists) { list in
                entryList(for: list)
                    .tag(list.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .overlay(alignment: .bottomTrailing) {
            floatingAddEntryButton
                .padding(.trailing, 16)
                .padding(.bottom, 16)
        }
    }

    private func entryList(for list: DiaryListItem) -> some View {
        let entries: [DiaryEntryItem] = model.entriesByListID[list.id] ?? []
        return List {
            ForEach(entries) { entry in
                DiaryEntryRow(item: entry)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
            .onDelete { indexSet in
                for index in indexSet { model.send(.deleteEntry(entries[index].id)) }
            }
        }
        .listStyle(.plain)
        .modifier(TopListBoundaryFadeModifier())
    }

    private var listMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                ForEach(model.lists) { list in
                    Menu {
                        Button {
                            model.send(.listSelected(list.id))
                        } label: {
                            if list.id == model.selectedListID {
                                Label("Select", systemImage: "checkmark")
                            } else {
                                Text("Select")
                            }
                        }
                        Button {
                            model.send(.listSettingsTapped(list.id))
                        } label: {
                            Label("List Settings", systemImage: "slider.horizontal.3")
                        }
                    } label: {
                        Label(list.name, systemImage: DiaryHeatmapColor(rawValue: list.heatmapColorID)?.rawValue == nil ? "list.bullet" : "circle.fill")
                    }
                }
                Divider()
                Button {
                    model.send(.addListTapped)
                } label: {
                    Label("New List", systemImage: "plus")
                }
                if model.lists.count > 1 {
                    Menu {
                        Button(role: .destructive) {
                            model.send(.deleteCurrentListRequested)
                        } label: {
                            Label("Delete Current List", systemImage: "trash")
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "list.bullet")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
    }

    private var floatingAddEntryButton: some View {
        floatingAddEntryButtonBase
            .glassEffect(.regular, in: .circle)
    }

    private var floatingAddEntryButtonBase: some View {
        Button {
            presentAddEntrySheet()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .frame(width: 56, height: 56)
                .contentShape(Circle())
        }
        .foregroundStyle(.primary)
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: addEntryHapticTrigger)
    }

    private var addEntryBinding: Binding<Bool> {
        Binding(
            get: { model.isShowingAddEntry },
            set: { model.isShowingAddEntry = $0 }
        )
    }

    private var addListBinding: Binding<Bool> {
        Binding(get: { model.isShowingAddList }, set: { model.isShowingAddList = $0 })
    }

    private var listSettingsBinding: Binding<Bool> {
        Binding(get: { model.isShowingListSettings }, set: { model.isShowingListSettings = $0 })
    }

    private var deleteListConfirmationBinding: Binding<Bool> {
        Binding(
            get: { model.isShowingDeleteListConfirmation },
            set: { model.isShowingDeleteListConfirmation = $0 }
        )
    }

    @ViewBuilder
    private var listSettingsSheet: some View {
        if let editingList = model.lists.first(where: { $0.id == model.editingListID }) {
            ListSettingsSheet(model: model, list: editingList)
        }
    }

    private var selectedListBinding: Binding<UUID> {
        Binding(
            get: { model.selectedListID ?? model.lists.first?.id ?? UUID() },
            set: { model.send(.listSelected($0)) }
        )
    }

    private var activeDayKeysForSelectedList: Set<String> {
        guard let selectedListID = model.selectedListID else { return Set<String>() }
        return model.activeDayKeysByListID[selectedListID] ?? Set<String>()
    }

    private var monthlyTotalsForSelectedList: [DiaryMonthlyTotalItem] {
        guard let selectedListID = model.selectedListID else { return [] }
        return model.monthlyTotalsByListID[selectedListID] ?? []
    }

    private var heatmapColorForSelectedList: DiaryHeatmapColor {
        guard let selectedListID = model.selectedListID,
              let list = model.lists.first(where: { $0.id == selectedListID }) else { return .yellow }
        return DiaryHeatmapColor(rawValue: list.heatmapColorID) ?? .yellow
    }

    private func presentAddEntrySheet() {
        addEntryHapticTrigger += 1
        model.send(.addEntryTapped)
    }

    private static func configureRoundedNavigationTitleFont() {
        let navigationBarAppearance: UINavigationBar = UINavigationBar.appearance()
        navigationBarAppearance.titleTextAttributes = [
            .font: makeScaledRoundedFont(size: 17, weight: .semibold, textStyle: .headline)
        ]
        navigationBarAppearance.largeTitleTextAttributes = [
            .font: makeScaledRoundedFont(size: 34, weight: .bold, textStyle: .largeTitle)
        ]
    }

    private static func makeScaledRoundedFont(
        size: CGFloat,
        weight: UIFont.Weight,
        textStyle: UIFont.TextStyle
    ) -> UIFont {
        let baseFont: UIFont = UIFont.systemFont(ofSize: size, weight: weight)
        let roundedDescriptor: UIFontDescriptor = baseFont.fontDescriptor.withDesign(.rounded) ?? baseFont.fontDescriptor
        let roundedFont: UIFont = UIFont(descriptor: roundedDescriptor, size: size)
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: roundedFont)
    }
}

private struct TopListBoundaryFadeModifier: ViewModifier {
    private let fadeHeight: CGFloat = 24

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemBackground).opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
                .frame(height: fadeHeight)
                .allowsHitTesting(false)
        }
    }
}

private struct ListSettingsSheet<Model: DiaryViewModel>: View {
    @ObservedObject var model: Model
    let list: DiaryListItem

    private let columns: [GridItem] = [GridItem(.adaptive(minimum: 64), spacing: 16)]

    var body: some View {
        NavigationStack {
            Form {
                Section("Streak") {
                    Toggle("Track Streak", isOn: Binding(get: { list.isStreakEnabled }, set: { model.send(.streakTrackingChanged($0)) }))
                    Text("Track consecutive posting days for this category.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Heatmap Color") {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(DiaryHeatmapColor.allCases) { color in
                            Button {
                                model.send(.heatmapColorSelected(color.id))
                            } label: {
                                VStack(spacing: 6) {
                                    Circle()
                                        .fill(color.color)
                                        .frame(width: 32, height: 32)
                                        .overlay {
                                            if color.id == list.heatmapColorID {
                                                Image(systemName: "checkmark")
                                                    .font(.caption.bold())
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                    Text(color.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.primary)
                                }
                                .frame(minWidth: 44, minHeight: 56)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle(list.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        model.isShowingListSettings = false
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                }
            }
        }
    }
}

private struct AddListSheet<Model: DiaryViewModel>: View {
    @ObservedObject var model: Model
    @State private var name: String = ""
    @FocusState private var isNameFieldFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                TextField("List name", text: $name)
                    .focused($isNameFieldFocused)
            }
            .navigationTitle("New List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        model.isShowingAddList = false
                    } label: {
                        Text("Cancel")
                            .frame(minWidth: 60, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        let trimmedName: String = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        model.send(.listNameSubmitted(trimmedName))
                    } label: {
                        Text("Add")
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .task { isNameFieldFocused = true }
        }
    }
}

private struct DiaryEntryRow: View {
    let item: DiaryEntryItem

    var body: some View {
        HStack(alignment: .top) {
            Text(item.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(item.dateLabel)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct AddEntrySheet<Model: DiaryViewModel>: View {
    @ObservedObject var model: Model
    @State private var text: String = ""
    @FocusState private var isEntryFieldFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let streak: DiaryStreakItem = model.selectedListStreak {
                        if streak.hasEntryToday {
                            Label("Today’s entry complete", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Label("Today will be day \(streak.nextEntryDays)", systemImage: "flame.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                    TextField("What did you progress today?", text: $text, axis: .vertical)
                        .lineLimit(3...6)
                        .focused($isEntryFieldFocused)
                }
            }
            .navigationTitle("New Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                cancelButton
                submitButton
            }
            .task {
                isEntryFieldFocused = true
            }
        }
    }

    private var cancelButton: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button {
                model.isShowingAddEntry = false
            } label: {
                Text("Cancel")
                    .fixedSize()
                    .frame(minWidth: 60, minHeight: 44)
                    .contentShape(Rectangle())
            }
        }
    }

    private var submitButton: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button {
                let trimmed: String = text.trimmingCharacters(in: .whitespaces)
                model.send(.entryTextSubmitted(trimmed))
            } label: {
                Text("Add")
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}
