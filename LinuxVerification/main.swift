// 行为验证：订票文本解析器 + 路线顺序优化算法。
// 运行方式见 run.sh；全部通过输出 ALL PASSED 并以 0 退出。
import Foundation

var failures = 0

func check(_ condition: Bool, _ name: String) {
    if condition {
        print("PASS \(name)")
    } else {
        failures += 1
        print("FAIL \(name)")
    }
}

// MARK: - BookingTextParser：12306 火车票短信

let train = BookingTextParser.parse(BookingSampleTexts.train)
check(train != nil, "train: 可解析")
check(train?.type == .train, "train: 类型=火车")
check(train?.transportNumber == "G1371", "train: 车次 G1371")
check(train?.departurePlace == "北京南站", "train: 出发站 北京南站")
check(train?.month == 5 && train?.day == 1, "train: 日期 5月1日")
check(train?.hour == 9 && train?.minute == 5, "train: 时间 09:05")
check(train?.orderNumber == "EB12345678", "train: 订单号 EB12345678")
check(train?.platform == .rail12306, "train: 平台 12306")
check(train?.extraNote.contains("2车12A号") == true, "train: 座位备注")

// MARK: - BookingTextParser：航班确认短信

let flight = BookingTextParser.parse(BookingSampleTexts.flight)
check(flight?.type == .flight, "flight: 类型=航班")
check(flight?.transportNumber == "CA4102", "flight: 航班号 CA4102")
check(flight?.departurePlace == "北京首都T2", "flight: 出发 北京首都T2")
check(flight?.arrivalPlace == "成都天府T1", "flight: 到达 成都天府T1")
check(flight?.month == 5 && flight?.day == 2, "flight: 日期 5月2日")
check(flight?.hour == 8 && flight?.minute == 30, "flight: 时间 08:30")
check(flight?.orderNumber == "8890123456", "flight: 订单号")
check(flight?.platform == .ctrip, "flight: 平台 携程")

// MARK: - BookingTextParser：酒店确认短信

let hotel = BookingTextParser.parse(BookingSampleTexts.hotel)
check(hotel?.type == .hotel, "hotel: 类型=酒店")
check(hotel?.title == "成都望江宾馆", "hotel: 酒店名")
check(hotel?.month == 5 && hotel?.day == 2, "hotel: 入住 5月2日")
check(hotel?.checkOutMonth == 5 && hotel?.checkOutDay == 4, "hotel: 退房 5月4日")
check(hotel?.orderNumber == "1234567890", "hotel: 订单号")
check(hotel?.phoneNumber == "028-85221234", "hotel: 电话")
check(hotel?.platform == .qunar, "hotel: 平台 去哪儿")

// MARK: - BookingTextParser：无关文本不误判

check(BookingTextParser.parse("今晚吃什么好呢，明天记得带伞。") == nil, "negative: 无关文本返回 nil")

// MARK: - RouteOptimizer：顺序优化

func coord(_ lat: Double, _ lon: Double) -> CLLocationCoordinate2D {
    CLLocationCoordinate2D(latitude: lat, longitude: lon)
}

// 4 个共线点乱序：0(104.0) → 1(104.2) → 2(104.1) → 3(104.3)，最优应为 [0, 2, 1, 3]。
let scrambled = [coord(30.0, 104.0), coord(30.0, 104.2), coord(30.0, 104.1), coord(30.0, 104.3)]
let order = RouteOptimizer.optimizeOrder(coordinates: scrambled)
check(order.first == 0 && order.last == 3, "route: 固定首尾")
check(order == [0, 2, 1, 3], "route: 共线乱序点重排为顺路")

let before = RouteOptimizer.totalDistance(coordinates: scrambled)
let after = RouteOptimizer.totalDistance(coordinates: order.map { scrambled[$0] })
check(after <= before, "route: 优化后总长不大于优化前")
check(after < before, "route: 本例严格变短（0.3° vs 0.5° 跨度）")

// 6 个乱序点：结果必须是合法排列且不劣化。
let messy = [
    coord(31.23, 121.47), coord(31.30, 121.50), coord(31.24, 121.48),
    coord(31.29, 121.49), coord(31.25, 121.48), coord(31.31, 121.51)
]
let order6 = RouteOptimizer.optimizeOrder(coordinates: messy)
check(Set(order6) == Set(0..<6) && order6.count == 6, "route: 6点输出为合法排列")
let after6 = RouteOptimizer.totalDistance(coordinates: order6.map { messy[$0] })
check(after6 <= RouteOptimizer.totalDistance(coordinates: messy), "route: 6点不劣化")

// 球面距离量级：北京—上海大圆距离约 1067 公里。
let bjsh = RouteOptimizer.haversine(coord(39.9042, 116.4074), coord(31.2304, 121.4737))
check(abs(bjsh - 1_067_000) < 55_000, "haversine: 京沪距离约 1067km")

print(failures == 0 ? "ALL PASSED" : "\(failures) FAILURES")
exit(failures == 0 ? 0 : 1)
