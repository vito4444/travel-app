// 独立验证用最小替身：让 BookingTextParser 与 RouteOptimizer 能脱离 iOS SDK 编译运行。
// 仅供 LinuxVerification/run.sh 使用，不参与 App 构建。
import Foundation

#if canImport(CoreLocation)
import CoreLocation
#else
struct CLLocationCoordinate2D {
    var latitude: Double
    var longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}
#endif

/// 与 App 内同名枚举保持 case 一致的替身（App 内版本带 SwiftUI 图标/颜色）。
enum ItemType: String, Equatable {
    case flight, train, hotel, attraction, food, transport, other
}

enum BookingPlatform: String, Equatable {
    case ctrip, qunar, fliggy, rail12306, meituan, dianping, elong, didi, umetrip, custom
}
