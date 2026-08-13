import Foundation
import SwiftData

@Model
final class Trip {
    var name: String = ""
    var destination: String = ""
    var startDate: Date = Date()
    var endDate: Date = Date()
    var colorHex: String = "1E7ADB"
    var notes: String = ""
    /// 预算目标，0 表示未设置。
    var budget: Double = 0
    var destinationLatitude: Double?
    var destinationLongitude: Double?
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \ItineraryItem.trip)
    var items: [ItineraryItem] = []

    @Relationship(deleteRule: .cascade, inverse: \Expense.trip)
    var expenses: [Expense] = []

    @Relationship(deleteRule: .cascade, inverse: \ChecklistItem.trip)
    var checklist: [ChecklistItem] = []

    init(name: String, destination: String, startDate: Date, endDate: Date, colorHex: String = "1E7ADB", budget: Double = 0) {
        self.name = name
        self.destination = destination
        self.startDate = startDate
        self.endDate = endDate
        self.colorHex = colorHex
        self.budget = budget
        self.createdAt = Date()
    }

    /// 行程总天数（含首尾两天）。
    var dayCount: Int {
        max(1, startDate.daysUntil(endDate) + 1)
    }

    /// 第 index 天（0 起）的日期。
    func date(forDay index: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: index, to: startDate.startOfDay) ?? startDate.startOfDay
    }

    /// 第 index 天的条目，按 sortIndex 排序。
    func items(forDay index: Int) -> [ItineraryItem] {
        items
            .filter { $0.dayIndex == index }
            .sorted { ($0.sortIndex, $0.createdAt) < ($1.sortIndex, $1.createdAt) }
    }

    var totalExpense: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }

    enum Status {
        case upcoming(daysLeft: Int)
        case ongoing(dayNumber: Int)
        case finished
    }

    var status: Status {
        let today = Date().startOfDay
        if today < startDate.startOfDay {
            return .upcoming(daysLeft: today.daysUntil(startDate))
        }
        if today > endDate.startOfDay {
            return .finished
        }
        return .ongoing(dayNumber: startDate.daysUntil(today) + 1)
    }

    var statusText: String {
        switch status {
        case .upcoming(let daysLeft): return daysLeft == 0 ? "今天出发" : "距出发 \(daysLeft) 天"
        case .ongoing(let dayNumber): return "旅行中 · 第 \(dayNumber) 天"
        case .finished: return "已结束"
        }
    }
}
