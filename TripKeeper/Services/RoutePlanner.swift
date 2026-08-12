import Foundation
import MapKit

/// 相邻两点的交通信息。
struct RouteLeg: Identifiable {
    let id = UUID()
    let fromTitle: String
    let toTitle: String
    let duration: TimeInterval
    /// MKDirections 失败时按直线距离估算，UI 需标注「估算」。
    let isEstimated: Bool
}

enum RouteTransportMode: String, CaseIterable, Identifiable {
    case driving
    case walking

    var id: String { rawValue }

    var label: String {
        switch self {
        case .driving: return "驾车"
        case .walking: return "步行"
        }
    }

    var icon: String {
        switch self {
        case .driving: return "car.fill"
        case .walking: return "figure.walk"
        }
    }

    var mkTransportType: MKDirectionsTransportType {
        switch self {
        case .driving: return .automobile
        case .walking: return .walking
        }
    }

    /// 估算用平均速度（米/秒）：驾车按城市 30km/h，步行 4.5km/h。
    var fallbackSpeed: Double {
        switch self {
        case .driving: return 30_000.0 / 3600.0
        case .walking: return 4_500.0 / 3600.0
        }
    }
}

enum RoutePlanner {
    // MARK: - 交通时长

    /// 逐段计算交通时长；MKDirections 失败的段按直线距离 × 平均速度估算并标记。
    static func legs(
        for items: [ItineraryItem],
        mode: RouteTransportMode
    ) async -> [RouteLeg] {
        guard items.count > 1 else { return [] }
        var result: [RouteLeg] = []
        for i in 0..<(items.count - 1) {
            let from = items[i]
            let to = items[i + 1]
            guard let fromCoord = from.coordinate, let toCoord = to.coordinate else { continue }

            var duration: TimeInterval?
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: fromCoord))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: toCoord))
            request.transportType = mode.mkTransportType
            if let response = try? await MKDirections(request: request).calculate(),
               let route = response.routes.first {
                duration = route.expectedTravelTime
            }

            if let duration {
                result.append(RouteLeg(fromTitle: from.title, toTitle: to.title, duration: duration, isEstimated: false))
            } else {
                let estimated = RouteOptimizer.haversine(fromCoord, toCoord) / mode.fallbackSpeed
                result.append(RouteLeg(fromTitle: from.title, toTitle: to.title, duration: estimated, isEstimated: true))
            }
        }
        return result
    }

    // MARK: - 回写行程

    /// 把优化后的顺序与推算时间写回条目：
    /// - 顺序：参与规划的条目按新顺序占据当天最前的 sortIndex，未定位条目按原相对顺序排在其后；
    /// - 时间：锚点取第一个条目原开始时间（缺省 09:00），停留时长取原时长或类型默认值，
    ///   段间交通时长向上取整到 5 分钟。
    @MainActor
    static func apply(
        orderedItems: [ItineraryItem],
        legs: [RouteLeg],
        allDayItems: [ItineraryItem],
        dayDate: Date
    ) {
        let plannedIDs = Set(orderedItems.map(\.uid))
        let unplanned = allDayItems.filter { !plannedIDs.contains($0.uid) }

        for (index, item) in orderedItems.enumerated() {
            item.sortIndex = index
        }
        for (offset, item) in unplanned.enumerated() {
            item.sortIndex = orderedItems.count + offset
        }

        guard let first = orderedItems.first else { return }
        let anchor = first.startTime ?? (
            Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: dayDate) ?? dayDate
        )

        var cursor = anchor
        for (index, item) in orderedItems.enumerated() {
            let duration = item.effectiveDurationSeconds
            item.startTime = cursor
            item.endTime = cursor.addingTimeInterval(duration)
            cursor = cursor.addingTimeInterval(duration)
            if index < legs.count {
                let travel = ceil(legs[index].duration / 300) * 300
                cursor = cursor.addingTimeInterval(travel)
            }
        }
    }
}
