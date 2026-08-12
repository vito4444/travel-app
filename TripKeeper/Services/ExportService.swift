import Foundation

/// 纯文本行程单导出。
enum ExportService {
    static func text(for trip: Trip) -> String {
        var lines: [String] = []
        lines.append("【\(trip.name)】")
        var headline = "\(trip.startDate.monthDayZH) - \(trip.endDate.monthDayZH) · 共\(trip.dayCount)天"
        if !trip.destination.isEmpty {
            headline += " · \(trip.destination)"
        }
        lines.append(headline)
        if !trip.notes.isEmpty {
            lines.append("备注：\(trip.notes)")
        }
        lines.append("")

        for day in 0..<trip.dayCount {
            let date = trip.date(forDay: day)
            lines.append("— 第\(day + 1)天 \(date.monthDayZH) \(date.weekdayZH) —")
            let items = trip.items(forDay: day)
            if items.isEmpty {
                lines.append("（暂无安排）")
            }
            for item in items {
                var line = ""
                if let start = item.startTime {
                    line += start.hourMinute
                    if let end = item.endTime {
                        line += "-\(end.hourMinute)"
                    }
                    line += " "
                }
                line += "[\(item.type.label)] \(item.title)"
                if !item.subtitle.isEmpty {
                    line += "（\(item.subtitle)）"
                }
                lines.append(line)

                var bookingParts: [String] = []
                if let platformName = item.platformDisplayName {
                    bookingParts.append(platformName)
                }
                if !item.orderNumber.isEmpty {
                    bookingParts.append("订单 \(item.orderNumber)")
                }
                if !item.phoneNumber.isEmpty {
                    bookingParts.append("电话 \(item.phoneNumber)")
                }
                if !bookingParts.isEmpty {
                    lines.append("    预订：" + bookingParts.joined(separator: " · "))
                }
                if !item.notes.isEmpty {
                    lines.append("    备注：\(item.notes)")
                }
            }
            lines.append("")
        }

        if trip.totalExpense > 0 {
            lines.append("已记录花费：\(moneyTextZH(trip.totalExpense))")
        }
        lines.append("—— 由「行程管家 TripKeeper」导出")
        return lines.joined(separator: "\n")
    }
}
