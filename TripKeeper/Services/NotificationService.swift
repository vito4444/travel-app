import Foundation
import SwiftData
import UserNotifications

/// 航班/火车出发前本地通知。
enum NotificationService {
    static let enabledKey = "departureReminderEnabled"
    static let leadMinutesKey = "departureReminderLeadMinutes"
    private static let idPrefix = "departure-"

    static var isEnabled: Bool {
        if UserDefaults.standard.object(forKey: enabledKey) == nil { return true }
        return UserDefaults.standard.bool(forKey: enabledKey)
    }

    /// 默认提前 120 分钟。
    static var leadMinutes: Int {
        let value = UserDefaults.standard.integer(forKey: leadMinutesKey)
        return value == 0 ? 120 : value
    }

    static func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// 清空并重建全部出发提醒：所有行程中含开始时间的航班/火车条目，提前 leadMinutes 分钟触发。
    @MainActor
    static func rescheduleAll(context: ModelContext) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ourIDs = pending.map(\.identifier).filter { $0.hasPrefix(idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ourIDs)

        guard isEnabled else { return }

        // 先收集待注册的提醒，有内容才申请通知权限，避免无谓弹窗。
        var requests: [UNNotificationRequest] = []
        let trips = (try? context.fetch(FetchDescriptor<Trip>())) ?? []
        for trip in trips {
            for item in trip.items where item.type == .flight || item.type == .train {
                guard let start = item.startTime else { continue }
                let fireDate = start.addingTimeInterval(TimeInterval(-leadMinutes * 60))
                guard fireDate > Date() else { continue }

                let content = UNMutableNotificationContent()
                content.title = "出发提醒 · \(trip.name)"
                let place = item.type == .flight ? "机场" : "车站"
                let numberPart = item.transportNumber.isEmpty ? "" : "（\(item.transportNumber)）"
                content.body = "「\(item.title)」\(numberPart) \(start.hourMinute) 出发，记得提前抵达\(place)。"
                content.sound = .default

                let comps = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: fireDate
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                requests.append(UNNotificationRequest(
                    identifier: idPrefix + item.uid,
                    content: content,
                    trigger: trigger
                ))
            }
        }

        guard !requests.isEmpty else { return }
        await requestAuthorization()
        for request in requests {
            try? await center.add(request)
        }
    }
}
