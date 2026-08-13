import Foundation
import SwiftData

/// 演示数据注入：仅当以 `-demoData` 启动参数运行（CI 截图/演示）且库为空时生效。
/// 坐标为成都各地点的近似值，仅用于演示地图与路线功能。
enum DemoData {
    static func seedIfNeeded(context: ModelContext) {
        guard ProcessInfo.processInfo.arguments.contains("-demoData") else { return }
        let existing = (try? context.fetch(FetchDescriptor<Trip>())) ?? []
        guard existing.isEmpty else { return }

        // 演示模式下关闭出发提醒，避免系统权限弹窗遮挡截图。
        UserDefaults.standard.set(false, forKey: NotificationService.enabledKey)

        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: 2, to: Date().startOfDay) ?? Date()
        let end = calendar.date(byAdding: .day, value: 2, to: start) ?? start

        let trip = Trip(name: "五一成都行", destination: "成都", startDate: start, endDate: end, colorHex: "E8574C", budget: 3000)
        trip.destinationLatitude = 30.5728
        trip.destinationLongitude = 104.0668
        trip.notes = "三日游：熊猫、市井、火锅。"
        context.insert(trip)

        func time(_ day: Int, _ hour: Int, _ minute: Int) -> Date {
            let dayDate = trip.date(forDay: day)
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: dayDate) ?? dayDate
        }

        func add(
            _ title: String, _ type: ItemType, day: Int, sort: Int,
            start: Date? = nil, end: Date? = nil,
            location: String = "", lat: Double? = nil, lon: Double? = nil,
            number: String = "", from: String = "", to: String = "",
            platform: BookingPlatform? = nil, order: String = "", phone: String = "",
            price: Double = 0
        ) {
            let item = ItineraryItem(title: title, type: type, dayIndex: day, sortIndex: sort)
            item.trip = trip
            item.startTime = start
            item.endTime = end
            item.locationName = location
            item.latitude = lat
            item.longitude = lon
            item.transportNumber = number
            item.departurePlace = from
            item.arrivalPlace = to
            item.platformRaw = platform?.rawValue ?? ""
            item.orderNumber = order
            item.phoneNumber = phone
            item.price = price
            context.insert(item)
        }

        // 第 1 天：抵达
        add("G1371 北京南 → 成都东", .train, day: 0, sort: 0,
            start: time(0, 9, 5), end: time(0, 16, 50),
            number: "G1371", from: "北京南站", to: "成都东站",
            platform: .rail12306, order: "EB12345678", price: 680)
        add("成都望江宾馆", .hotel, day: 0, sort: 1,
            start: time(0, 17, 30), end: time(0, 18, 0),
            location: "成都望江宾馆", lat: 30.6417, lon: 104.0824,
            platform: .qunar, order: "1234567890", phone: "028-85221234", price: 428)

        // 第 2 天：市区一日（4 个含坐标条目，故意留成非最优顺序供「优化顺序」演示）
        add("大熊猫繁育研究基地", .attraction, day: 1, sort: 0,
            start: time(1, 9, 0), end: time(1, 12, 0),
            location: "成都大熊猫繁育研究基地", lat: 30.7327, lon: 104.1440,
            platform: .meituan, order: "MT2026050188", price: 55)
        add("春熙路", .attraction, day: 1, sort: 1,
            start: time(1, 13, 0), end: time(1, 14, 30),
            location: "春熙路商圈", lat: 30.6598, lon: 104.0810)
        add("宽窄巷子小吃", .food, day: 1, sort: 2,
            start: time(1, 15, 0), end: time(1, 16, 30),
            location: "宽窄巷子", lat: 30.6636, lon: 104.0555)
        add("人民公园鹤鸣茶社", .attraction, day: 1, sort: 3,
            start: time(1, 17, 0), end: time(1, 18, 30),
            location: "人民公园", lat: 30.6595, lon: 104.0561)

        // 第 3 天：返程
        add("武侯祠", .attraction, day: 2, sort: 0,
            start: time(2, 9, 30), end: time(2, 11, 30),
            location: "武侯祠博物馆", lat: 30.6459, lon: 104.0455,
            platform: .dianping, price: 50)
        add("CA4102 成都天府 → 北京首都", .flight, day: 2, sort: 1,
            start: time(2, 15, 20), end: time(2, 18, 5),
            number: "CA4102", from: "成都天府T1", to: "北京首都T2",
            platform: .ctrip, order: "8890123456")

        // 账目与清单
        let e1 = Expense(amount: 680, category: .transport, note: "高铁票", date: start)
        e1.trip = trip
        context.insert(e1)
        let e2 = Expense(amount: 55, category: .ticket, note: "熊猫基地门票", date: start)
        e2.trip = trip
        context.insert(e2)
        let e3 = Expense(amount: 128, category: .food, note: "火锅", date: start)
        e3.trip = trip
        context.insert(e3)

        for (index, title) in ["身份证", "充电宝", "防晒霜"].enumerated() {
            let checklistItem = ChecklistItem(title: title, category: index == 0 ? "证件" : (index == 1 ? "电子" : "洗漱"), sortIndex: index)
            checklistItem.isDone = index == 0
            checklistItem.trip = trip
            context.insert(checklistItem)
        }
    }
}
