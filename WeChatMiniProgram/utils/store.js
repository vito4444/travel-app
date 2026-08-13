// 数据层：全部行程数据存 wx 本地缓存（对应 iOS 版 SwiftData 本地存储）。
const dateUtil = require('./date.js');
const meta = require('./meta.js');

const STORAGE_KEY = 'tripkeeper_data_v1';
let cache = null;

function uid() {
  return Date.now().toString(36) + Math.random().toString(36).slice(2, 8);
}

function load() {
  if (cache) return cache;
  try {
    cache = wx.getStorageSync(STORAGE_KEY) || { trips: [] };
  } catch (e) {
    cache = { trips: [] };
  }
  if (!Array.isArray(cache.trips)) cache.trips = [];
  return cache;
}

function persist() {
  try {
    wx.setStorageSync(STORAGE_KEY, load());
  } catch (e) {
    // 存储失败（配额/系统异常）时静默，下次操作重试。
  }
}

// ---------- 行程 ----------

function getTrips() {
  return load().trips.slice().sort((a, b) => (a.startDate < b.startDate ? 1 : -1));
}

function getTrip(id) {
  return load().trips.find((t) => t.id === id) || null;
}

function createTrip(fields) {
  const trip = {
    id: uid(),
    name: fields.name || '未命名行程',
    destination: fields.destination || '',
    startDate: fields.startDate,
    endDate: fields.endDate,
    colorHex: fields.colorHex || meta.TRIP_COLORS[0],
    notes: fields.notes || '',
    budget: Number(fields.budget) || 0,
    destLat: fields.destLat != null ? fields.destLat : null,
    destLon: fields.destLon != null ? fields.destLon : null,
    createdAt: Date.now(),
    items: [],
    expenses: [],
    checklist: []
  };
  load().trips.push(trip);
  persist();
  return trip;
}

function updateTrip(id, fields) {
  const trip = getTrip(id);
  if (!trip) return null;
  Object.assign(trip, fields);
  persist();
  return trip;
}

function deleteTrip(id) {
  const data = load();
  data.trips = data.trips.filter((t) => t.id !== id);
  cache = data;
  persist();
}

function dayCount(trip) {
  return Math.max(1, dateUtil.daysBetween(trip.startDate, trip.endDate) + 1);
}

function dateForDay(trip, dayIndex) {
  return dateUtil.addDays(trip.startDate, dayIndex);
}

/** 行程状态文案：距出发 X 天 / 旅行中 · 第 X 天 / 已结束。 */
function statusText(trip) {
  const today = dateUtil.todayString();
  if (today < trip.startDate) {
    const days = dateUtil.daysBetween(today, trip.startDate);
    return days === 0 ? '今天出发' : '距出发 ' + days + ' 天';
  }
  if (today > trip.endDate) return '已结束';
  return '旅行中 · 第 ' + (dateUtil.daysBetween(trip.startDate, today) + 1) + ' 天';
}

// ---------- 条目 ----------

function itemsForDay(trip, dayIndex) {
  return trip.items
    .filter((it) => it.dayIndex === dayIndex)
    .sort((a, b) => (a.sortIndex - b.sortIndex) || (a.createdAt - b.createdAt));
}

function newItem(dayIndex) {
  return {
    id: uid(),
    title: '',
    type: 'attraction',
    dayIndex,
    sortIndex: 0,
    startTime: '',
    endTime: '',
    locationName: '',
    address: '',
    lat: null,
    lon: null,
    notes: '',
    price: 0,
    transportNumber: '',
    departurePlace: '',
    arrivalPlace: '',
    checkInDate: '',
    checkOutDate: '',
    platform: '',
    customPlatformName: '',
    orderNumber: '',
    phoneNumber: '',
    bookingShortLink: '',
    photos: [],
    createdAt: Date.now()
  };
}

function addItem(tripId, item) {
  const trip = getTrip(tripId);
  if (!trip) return null;
  const siblings = itemsForDay(trip, item.dayIndex);
  item.sortIndex = siblings.length ? siblings[siblings.length - 1].sortIndex + 1 : 0;
  trip.items.push(item);
  persist();
  return item;
}

function updateItem(tripId, updated) {
  const trip = getTrip(tripId);
  if (!trip) return;
  const index = trip.items.findIndex((it) => it.id === updated.id);
  if (index >= 0) {
    trip.items[index] = updated;
    persist();
  }
}

function deleteItem(tripId, itemId) {
  const trip = getTrip(tripId);
  if (!trip) return;
  trip.items = trip.items.filter((it) => it.id !== itemId);
  persist();
}

/** 同一天内把 fromPos 的条目移到 toPos（位置为该天序内索引）。 */
function moveItem(tripId, dayIndex, fromPos, toPos) {
  const trip = getTrip(tripId);
  if (!trip) return;
  const dayItems = itemsForDay(trip, dayIndex);
  if (fromPos < 0 || fromPos >= dayItems.length || toPos < 0 || toPos >= dayItems.length) return;
  const [moved] = dayItems.splice(fromPos, 1);
  dayItems.splice(toPos, 0, moved);
  dayItems.forEach((it, i) => { it.sortIndex = i; });
  persist();
}

/**
 * 路线规划回写（对应 iOS 版 RoutePlanner.apply）：
 * orderedIds 为参与规划条目的新顺序，legsMinutes[i] 为第 i 段交通分钟数；
 * 未参与（无坐标）的条目按原相对顺序排在其后；
 * 时间锚点取第一个条目原开始时间（缺省 09:00），停留时长取原时长或类型默认。
 */
function applyRoute(tripId, dayIndex, orderedIds, legsMinutes) {
  const trip = getTrip(tripId);
  if (!trip) return;
  const dayItems = itemsForDay(trip, dayIndex);
  const byId = {};
  dayItems.forEach((it) => { byId[it.id] = it; });
  const ordered = orderedIds.map((id) => byId[id]).filter(Boolean);
  const orderedSet = new Set(orderedIds);
  const rest = dayItems.filter((it) => !orderedSet.has(it.id));

  ordered.forEach((it, i) => { it.sortIndex = i; });
  rest.forEach((it, i) => { it.sortIndex = ordered.length + i; });

  if (ordered.length) {
    const first = ordered[0];
    let cursor = dateUtil.timeToMinutes(first.startTime);
    if (cursor == null) cursor = 9 * 60;
    ordered.forEach((it, i) => {
      const startMin = dateUtil.timeToMinutes(it.startTime);
      const endMin = dateUtil.timeToMinutes(it.endTime);
      let duration = (startMin != null && endMin != null && endMin > startMin)
        ? endMin - startMin
        : (meta.ITEM_TYPES[it.type] || meta.ITEM_TYPES.other).defaultDuration;
      it.startTime = dateUtil.minutesToTime(cursor);
      it.endTime = dateUtil.minutesToTime(cursor + duration);
      cursor += duration;
      if (i < legsMinutes.length) {
        cursor += Math.ceil(legsMinutes[i] / 5) * 5;
      }
    });
  }
  persist();
}

// ---------- 账目 ----------

function addExpense(tripId, expense) {
  const trip = getTrip(tripId);
  if (!trip) return;
  trip.expenses.push({
    id: uid(),
    amount: Number(expense.amount) || 0,
    category: expense.category || 'other',
    note: expense.note || '',
    date: expense.date || dateUtil.todayString()
  });
  persist();
}

function deleteExpense(tripId, expenseId) {
  const trip = getTrip(tripId);
  if (!trip) return;
  trip.expenses = trip.expenses.filter((e) => e.id !== expenseId);
  persist();
}

function totalExpense(trip) {
  return trip.expenses.reduce((sum, e) => sum + (Number(e.amount) || 0), 0);
}

// ---------- 清单 ----------

function addChecklistItem(tripId, title, category) {
  const trip = getTrip(tripId);
  if (!trip) return;
  trip.checklist.push({ id: uid(), title, category: category || '其他', done: false });
  persist();
}

function toggleChecklistItem(tripId, itemId) {
  const trip = getTrip(tripId);
  if (!trip) return;
  const item = trip.checklist.find((c) => c.id === itemId);
  if (item) {
    item.done = !item.done;
    persist();
  }
}

function deleteChecklistItem(tripId, itemId) {
  const trip = getTrip(tripId);
  if (!trip) return;
  trip.checklist = trip.checklist.filter((c) => c.id !== itemId);
  persist();
}

/** 导入模板分类（按标题去重）。 */
function importChecklistTemplate(tripId, categories) {
  const trip = getTrip(tripId);
  if (!trip) return;
  const existing = new Set(trip.checklist.map((c) => c.title));
  meta.CHECKLIST_TEMPLATE.forEach((group) => {
    if (!categories.includes(group.category)) return;
    group.titles.forEach((title) => {
      if (!existing.has(title)) {
        trip.checklist.push({ id: uid(), title, category: group.category, done: false });
      }
    });
  });
  persist();
}

module.exports = {
  uid,
  getTrips,
  getTrip,
  createTrip,
  updateTrip,
  deleteTrip,
  dayCount,
  dateForDay,
  statusText,
  itemsForDay,
  newItem,
  addItem,
  updateItem,
  deleteItem,
  moveItem,
  applyRoute,
  addExpense,
  deleteExpense,
  totalExpense,
  addChecklistItem,
  toggleChecklistItem,
  deleteChecklistItem,
  importChecklistTemplate
};
