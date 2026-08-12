import Foundation
import SwiftData
import CoreLocation

@Model
final class ItineraryItem {
    var title: String = ""
    var typeRaw: String = ItemType.attraction.rawValue
    /// 属于行程的第几天（0 起）。
    var dayIndex: Int = 0
    /// 当天内的排序位置。
    var sortIndex: Int = 0
    var startTime: Date?
    var endTime: Date?
    var locationName: String = ""
    var address: String = ""
    var latitude: Double?
    var longitude: Double?
    var notes: String = ""
    /// 门票/票价/房费，0 表示未填。
    var price: Double = 0

    // 点对点交通类字段（航班号/车次等）
    var transportNumber: String = ""
    var departurePlace: String = ""
    var arrivalPlace: String = ""

    // 酒店字段
    var checkInDate: Date?
    var checkOutDate: Date?

    // 预订信息
    var platformRaw: String = ""
    var customPlatformName: String = ""
    var orderNumber: String = ""
    var phoneNumber: String = ""
    var bookingURLString: String = ""

    var createdAt: Date = Date()
    var trip: Trip?

    @Relationship(deleteRule: .cascade, inverse: \Attachment.item)
    var attachments: [Attachment] = []

    init(title: String, type: ItemType, dayIndex: Int, sortIndex: Int = 0) {
        self.title = title
        self.typeRaw = type.rawValue
        self.dayIndex = dayIndex
        self.sortIndex = sortIndex
        self.createdAt = Date()
    }

    var type: ItemType {
        get { ItemType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    var platform: BookingPlatform? {
        get { BookingPlatform(rawValue: platformRaw) }
        set { platformRaw = newValue?.rawValue ?? "" }
    }

    /// 平台显示名（自定义平台用用户填写的名称）。
    var platformDisplayName: String? {
        guard let platform else { return nil }
        if platform == .custom {
            return customPlatformName.isEmpty ? "自定义平台" : customPlatformName
        }
        return platform.label
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var bookingURL: URL? {
        guard !bookingURLString.isEmpty else { return nil }
        return URL(string: bookingURLString)
    }

    /// 是否填写了任一预订信息（用于决定卡片是否显示操作按钮区）。
    var hasBookingInfo: Bool {
        platform != nil || !orderNumber.isEmpty || !phoneNumber.isEmpty || bookingURL != nil
    }

    /// 已填开始/结束时间时的时长，否则用类型默认时长。
    var effectiveDurationSeconds: TimeInterval {
        if let startTime, let endTime, endTime > startTime {
            return endTime.timeIntervalSince(startTime)
        }
        return TimeInterval(type.defaultDurationMinutes * 60)
    }

    /// 时间轴副标题：交通类显示「出发 → 到达」，酒店显示入住/退房，其余显示地点。
    var subtitle: String {
        switch type {
        case .flight, .train, .transport:
            let route = [departurePlace, arrivalPlace].filter { !$0.isEmpty }.joined(separator: " → ")
            let parts = [transportNumber, route].filter { !$0.isEmpty }
            if !parts.isEmpty { return parts.joined(separator: " · ") }
        case .hotel:
            if let checkInDate, let checkOutDate {
                return "\(checkInDate.monthDayZH)入住 · \(checkOutDate.monthDayZH)退房"
            }
        default:
            break
        }
        return locationName.isEmpty ? address : locationName
    }
}

@Model
final class Attachment {
    @Attribute(.externalStorage) var data: Data = Data()
    var caption: String = ""
    var createdAt: Date = Date()
    var item: ItineraryItem?

    init(data: Data, caption: String = "") {
        self.data = data
        self.caption = caption
        self.createdAt = Date()
    }
}
