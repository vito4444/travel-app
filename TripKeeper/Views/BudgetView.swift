import SwiftUI
import SwiftData

/// 预算与记账：分类汇总 + 明细增删。
struct BudgetView: View {
    let trip: Trip
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var showAddSheet = false

    private var sortedExpenses: [Expense] {
        trip.expenses.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            List {
                summarySection
                categorySection
                detailSection
            }
            .navigationTitle("预算记账")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddExpenseView(trip: trip)
            }
        }
    }

    private var summarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(moneyTextZH(trip.totalExpense))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                if trip.budget > 0 {
                    ProgressView(value: min(trip.totalExpense, trip.budget), total: trip.budget)
                        .tint(trip.totalExpense > trip.budget ? .red : Color(hex: trip.colorHex))
                    Text(trip.totalExpense > trip.budget
                         ? "已超预算 \(moneyTextZH(trip.totalExpense - trip.budget))"
                         : "预算 \(moneyTextZH(trip.budget))，还剩 \(moneyTextZH(trip.budget - trip.totalExpense))")
                        .font(.caption)
                        .foregroundStyle(trip.totalExpense > trip.budget ? .red : .secondary)
                } else {
                    Text("未设置预算，可在「行程设置」里填写")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("总支出")
        }
    }

    @ViewBuilder
    private var categorySection: some View {
        let grouped = Dictionary(grouping: trip.expenses, by: \.category)
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
        if !grouped.isEmpty {
            Section("分类汇总") {
                ForEach(ExpenseCategory.allCases.filter { grouped[$0] != nil }) { category in
                    HStack {
                        Image(systemName: category.icon)
                            .foregroundStyle(category.color)
                            .frame(width: 24)
                        Text(category.label)
                        Spacer()
                        Text(moneyTextZH(grouped[category] ?? 0))
                            .font(.subheadline.monospacedDigit())
                    }
                }
            }
        }
    }

    private var detailSection: some View {
        Section("明细") {
            if sortedExpenses.isEmpty {
                Text("还没有记账，点右上角 + 添加一笔")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(sortedExpenses) { expense in
                HStack {
                    Image(systemName: expense.category.icon)
                        .foregroundStyle(expense.category.color)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(expense.note.isEmpty ? expense.category.label : expense.note)
                            .font(.subheadline)
                        Text(expense.date.monthDayZH)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(moneyTextZH(expense.amount))
                        .font(.subheadline.monospacedDigit().weight(.medium))
                }
            }
            .onDelete { offsets in
                let expenses = sortedExpenses
                for index in offsets where index < expenses.count {
                    context.delete(expenses[index])
                }
            }
        }
    }
}

struct AddExpenseView: View {
    let trip: Trip
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var amountText = ""
    @State private var category: ExpenseCategory = .food
    @State private var note = ""
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("金额") {
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.title2.monospacedDigit())
                }
                Section("分类") {
                    Picker("分类", selection: $category) {
                        ForEach(ExpenseCategory.allCases) { category in
                            Label(category.label, systemImage: category.icon)
                                .tag(category)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section("备注与日期") {
                    TextField("备注（如：大熊猫基地门票）", text: $note)
                    DatePicker("日期", selection: $date, displayedComponents: .date)
                }
            }
            .navigationTitle("记一笔")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(Double(amountText) == nil || (Double(amountText) ?? 0) <= 0)
                }
            }
        }
    }

    private func save() {
        guard let amount = Double(amountText), amount > 0 else { return }
        let expense = Expense(amount: amount, category: category, note: note, date: date)
        expense.trip = trip
        context.insert(expense)
        dismiss()
    }
}
