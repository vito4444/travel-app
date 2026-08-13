import SwiftUI
import SwiftData

/// 新建（trip == nil）或编辑行程基本信息。
struct TripEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let trip: Trip?

    @State private var name = ""
    @State private var destination = ""
    @State private var startDate = Date().startOfDay
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 2, to: Date().startOfDay) ?? Date()
    @State private var colorHex = Color.tripPresetHexes[0]
    @State private var budgetText = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("行程名称（如：五一成都行）", text: $name)
                    TextField("目的地（如：成都）", text: $destination)
                }
                Section("日期") {
                    DatePicker("出发", selection: $startDate, displayedComponents: .date)
                    DatePicker("返程", selection: $endDate, in: startDate..., displayedComponents: .date)
                    Text("共 \(max(1, startDate.daysUntil(endDate) + 1)) 天，每天自动生成日程分组")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("封面色") {
                    HStack(spacing: 12) {
                        ForEach(Color.tripPresetHexes, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 30, height: 30)
                                .overlay {
                                    if hex == colorHex {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                                .onTapGesture { colorHex = hex }
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("预算（可选）") {
                    TextField("总预算，单位元", text: $budgetText)
                        .keyboardType(.decimalPad)
                }
                Section("备注（可选）") {
                    TextField("签证、同行人等备注", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle(trip == nil ? "新建行程" : "行程设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let trip else { return }
        name = trip.name
        destination = trip.destination
        startDate = trip.startDate
        endDate = trip.endDate
        colorHex = trip.colorHex
        budgetText = trip.budget > 0 ? String(format: "%.0f", trip.budget) : ""
        notes = trip.notes
    }

    private func save() {
        let budget = Double(budgetText) ?? 0
        let target: Trip
        if let trip {
            target = trip
            trip.name = name
            trip.destination = destination
            trip.startDate = startDate.startOfDay
            trip.endDate = endDate.startOfDay
            trip.colorHex = colorHex
            trip.budget = budget
            trip.notes = notes
        } else {
            let newTrip = Trip(
                name: name,
                destination: destination,
                startDate: startDate.startOfDay,
                endDate: endDate.startOfDay,
                colorHex: colorHex,
                budget: budget
            )
            newTrip.notes = notes
            context.insert(newTrip)
            target = newTrip
        }
        dismiss()

        // 目的地转坐标（用于天气与地图初始视野），查不到保持为空。
        let query = destination
        Task { @MainActor in
            if let coord = await GeocodeService.coordinate(for: query) {
                target.destinationLatitude = coord.latitude
                target.destinationLongitude = coord.longitude
            }
        }
    }
}
