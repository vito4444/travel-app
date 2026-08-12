import SwiftUI
import SwiftData

struct TripDetailView: View {
    let trip: Trip
    @Environment(\.modelContext) private var context

    @State private var weatherByDay: [Int: DayWeather] = [:]
    @State private var editingItem: ItineraryItem?
    @State private var addTarget: AddTarget?
    @State private var showMap = false
    @State private var activeTool: ToolSheet?

    struct AddTarget: Identifiable {
        let id: Int
    }

    enum ToolSheet: String, Identifiable {
        case checklist, budget, importer, share, settings
        var id: String { rawValue }
    }

    var body: some View {
        List {
            overviewSection
            ForEach(0..<trip.dayCount, id: \.self) { day in
                daySection(day)
            }
        }
        .navigationTitle(trip.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showMap = true
                } label: {
                    Label("地图规划", systemImage: "map")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { activeTool = .checklist } label: { Label("行前清单", systemImage: "checklist") }
                    Button { activeTool = .budget } label: { Label("预算记账", systemImage: "yensign.circle") }
                    Button { activeTool = .importer } label: { Label("粘贴订票信息导入", systemImage: "square.and.arrow.down.on.square") }
                    Button { activeTool = .share } label: { Label("分享导出", systemImage: "square.and.arrow.up") }
                    Divider()
                    Button { activeTool = .settings } label: { Label("行程设置", systemImage: "gearshape") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(item: $editingItem) { item in
            ItemEditorView(trip: trip, existing: item, defaultDay: item.dayIndex)
        }
        .sheet(item: $addTarget) { target in
            ItemEditorView(trip: trip, existing: nil, defaultDay: target.id)
        }
        .fullScreenCover(isPresented: $showMap) {
            DayMapView(trip: trip)
        }
        .sheet(item: $activeTool) { tool in
            switch tool {
            case .checklist: ChecklistView(trip: trip)
            case .budget: BudgetView(trip: trip)
            case .importer: ImportView(trip: trip)
            case .share: ShareTripView(trip: trip)
            case .settings: TripEditorView(trip: trip)
            }
        }
        .task {
            await loadWeather()
        }
    }

    // MARK: - 顶部概览

    private var overviewSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(trip.destination.isEmpty ? "未设置目的地" : trip.destination, systemImage: "mappin.circle.fill")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text(trip.statusText)
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(hex: trip.colorHex).opacity(0.15), in: Capsule())
                        .foregroundStyle(Color(hex: trip.colorHex))
                }
                Text("\(trip.startDate.yearMonthDayZH) - \(trip.endDate.monthDayZH) · 共\(trip.dayCount)天 · \(trip.items.count)个安排")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if trip.budget > 0 || trip.totalExpense > 0 {
                    Text(budgetLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !trip.notes.isEmpty {
                    Text(trip.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var budgetLine: String {
        if trip.budget > 0 {
            return "已花 \(moneyTextZH(trip.totalExpense)) / 预算 \(moneyTextZH(trip.budget))"
        }
        return "已花 \(moneyTextZH(trip.totalExpense))"
    }

    // MARK: - 每日分组

    private func daySection(_ day: Int) -> some View {
        Section {
            let dayItems = trip.items(forDay: day)
            ForEach(dayItems) { item in
                ItemRowView(item: item)
                    .contentShape(Rectangle())
                    .onTapGesture { editingItem = item }
                    .contextMenu { navigationMenu(for: item) }
            }
            .onMove { source, destination in
                move(day: day, from: source, to: destination)
            }
            .onDelete { offsets in
                delete(day: day, offsets: offsets)
            }

            Button {
                addTarget = AddTarget(id: day)
            } label: {
                Label("添加安排", systemImage: "plus.circle")
                    .font(.subheadline)
            }
            .buttonStyle(.borderless)
        } header: {
            dayHeader(day)
        }
    }

    private func dayHeader(_ day: Int) -> some View {
        let date = trip.date(forDay: day)
        return HStack {
            Text("第\(day + 1)天 · \(date.monthDayZH) \(date.weekdayZH)")
                .font(.footnote.weight(.semibold))
            Spacer()
            WeatherBadge(weather: weatherByDay[day])
        }
    }

    @ViewBuilder
    private func navigationMenu(for item: ItineraryItem) -> some View {
        if let coordinate = item.coordinate {
            Menu {
                ForEach(DeepLinkService.MapApp.allCases) { app in
                    Button(app.label) {
                        DeepLinkService.navigate(
                            to: coordinate,
                            name: item.locationName.isEmpty ? item.title : item.locationName,
                            via: app
                        )
                    }
                }
            } label: {
                Label("导航到这里", systemImage: "location.fill")
            }
        }
        Button(role: .destructive) {
            context.delete(item)
        } label: {
            Label("删除条目", systemImage: "trash")
        }
    }

    // MARK: - 数据操作

    private func move(day: Int, from source: IndexSet, to destination: Int) {
        var dayItems = trip.items(forDay: day)
        dayItems.move(fromOffsets: source, toOffset: destination)
        for (index, item) in dayItems.enumerated() {
            item.sortIndex = index
        }
    }

    private func delete(day: Int, offsets: IndexSet) {
        let dayItems = trip.items(forDay: day)
        for index in offsets where index < dayItems.count {
            context.delete(dayItems[index])
        }
    }

    private func loadWeather() async {
        var coordinate: (lat: Double, lon: Double)?
        if let lat = trip.destinationLatitude, let lon = trip.destinationLongitude {
            coordinate = (lat, lon)
        } else if let itemCoord = trip.items.compactMap(\.coordinate).first {
            coordinate = (itemCoord.latitude, itemCoord.longitude)
        }
        guard let coordinate else { return }
        let byDate = await WeatherService.forecast(
            latitude: coordinate.lat,
            longitude: coordinate.lon,
            start: trip.startDate,
            end: trip.endDate
        )
        var mapped: [Int: DayWeather] = [:]
        for day in 0..<trip.dayCount {
            if let weather = byDate[trip.date(forDay: day).startOfDay] {
                mapped[day] = weather
            }
        }
        weatherByDay = mapped
    }
}

/// 天气徽标：有数据显示图标+温度区间，无数据显示「—」。
struct WeatherBadge: View {
    let weather: DayWeather?

    var body: some View {
        if let weather {
            HStack(spacing: 4) {
                Image(systemName: weather.symbol)
                    .symbolRenderingMode(.multicolor)
                Text(weather.tempText)
                    .monospacedDigit()
            }
            .font(.caption)
        } else {
            Text("—")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}
