import SwiftUI
import SwiftData

/// 行前清单：模板导入 + 勾选 + 增删。
struct ChecklistView: View {
    let trip: Trip
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var newTitle = ""
    @State private var newCategory = "其他"

    private var doneCount: Int { trip.checklist.filter(\.isDone).count }

    private var categoriesInUse: [String] {
        ChecklistTemplate.categories.filter { category in
            trip.checklist.contains { $0.category == category }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                progressSection
                ForEach(categoriesInUse, id: \.self) { category in
                    categorySection(category)
                }
                addSection
            }
            .navigationTitle("行前清单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("导入全部模板") { importTemplate(categories: ChecklistTemplate.items.map(\.category)) }
                        Divider()
                        ForEach(ChecklistTemplate.items, id: \.category) { group in
                            Button("导入「\(group.category)」") { importTemplate(categories: [group.category]) }
                        }
                    } label: {
                        Label("模板", systemImage: "text.badge.plus")
                    }
                }
            }
        }
    }

    private var progressSection: some View {
        Section {
            let total = trip.checklist.count
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(total == 0 ? "清单为空" : "已完成 \(doneCount)/\(total)")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    if total > 0 && doneCount == total {
                        Label("全部就绪", systemImage: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                if total > 0 {
                    ProgressView(value: Double(doneCount), total: Double(total))
                        .tint(Color(hex: trip.colorHex))
                }
                if total == 0 {
                    Text("点右上角「模板」一键导入证件、电子、衣物、洗漱、药品五类常用物品。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func categorySection(_ category: String) -> some View {
        Section(category) {
            let items = trip.checklist
                .filter { $0.category == category }
                .sorted { ($0.sortIndex, $0.title) < ($1.sortIndex, $1.title) }
            ForEach(items) { item in
                Button {
                    item.isDone.toggle()
                } label: {
                    HStack {
                        Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(item.isDone ? .green : .secondary)
                        Text(item.title)
                            .strikethrough(item.isDone)
                            .foregroundStyle(item.isDone ? .secondary : .primary)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
            .onDelete { offsets in
                for index in offsets where index < items.count {
                    context.delete(items[index])
                }
            }
        }
    }

    private var addSection: some View {
        Section("添加物品") {
            HStack {
                TextField("物品名称", text: $newTitle)
                Picker("", selection: $newCategory) {
                    ForEach(ChecklistTemplate.categories, id: \.self) { category in
                        Text(category).tag(category)
                    }
                }
                .labelsHidden()
                .frame(width: 90)
                Button {
                    addItem()
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func addItem() {
        let title = newTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        let item = ChecklistItem(title: title, category: newCategory, sortIndex: trip.checklist.count)
        item.trip = trip
        context.insert(item)
        newTitle = ""
    }

    /// 导入模板，按标题去重。
    private func importTemplate(categories: [String]) {
        let existingTitles = Set(trip.checklist.map(\.title))
        var sortIndex = trip.checklist.count
        for group in ChecklistTemplate.items where categories.contains(group.category) {
            for title in group.titles where !existingTitles.contains(title) {
                let item = ChecklistItem(title: title, category: group.category, sortIndex: sortIndex)
                item.trip = trip
                context.insert(item)
                sortIndex += 1
            }
        }
    }
}
