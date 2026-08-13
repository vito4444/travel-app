import Foundation
#if canImport(CoreLocation)
import CoreLocation
#endif

/// 纯算法部分：顺序优化与距离计算（不依赖 MapKit，可独立验证）。
enum RouteOptimizer {
    /// 返回优化后的索引顺序。固定首尾（元素数 >= 3 时尾部固定），只重排中间点。
    /// 算法：最近邻构造初始解 + 2-opt 迭代改进。
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

        // 最近邻：从 0 出发，终点 count-1 固定，贪心遍历中间点。
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

    /// 按给定顺序的连线总长度（米）。
    static func totalDistance(coordinates: [CLLocationCoordinate2D]) -> Double {
        guard coordinates.count > 1 else { return 0 }
        var total = 0.0
        for i in 0..<(coordinates.count - 1) {
            total += haversine(coordinates[i], coordinates[i + 1])
        }
        return total
    }

    /// 球面距离（米）。
    static func haversine(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let earthRadius = 6_371_000.0
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earthRadius * atan2(sqrt(h), sqrt(1 - h))
    }
}
