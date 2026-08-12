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
    // MARK: - 顺序优化（最近邻 + 2-opt）

    /// 返回优化后的索引顺序。固定首尾（元素数 >= 3 时尾部固定），只重排中间点。
    static func optimizeOrder(coordinates: [CLLocationCoordinate2D]) -> [Int] {
        let count = coordinates.count
        guard count > 2 else { return Array(0..<count) }

        var distance = [[Double]](repeating: [Double](repeating: 0, count: count), count: count)
        for i in 0..<count {
            for j in (i + 1)..<count {
                let d = haversine(coordinates[i], coordinates[j])
                distance[i][j] = d
                distance[j][i] = d
            }
        }

        // 最近邻：从 0 出发，终点 count-1 固定，遍历中间点。
        let last = count - 1
        var remaining = Set(1..<last)
        var order = [0]
        var current = 0
        while !remaining.isEmpty {
            guard let next = remaining.min(by: { distance[current][$0] < distance[current][$1] }) else { break }
            order.append(next)
            remaining.remove(next)
            current = next
        }
        order.append(last)

        // 2-opt：反转能缩短总长的区间，首尾位置不参与交换。
        var improved = true
        while improved {
            improved = false
            guard order.count >= 4 else { break }
            for i in 1..<(order.count - 2) {
                for j in (i + 1)..<(order.count - 1) {
                    let a = order[i - 1], b = order[i]
                    let c = order[j], d = order[j + 1]
                    let before = distance[a][b] + distance[c][d]
                    let after = distance[a][c] + distance[b][d]
                    if after + 0.001 < before {
                        order.replaceSubrange(i...j, with: order[i...j].reversed())
                        improved = true
                    }
                }
            }
        }
        return order
    }

    /// 按给定顺序的连线总长度（米），用于校验优化效果。
    static func totalDistance(coordinates: [CLLocationCoordinate2D]) -> Double {
        guard coordinates.count > 1 else { return 0 }
        var total = 0.0
        for i in 0..<(coordinates.count - 1) {
            total += haversine(coordinates[i], coordinates[i + 1])
        }
        return total
    }

    static func haversine(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let earthRadius = 6_371_000.0
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earthRadius * atan2(sqrt(h), sqrt(1 - h))
    }

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
                let estimated = haversine(fromCoord, toCoord) / mode.fallbackSpeed
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
