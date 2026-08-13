import Foundation

/// 订票/预订平台注册表。
///
/// URL Scheme 与 App Store ID 来源（2026-08 网络检索确认）：
/// - 携程 ctrip://（App Store id379395415）
/// - 去哪儿 qunarphone://（id395096736）
/// - 飞猪 taobaotravel://（id453691481）
/// - 铁路12306 cn.12306://
/// - 美团 imeituan://（id423084029）
/// - 大众点评 dianping://
/// - 艺龙 eltclient://
/// - 滴滴出行 diditaxi://
/// - 航旅纵横 umetrip://（id480161784）
/// 以上 scheme 均已加入 Info.plist 的 LSApplicationQueriesSchemes 白名单。
enum BookingPlatform: String, CaseIterable, Identifiable, Codable {
    case ctrip
    case qunar
    case fliggy
    case rail12306
    case meituan
    case dianping
    case elong
    case didi
    case umetrip
    case custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ctrip: return "携程"
        case .qunar: return "去哪儿"
        case .fliggy: return "飞猪"
        case .rail12306: return "铁路12306"
        case .meituan: return "美团"
        case .dianping: return "大众点评"
        case .elong: return "艺龙"
        case .didi: return "滴滴出行"
        case .umetrip: return "航旅纵横"
        case .custom: return "自定义"
        }
    }

    /// 唤起 App 的 URL Scheme；自定义平台无 scheme。
    var schemeURL: URL? {
        let scheme: String?
        switch self {
        case .ctrip: scheme = "ctrip://"
        case .qunar: scheme = "qunarphone://"
        case .fliggy: scheme = "taobaotravel://"
        case .rail12306: scheme = "cn.12306://"
        case .meituan: scheme = "imeituan://"
        case .dianping: scheme = "dianping://"
        case .elong: scheme = "eltclient://"
        case .didi: scheme = "diditaxi://"
        case .umetrip: scheme = "umetrip://"
        case .custom: scheme = nil
        }
        return scheme.flatMap { URL(string: $0) }
    }

    /// App 未安装时的网页回落地址。
    var webURL: URL? {
        let link: String?
        switch self {
        case .ctrip: link = "https://m.ctrip.com/"
        case .qunar: link = "https://touch.qunar.com/"
        case .fliggy: link = "https://m.fliggy.com/"
        case .rail12306: link = "https://www.12306.cn/"
        case .meituan: link = "https://www.meituan.com/"
        case .dianping: link = "https://m.dianping.com/"
        case .elong: link = "https://m.elong.com/"
        case .didi: link = "https://www.didiglobal.com/"
        case .umetrip: link = "https://www.umetrip.com/"
        case .custom: link = nil
        }
        return link.flatMap { URL(string: $0) }
    }

    /// 已确认的 App Store 条目（仅收录检索确认过的 ID）。
    var appStoreURL: URL? {
        let storeID: String?
        switch self {
        case .ctrip: storeID = "379395415"
        case .qunar: storeID = "395096736"
        case .fliggy: storeID = "453691481"
        case .meituan: storeID = "423084029"
        case .umetrip: storeID = "480161784"
        default: storeID = nil
        }
        return storeID.flatMap { URL(string: "itms-apps://apps.apple.com/cn/app/id\($0)") }
    }
}
