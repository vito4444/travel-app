import SwiftUI

extension Color {
    /// 从 "RRGGBB" 十六进制字符串创建颜色，解析失败时返回蓝色。
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        guard cleaned.count == 6, Scanner(string: cleaned).scanHexInt64(&value) else {
            self = .blue
            return
        }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255.0,
            green: Double((value >> 8) & 0xFF) / 255.0,
            blue: Double(value & 0xFF) / 255.0
        )
    }

    /// 行程封面备选色。
    static let tripPresetHexes: [String] = [
        "1E7ADB", "E8574C", "2FA35C", "8656D6", "E88F2A", "1FA8A0", "D6508E", "5A6B7C"
    ]
}

extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }

    /// "5月1日"
    var monthDayZH: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日"
        return f.string(from: self)
    }

    /// "周三"
    var weekdayZH: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "EEE"
        return f.string(from: self)
    }

    /// "09:30"
    var hourMinute: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "HH:mm"
        return f.string(from: self)
    }

    /// "2026年5月1日"
    var yearMonthDayZH: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月d日"
        return f.string(from: self)
    }

    /// 与另一日期相差的整天数（按自然日）。
    func daysUntil(_ other: Date) -> Int {
        Calendar.current.dateComponents([.day], from: startOfDay, to: other.startOfDay).day ?? 0
    }
}

/// 将秒数格式化为 "1小时20分" / "35分"。
func durationTextZH(_ seconds: TimeInterval) -> String {
    let totalMinutes = Int((seconds / 60).rounded())
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60
    if hours > 0 && minutes > 0 { return "\(hours)小时\(minutes)分" }
    if hours > 0 { return "\(hours)小时" }
    return "\(minutes)分"
}

/// 金额显示，去掉多余小数位。
func moneyTextZH(_ amount: Double) -> String {
    if amount == amount.rounded() && abs(amount) < 1_000_000 {
        return String(format: "¥%.0f", amount)
    }
    return String(format: "¥%.2f", amount)
}
