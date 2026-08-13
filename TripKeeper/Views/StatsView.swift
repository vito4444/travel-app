import SwiftUI
import SwiftData
import MapKit

/// 足迹统计：行程数、旅行天数、目的地列表与足迹地图。
struct StatsView: View {
    @Query(sort: \Trip.startDate) private var trips: [Trip]

    private var totalDays: Int {
        trips.reduce(0) { $0 + $1.dayCount }
    }

    private var destinations: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for trip in trips {
            let name = trip.destination.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, !seen.contains(name) else { continue }
            seen.insert(name)
            result.append(name)
        }
        return result
    }

    private var locatedItems: [ItineraryItem] {
        trips.flatMap(\.items).filter { $0.coordinate != nil }
    }

    var body: some View {
        NavigationStack {
            Group {
                if trips.isEmpty {
                    ContentUnavailableView(
                        "还没有足迹",
                        systemImage: "map",
                        description: Text("创建行程并添加带定位的安排后，这里会点亮你的足迹地图")
                    )
                } else {
                    content
                }
            }
            .navigationTitle("我的足迹")
        }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    statCard(value: "\(trips.count)", label: "段旅程", icon: "suitcase.fill", color: .blue)
                    statCard(value: "\(totalDays)", label: "天在路上", icon: "calendar", color: .orange)
                    statCard(value: "\(destinations.count)", label: "个目的地", icon: "mappin.and.ellipse", color: .green)
                }

                footprintMap

                if !destinations.isEmpty {
                    destinationList
                }
            }
            .padding(16)
        }
    }

    private func statCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.bold().monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var footprintMap: some View {
        Map {
            ForEach(locatedItems, id: \.uid) { item in
                if let coordinate = item.coordinate {
                    Annotation(item.title, coordinate: coordinate) {
                        Circle()
                            .fill(item.type.color)
                            .frame(width: 9, height: 9)
                            .overlay(Circle().stroke(.white, lineWidth: 1.5))
                            .shadow(radius: 1)
                    }
                    .annotationTitles(.hidden)
                }
            }
        }
        .frame(height: 300)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(alignment: .bottomLeading) {
            Text("共 \(locatedItems.count) 个打卡点")
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.thinMaterial, in: Capsule())
                .padding(8)
        }
    }

    private var destinationList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("去过的目的地")
                .font(.subheadline.bold())
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 8) {
                ForEach(destinations, id: \.self) { destination in
                    Text(destination)
                        .font(.caption)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
