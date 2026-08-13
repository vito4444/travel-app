import Foundation

/// 从订票短信/确认文本解析出的预订草稿。
struct ParsedBooking {
    var type: ItemType
    var title: String
    var transportNumber: String = ""
    var departurePlace: String = ""
    var arrivalPlace: String = ""
    /// 出发/入住的月、日（年份由调用方按行程推断）。
    var month: Int?
    var day: Int?
    var hour: Int?
    var minute: Int?
    /// 酒店退房的月、日。
    var checkOutMonth: Int?
    var checkOutDay: Int?
    var orderNumber: String = ""
    var phoneNumber: String = ""
    var platform: BookingPlatform?
    var extraNote: String = ""
}

/// 离线正则解析 12306 购票短信、航班确认、酒店确认文本。
enum BookingTextParser {
    static func parse(_ text: String) -> ParsedBooking? {
        let normalized = text
            .replacingOccurrences(of: "：", with: ":")
            .replacingOccurrences(of: "（", with: "(")
            .replacingOccurrences(of: "）", with: ")")

        if isTrain(normalized) {
            return parseTrain(normalized)
        }
        if isFlight(normalized) {
            return parseFlight(normalized)
        }
        if isHotel(normalized) {
            return parseHotel(normalized)
        }
        return nil
    }

    // MARK: - 类型判定

    private static func isTrain(_ text: String) -> Bool {
        if text.contains("12306") { return true }
        if text.contains("次列车") { return true }
        return firstMatch(#"[GDCKTZY]\d{1,4}次"#, in: text) != nil && text.contains("站")
    }

    private static func isFlight(_ text: String) -> Bool {
        guard text.contains("航班") || text.contains("起飞") || text.contains("登机") else { return false }
        return firstMatch(#"([A-Z]{2}\d{3,4})"#, in: text) != nil
    }

    private static func isHotel(_ text: String) -> Bool {
        let keywords = ["酒店", "宾馆", "饭店", "民宿", "客栈", "度假村", "公寓", "旅馆"]
        guard keywords.contains(where: { text.contains($0) }) else { return false }
        return text.contains("入住") || text.contains("预订") || text.contains("预定")
    }

    // MARK: - 各类型解析

    private static func parseTrain(_ text: String) -> ParsedBooking {
        var result = ParsedBooking(type: .train, title: "")
        if let groups = firstMatch(#"([GDCKTZY]?\d{1,4})次"#, in: text) {
            result.transportNumber = groups[1]
        }
        applyDate(&result, text: text)
        if let groups = firstMatch(#"([\u4e00-\u9fa5]+?站)\s*(\d{1,2}):(\d{2})开"#, in: text) {
            result.departurePlace = groups[1]
            result.hour = Int(groups[2])
            result.minute = Int(groups[3])
        } else if let groups = firstMatch(#"(\d{1,2}):(\d{2})开"#, in: text) {
            result.hour = Int(groups[1])
            result.minute = Int(groups[2])
        }
        if let groups = firstMatch(#"(?:到|至)([\u4e00-\u9fa5]+?站)"#, in: text) {
            result.arrivalPlace = groups[1]
        }
        if let groups = firstMatch(#"(\d{1,2}车\d{1,3}[A-Fa-f]?号?)"#, in: text) {
            result.extraNote = "座位：\(groups[1])"
        }
        applyCommon(&result, text: text)
        result.platform = result.platform ?? .rail12306

        var titleParts: [String] = []
        if !result.transportNumber.isEmpty { titleParts.append(result.transportNumber) }
        let route = [result.departurePlace, result.arrivalPlace]
            .filter { !$0.isEmpty }
            .joined(separator: " → ")
        if !route.isEmpty { titleParts.append(route) }
        result.title = titleParts.isEmpty ? "火车出行" : titleParts.joined(separator: " ")
        return result
    }

    private static func parseFlight(_ text: String) -> ParsedBooking {
        var result = ParsedBooking(type: .flight, title: "")
        if let groups = firstMatch(#"([A-Z]{2}\d{3,4})"#, in: text) {
            result.transportNumber = groups[1]
        }
        applyDate(&result, text: text)
        if let groups = firstMatch(#"([\u4e00-\u9fa5]+(?:T\d)?)\s*(\d{1,2}):(\d{2})起飞"#, in: text) {
            result.departurePlace = groups[1]
            result.hour = Int(groups[2])
            result.minute = Int(groups[3])
        } else if let groups = firstMatch(#"(\d{1,2}):(\d{2})起飞"#, in: text) {
            result.hour = Int(groups[1])
            result.minute = Int(groups[2])
        }
        if let groups = firstMatch(#"(?:到达|抵达)([\u4e00-\u9fa5]+(?:T\d)?)"#, in: text) {
            result.arrivalPlace = groups[1]
        }
        applyCommon(&result, text: text)

        var titleParts: [String] = []
        if !result.transportNumber.isEmpty { titleParts.append(result.transportNumber) }
        let route = [result.departurePlace, result.arrivalPlace]
            .filter { !$0.isEmpty }
            .joined(separator: " → ")
        if !route.isEmpty { titleParts.append(route) }
        result.title = titleParts.isEmpty ? "航班出行" : titleParts.joined(separator: " ")
        return result
    }

    private static func parseHotel(_ text: String) -> ParsedBooking {
        var result = ParsedBooking(type: .hotel, title: "")
        if let groups = firstMatch(#"(?:预订|预定|入住)([\u4e00-\u9fa5A-Za-z0-9]+?(?:酒店|宾馆|饭店|民宿|客栈|度假村|公寓|旅馆))"#, in: text) {
            result.title = groups[1]
        } else if let groups = firstMatch(#"([\u4e00-\u9fa5A-Za-z0-9]{2,18}(?:酒店|宾馆|饭店|民宿|客栈|度假村|旅馆))"#, in: text) {
            result.title = groups[1]
        } else {
            result.title = "酒店入住"
        }
        if let groups = firstMatch(#"(\d{1,2})月(\d{1,2})(?:日|号)入住"#, in: text) {
            result.month = Int(groups[1])
            result.day = Int(groups[2])
        } else {
            applyDate(&result, text: text)
        }
        if let groups = firstMatch(#"(\d{1,2})月(\d{1,2})(?:日|号)(?:离店|退房)"#, in: text) {
            result.checkOutMonth = Int(groups[1])
            result.checkOutDay = Int(groups[2])
        }
        applyCommon(&result, text: text)
        return result
    }

    // MARK: - 公共字段

    private static func applyDate(_ result: inout ParsedBooking, text: String) {
        guard result.month == nil else { return }
        if let groups = firstMatch(#"(\d{1,2})月(\d{1,2})(?:日|号)"#, in: text) {
            result.month = Int(groups[1])
            result.day = Int(groups[2])
        }
    }

    private static func applyCommon(_ result: inout ParsedBooking, text: String) {
        if let groups = firstMatch(#"(?:订单号|订单编号|订单)[^A-Za-z0-9]{0,3}([A-Za-z0-9]{6,20})"#, in: text) {
            result.orderNumber = groups[1]
        }
        if let groups = firstMatch(#"(400[0-9\-]{6,10}|0\d{2,3}-?\d{7,8}|1[3-9]\d{9})"#, in: text) {
            result.phoneNumber = groups[1]
        }
        result.platform = detectPlatform(text)
    }

    private static func detectPlatform(_ text: String) -> BookingPlatform? {
        if text.contains("12306") { return .rail12306 }
        if text.contains("携程") { return .ctrip }
        if text.contains("去哪儿") { return .qunar }
        if text.contains("飞猪") { return .fliggy }
        if text.contains("美团") { return .meituan }
        if text.contains("大众点评") { return .dianping }
        if text.contains("艺龙") { return .elong }
        if text.contains("航旅纵横") { return .umetrip }
        return nil
    }

    // MARK: - 正则工具

    /// 返回 [整体匹配, 捕获组1, 捕获组2, ...]；无匹配返回 nil。
    private static func firstMatch(_ pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else { return nil }
        var groups: [String] = []
        for index in 0..<match.numberOfRanges {
            if let groupRange = Range(match.range(at: index), in: text) {
                groups.append(String(text[groupRange]))
            } else {
                groups.append("")
            }
        }
        return groups
    }
}

/// 内置示例文本（虚构数据，仅用于演示解析）。
enum BookingSampleTexts {
    static let train = "【铁路12306】订单EB12345678，王小明您已购5月1日G1371次列车2车12A号，北京南站09:05开。请提前换取纸质车票或直接刷证进站。"
    static let flight = "【携程旅行】您已预订5月2日CA4102航班，北京首都T2 08:30起飞，11:05到达成都天府T1，乘机人王小明，订单号8890123456，如需改签退票请打开携程App操作。"
    static let hotel = "【去哪儿旅行】您已成功预订成都望江宾馆高级大床房1间2晚，5月2日入住，5月4日离店，订单号1234567890，酒店电话028-85221234，退订改期请在App内处理。"
}
