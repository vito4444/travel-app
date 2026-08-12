import SwiftUI

/// 行程条目类型：航班/火车/酒店/景点/餐饮/交通/其他。
enum ItemType: String, CaseIterable, Identifiable, Codable {
    case flight
    case train
    case hotel
    case attraction
    case food
    case transport
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .flight: return "航班"
        case .train: return "火车"
        case .hotel: return "酒店"
        case .attraction: return "景点"
        case .food: return "餐饮"
        case .transport: return "交通"
        case .other: return "其他"
        }
    }

    var icon: String {
        switch self {
        case .flight: return "airplane"
        case .train: return "tram.fill"
        case .hotel: return "bed.double.fill"
        case .attraction: return "mappin.and.ellipse"
        case .food: return "fork.knife"
        case .transport: return "car.fill"
        case .other: return "square.grid.2x2.fill"
        }
    }

    var color: Color {
        switch self {
        case .flight: return .blue
        case .train: return .green
        case .hotel: return .indigo
        case .attraction: return .orange
        case .food: return .pink
        case .transport: return .teal
        case .other: return .gray
        }
    }

    /// 路线规划推算时间时使用的默认停留时长（分钟）。
    var defaultDurationMinutes: Int {
        switch self {
        case .flight: return 150
        case .train: return 180
        case .hotel: return 60
        case .attraction: return 90
        case .food: return 60
        case .transport: return 45
        case .other: return 60
        }
    }

    /// 是否属于点对点交通类条目（有出发/到达地与班次号）。
    var isPointToPoint: Bool {
        self == .flight || self == .train || self == .transport
    }
}
