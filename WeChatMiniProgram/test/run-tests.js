// 小程序逻辑层行为验证：node WeChatMiniProgram/test/run-tests.js
// mock 掉 wx 存储接口后直接跑 utils 层，与 iOS 版 LinuxVerification 对等。

const memoryStorage = {};
global.wx = {
  getStorageSync: (key) => (key in memoryStorage ? memoryStorage[key] : ''),
  setStorageSync: (key, value) => { memoryStorage[key] = value; }
};

const parser = require('../utils/parser.js');
const optimizer = require('../utils/optimizer.js');
const dateUtil = require('../utils/date.js');
const store = require('../utils/store.js');
const exporter = require('../utils/exporter.js');

let failures = 0;
function check(cond, name) {
  if (cond) {
    console.log('PASS ' + name);
  } else {
    failures += 1;
    console.log('FAIL ' + name);
  }
}

// ---------- parser：12306 火车票短信 ----------
const train = parser.parse(parser.SAMPLES.train);
check(!!train, 'train: 可解析');
check(train && train.type === 'train', 'train: 类型=火车');
check(train && train.transportNumber === 'G1371', 'train: 车次 G1371');
check(train && train.departurePlace === '北京南站', 'train: 出发站');
check(train && train.month === 5 && train.day === 1, 'train: 日期 5月1日');
check(train && train.hour === 9 && train.minute === 5, 'train: 时间 09:05');
check(train && train.orderNumber === 'EB12345678', 'train: 订单号');
check(train && train.platform === 'rail12306', 'train: 平台 12306');
check(train && train.extraNote.indexOf('2车12A号') >= 0, 'train: 座位备注');

// ---------- parser：航班确认 ----------
const flight = parser.parse(parser.SAMPLES.flight);
check(flight && flight.type === 'flight', 'flight: 类型=航班');
check(flight && flight.transportNumber === 'CA4102', 'flight: 航班号');
check(flight && flight.departurePlace === '北京首都T2', 'flight: 出发');
check(flight && flight.arrivalPlace === '成都天府T1', 'flight: 到达');
check(flight && flight.hour === 8 && flight.minute === 30, 'flight: 时间 08:30');
check(flight && flight.orderNumber === '8890123456', 'flight: 订单号');
check(flight && flight.platform === 'ctrip', 'flight: 平台 携程');

// ---------- parser：酒店确认 ----------
const hotel = parser.parse(parser.SAMPLES.hotel);
check(hotel && hotel.type === 'hotel', 'hotel: 类型=酒店');
check(hotel && hotel.title === '成都望江宾馆', 'hotel: 酒店名');
check(hotel && hotel.month === 5 && hotel.day === 2, 'hotel: 入住 5月2日');
check(hotel && hotel.checkOutMonth === 5 && hotel.checkOutDay === 4, 'hotel: 退房 5月4日');
check(hotel && hotel.orderNumber === '1234567890', 'hotel: 订单号');
check(hotel && hotel.phoneNumber === '028-85221234', 'hotel: 电话');
check(hotel && hotel.platform === 'qunar', 'hotel: 平台 去哪儿');

check(parser.parse('今晚吃什么好呢，明天记得带伞。') === null, 'negative: 无关文本返回 null');

// ---------- optimizer ----------
const scrambled = [
  { lat: 30.0, lon: 104.0 },
  { lat: 30.0, lon: 104.2 },
  { lat: 30.0, lon: 104.1 },
  { lat: 30.0, lon: 104.3 }
];
const order = optimizer.optimizeOrder(scrambled);
check(order[0] === 0 && order[order.length - 1] === 3, 'route: 固定首尾');
check(JSON.stringify(order) === '[0,2,1,3]', 'route: 共线乱序点重排为顺路');
const before = optimizer.totalDistance(scrambled);
const after = optimizer.totalDistance(order.map((i) => scrambled[i]));
check(after <= before, 'route: 优化后总长不大于优化前');
check(after < before, 'route: 本例严格变短');

const messy = [
  { lat: 31.23, lon: 121.47 }, { lat: 31.30, lon: 121.50 }, { lat: 31.24, lon: 121.48 },
  { lat: 31.29, lon: 121.49 }, { lat: 31.25, lon: 121.48 }, { lat: 31.31, lon: 121.51 }
];
const order6 = optimizer.optimizeOrder(messy);
check(order6.length === 6 && new Set(order6).size === 6, 'route: 6点输出为合法排列');
check(
  optimizer.totalDistance(order6.map((i) => messy[i])) <= optimizer.totalDistance(messy),
  'route: 6点不劣化'
);
const bjsh = optimizer.haversine({ lat: 39.9042, lon: 116.4074 }, { lat: 31.2304, lon: 121.4737 });
check(Math.abs(bjsh - 1067000) < 55000, 'haversine: 京沪距离约 1067km');

// ---------- date ----------
check(dateUtil.daysBetween('2026-05-01', '2026-05-03') === 2, 'date: daysBetween');
check(dateUtil.addDays('2026-05-01', 2) === '2026-05-03', 'date: addDays');
check(dateUtil.monthDayZH('2026-05-01') === '5月1日', 'date: monthDayZH');
check(dateUtil.timeToMinutes('09:05') === 545, 'date: timeToMinutes');
check(dateUtil.minutesToTime(545) === '09:05', 'date: minutesToTime');
check(dateUtil.durationZH(80) === '1小时20分', 'date: durationZH');
check(dateUtil.moneyZH(863) === '¥863', 'date: moneyZH');

// ---------- store：建行程 / 加条目 / 排序 ----------
const trip = store.createTrip({
  name: '五一成都行',
  destination: '成都',
  startDate: '2026-05-01',
  endDate: '2026-05-03',
  budget: 3000
});
check(store.dayCount(trip) === 3, 'store: 5.1-5.3 共 3 天');
check(store.statusText(trip) === '已结束' || store.statusText(trip).indexOf('距出发') >= 0 || store.statusText(trip).indexOf('旅行中') >= 0, 'store: 状态文案有值');

const itemA = store.newItem(1);
itemA.title = 'A 景点';
itemA.type = 'attraction';
itemA.startTime = '09:00';
itemA.endTime = '11:00';
itemA.lat = 30.7327; itemA.lon = 104.1440;
store.addItem(trip.id, itemA);

const itemB = store.newItem(1);
itemB.title = 'B 餐厅';
itemB.type = 'food';
itemB.lat = 30.6636; itemB.lon = 104.0555;
store.addItem(trip.id, itemB);

const itemC = store.newItem(1);
itemC.title = 'C 自由活动';
itemC.type = 'other';
itemC.startTime = '19:00';
store.addItem(trip.id, itemC);

check(store.itemsForDay(store.getTrip(trip.id), 1).length === 3, 'store: 加 3 条目');
check(itemB.sortIndex === 1 && itemC.sortIndex === 2, 'store: sortIndex 递增');

store.moveItem(trip.id, 1, 2, 0);
let names = store.itemsForDay(store.getTrip(trip.id), 1).map((i) => i.title[0]).join('');
check(names === 'CAB', 'store: moveItem C 移到最前');
store.moveItem(trip.id, 1, 0, 2);
names = store.itemsForDay(store.getTrip(trip.id), 1).map((i) => i.title[0]).join('');
check(names === 'ABC', 'store: moveItem 还原 ABC');

// ---------- store.applyRoute：顺序与时间回写 ----------
// B 提到 A 前，B 无时间（食物默认 60 分），leg 10 分钟。
store.applyRoute(trip.id, 1, [itemB.id, itemA.id], [10]);
const day1 = store.itemsForDay(store.getTrip(trip.id), 1);
check(day1[0].title === 'B 餐厅' && day1[1].title === 'A 景点' && day1[2].title === 'C 自由活动', 'applyRoute: 顺序 B,A + 未参与的 C 殿后');
check(day1[0].startTime === '09:00' && day1[0].endTime === '10:00', 'applyRoute: B 锚定 09:00 默认 60 分');
check(day1[1].startTime === '10:10' && day1[1].endTime === '12:10', 'applyRoute: A 10:10 开始保留 120 分时长');
check(day1[2].startTime === '19:00', 'applyRoute: 未参与条目时间不动');

// ---------- store：账目 / 清单 ----------
store.addExpense(trip.id, { amount: 680, category: 'transport', note: '高铁票', date: '2026-05-01' });
store.addExpense(trip.id, { amount: 128, category: 'food', note: '火锅', date: '2026-05-02' });
check(store.totalExpense(store.getTrip(trip.id)) === 808, 'store: 花费合计 808');

store.importChecklistTemplate(trip.id, ['证件', '药品']);
const checklist1 = store.getTrip(trip.id).checklist.length;
store.importChecklistTemplate(trip.id, ['证件']);
check(store.getTrip(trip.id).checklist.length === checklist1, 'store: 模板重复导入去重');

// ---------- exporter ----------
const text = exporter.tripText(store.getTrip(trip.id));
check(text.indexOf('【五一成都行】') === 0, 'exporter: 标题行');
check(text.indexOf('第2天') >= 0, 'exporter: 天分组');
check(text.indexOf('B 餐厅') >= 0 && text.indexOf('[餐饮]') >= 0, 'exporter: 条目行');
check(text.indexOf('已记录花费：¥808') >= 0, 'exporter: 花费合计');

console.log(failures === 0 ? 'ALL PASSED' : failures + ' FAILURES');
process.exit(failures === 0 ? 0 : 1);
