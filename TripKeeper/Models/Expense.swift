import SwiftUI
import SwiftData

enum ExpenseCategory: String, CaseIterable, Identifiable, Codable {
    case transport
    case hotel
    case food
    case ticket
    case shopping
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .transport: return "交通"
        case .hotel: return "住宿"
        case .food: return "餐饮"
        case .ticket: return "门票"
        case .shopping: return "购物"
        case .other: return "其他"
        }
    }

    var icon: String {
        switch self {
        case .transport: return "car.fill"
        case .hotel: return "bed.double.fill"
        case .food: return "fork.knife"
        case .ticket: return "ticket.fill"
        case .shopping: return "bag.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .transport: return .teal
        case .hotel: return .indigo
        case .food: return .pink
        case .ticket: return .orange
        case .shopping: return .purple
        case .other: return .gray
        }
    }
}

@Model
final class Expense {
    var amount: Double = 0
    var categoryRaw: String = ExpenseCategory.other.rawValue
    var note: String = ""
    var date: Date = Date()
    var trip: Trip?

    init(amount: Double, category: ExpenseCategory, note: String = "", date: Date = Date()) {
        self.amount = amount
        self.categoryRaw = category.rawValue
        self.note = note
        self.date = date
    }

    var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
}
