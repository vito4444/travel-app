import SwiftUI
import MapKit
import SwiftData

/// 每日地图：标记 + 顺序连线 + 一键优化 + 应用回写行程。
struct DayMapView: View {
    let trip: Trip
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var selectedDay = 0
    @State private var mode: RouteTransportMode = .driving
    /// 参与规划（含坐标）的条目，按当前预览顺序。
    @State private var orderedItems: [ItineraryItem] = []
    @State private var legs: [RouteLeg] = []
    @State private var loadingLegs = false
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showAppliedToast = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                dayPicker
                mapArea
                controls
                legPanel
            }
            .navigationTitle("路线规划")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("完成") { dismiss() }
                }
            }
            .onAppear {
                selectDefaultDay()
                reload()
            }
            .onChange(of: selectedDay) {
                reload()
            }
            .onChange(of: mode) {
                Task { await recalcLegs() }
            }
        }
    }

    private var polylineCoordinates: [CLLocationCoordinate2D] {
        orderedItems.compactMap(\.coordinate)
    }

    // MARK: - 子视图

    private var dayPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(0..<trip.dayCount, id: \.self) { day in
                    let selected = day == selectedDay
                    Button {
                        selectedDay = day
                    } label: {
                        VStack(spacing: 1) {
                            Text("第\(day + 1)天")
                                .font(.caption.bold())
                            Text(trip.date(forDay: day).monthDayZH)
                                .font(.caption2)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            selected ? Color(hex: trip.colorHex) : Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                        .foregroundStyle(selected ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private var mapArea: some View {
        Map(position: $cameraPosition) {
            ForEach(Array(orderedItems.enumerated()), id: \.element.uid) { index, item in
                if let coordinate = item.coordinate {
                    Annotation(item.title, coordinate: coordinate) {
                        ZStack {
                            Circle()
                                .fill(item.type.color)
                                .frame(width: 26, height: 26)
                                .shadow(radius: 1.5)
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
            if polylineCoordinates.count > 1 {
                MapPolyline(coordinates: polylineCoordinates)
                    .stroke(Color(hex: trip.colorHex), style: StrokeStyle(lineWidth: 3, dash: [7, 4]))
            }
            UserAnnotation()
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .overlay {
            if orderedItems.isEmpty {
                ContentUnavailableView(
                    "本日暂无含定位的条目",
                    systemImage: "mappin.slash",
                    description: Text("在条目编辑页搜索并选择地点后，这里会出现标记与路线")
                )
                .background(.thinMaterial)
            }
        }
        .overlay(alignment: .bottom) {
            if showAppliedToast {
                Label("已应用到行程，时间轴同步更新", systemImage: "checkmark.circle.fill")
                    .font(.footnote.bold())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Picker("交通方式", selection: $mode) {
                ForEach(RouteTransportMode.allCases) { transportMode in
                    Label(transportMode.label, systemImage: transportMode.icon)
                        .tag(transportMode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 140)

            Button {
                optimize()
            } label: {
                Label("优化顺序", systemImage: "wand.and.stars")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .disabled(orderedItems.count < 3)

            Button {
                apply()
            } label: {
                Label("应用到行程", systemImage: "checkmark.circle")
                    .font(.subheadline)
            }
            .buttonStyle(.borderedProminent)
            .disabled(orderedItems.isEmpty || loadingLegs)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var legPanel: some View {
        List {
            if !polylineCoordinates.isEmpty {
                HStack {
                    Label("连线总长", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    Spacer()
                    Text(String(format: "%.1f 公里", RoutePlanner.totalDistance(coordinates: polylineCoordinates) / 1000))
                        .foregroundStyle(.secondary)
                }
                .font(.footnote)
            }
            if loadingLegs {
                HStack {
                    ProgressView()
                    Text("计算各段交通时长…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(Array(legs.enumerated()), id: \.element.id) { index, leg in
                    HStack(spacing: 6) {
                        Text("\(index + 1) → \(index + 2)")
                            .font(.caption.monospacedDigit().bold())
                            .foregroundStyle(.secondary)
                        Text(leg.toTitle)
                            .font(.footnote)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: mode.icon)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(durationTextZH(leg.duration))
                            .font(.footnote.monospacedDigit())
                        if leg.isEstimated {
                            Text("估算")
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.yellow.opacity(0.25), in: Capsule())
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .frame(height: 168)
    }

    // MARK: - 逻辑

    private func selectDefaultDay() {
        if case .ongoing(let dayNumber) = trip.status {
            selectedDay = min(max(0, dayNumber - 1), trip.dayCount - 1)
        } else {
            selectedDay = 0
        }
    }

    private func reload() {
        orderedItems = trip.items(forDay: selectedDay).filter { $0.coordinate != nil }
        legs = []
        cameraPosition = .automatic
        Task { await recalcLegs() }
    }

    private func recalcLegs() async {
        guard orderedItems.count > 1 else {
            legs = []
            return
        }
        loadingLegs = true
        legs = await RoutePlanner.legs(for: orderedItems, mode: mode)
        loadingLegs = false
    }

    private func optimize() {
        let coordinates = orderedItems.compactMap(\.coordinate)
        guard coordinates.count == orderedItems.count, coordinates.count > 2 else { return }
        let order = RoutePlanner.optimizeOrder(coordinates: coordinates)
        orderedItems = order.map { orderedItems[$0] }
        Task { await recalcLegs() }
    }

    private func apply() {
        RoutePlanner.apply(
            orderedItems: orderedItems,
            legs: legs,
            allDayItems: trip.items(forDay: selectedDay),
            dayDate: trip.date(forDay: selectedDay)
        )
        withAnimation {
            showAppliedToast = true
        }
        Task { @MainActor in
            await NotificationService.rescheduleAll(context: context)
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation {
                showAppliedToast = false
            }
        }
    }
}
