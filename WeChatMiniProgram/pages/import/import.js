const store = require('../../utils/store.js');
const meta = require('../../utils/meta.js');
const parser = require('../../utils/parser.js');
const dateUtil = require('../../utils/date.js');

Page({
  data: {
    tripId: '',
    text: '',
    parsed: null,
    parsedRows: [],
    parseFailed: false,
    dayOptions: [],
    targetDay: 0
  },

  onLoad(options) {
    const trip = store.getTrip(options.tripId);
    if (!trip) {
      wx.navigateBack();
      return;
    }
    this.trip = trip;
    const dayOptions = [];
    for (let i = 0; i < store.dayCount(trip); i++) {
      dayOptions.push('第' + (i + 1) + '天 · ' + dateUtil.monthDayZH(store.dateForDay(trip, i)));
    }
    this.setData({ tripId: trip.id, dayOptions });
  },

  onInput(e) {
    this.setData({ text: e.detail.value, parsed: null, parsedRows: [], parseFailed: false });
  },

  onSample(e) {
    this.setData({
      text: parser.SAMPLES[e.currentTarget.dataset.kind],
      parsed: null,
      parsedRows: [],
      parseFailed: false
    });
  },

  onParse() {
    const result = parser.parse(this.data.text);
    if (!result) {
      this.setData({ parsed: null, parsedRows: [], parseFailed: true });
      return;
    }
    const rows = [];
    rows.push({ label: '类型', value: meta.ITEM_TYPES[result.type].label });
    rows.push({ label: '标题', value: result.title });
    if (result.transportNumber) {
      rows.push({ label: result.type === 'flight' ? '航班号' : '车次', value: result.transportNumber });
    }
    const route = [result.departurePlace, result.arrivalPlace].filter(Boolean).join(' → ');
    if (route) rows.push({ label: '路线', value: route });
    if (result.month != null) {
      let value = result.month + '月' + result.day + '日';
      if (result.hour != null) {
        value += ' ' + (result.hour < 10 ? '0' : '') + result.hour + ':' + (result.minute < 10 ? '0' : '') + result.minute;
      }
      rows.push({ label: result.type === 'hotel' ? '入住' : '出发', value });
    }
    if (result.checkOutMonth != null) {
      rows.push({ label: '退房', value: result.checkOutMonth + '月' + result.checkOutDay + '日' });
    }
    if (result.orderNumber) rows.push({ label: '订单号', value: result.orderNumber });
    if (result.phoneNumber) rows.push({ label: '电话', value: result.phoneNumber });
    if (result.platform) rows.push({ label: '平台', value: meta.PLATFORMS[result.platform].label });

    this.setData({
      parsed: result,
      parsedRows: rows,
      parseFailed: false,
      targetDay: this.suggestedDay(result)
    });
  },

  /** 解析出的月日 → 行程内第几天；不在范围内回第 1 天。 */
  suggestedDay(result) {
    if (result.month == null || result.day == null) return 0;
    const date = this.resolveDate(result.month, result.day);
    if (!date) return 0;
    const index = dateUtil.daysBetween(this.trip.startDate, date);
    if (index < 0 || index >= store.dayCount(this.trip)) return 0;
    return index;
  },

  /** 用行程年份补全月日；早于行程 180 天以上视为跨年推一年。 */
  resolveDate(month, day) {
    const year = Number(this.trip.startDate.split('-')[0]);
    const pad = (n) => (n < 10 ? '0' + n : '' + n);
    let candidate = year + '-' + pad(month) + '-' + pad(day);
    if (dateUtil.daysBetween(candidate, this.trip.startDate) > 180) {
      candidate = (year + 1) + '-' + pad(month) + '-' + pad(day);
    }
    return candidate;
  },

  onPickDay(e) {
    this.setData({ targetDay: Number(e.detail.value) });
  },

  onAdd() {
    const parsed = this.data.parsed;
    if (!parsed) return;
    const item = store.newItem(this.data.targetDay);
    item.title = parsed.title;
    item.type = parsed.type;
    item.transportNumber = parsed.transportNumber;
    item.departurePlace = parsed.departurePlace;
    item.arrivalPlace = parsed.arrivalPlace;
    item.orderNumber = parsed.orderNumber;
    item.phoneNumber = parsed.phoneNumber;
    item.platform = parsed.platform;
    item.notes = parsed.extraNote;
    if (parsed.hour != null) {
      item.startTime = dateUtil.minutesToTime(parsed.hour * 60 + parsed.minute);
    }
    if (parsed.type === 'hotel') {
      if (parsed.month != null) item.checkInDate = this.resolveDate(parsed.month, parsed.day);
      if (parsed.checkOutMonth != null) item.checkOutDate = this.resolveDate(parsed.checkOutMonth, parsed.checkOutDay);
    }
    store.addItem(this.data.tripId, item);
    wx.showToast({ title: '已添加到行程', icon: 'success' });
    setTimeout(() => wx.navigateBack(), 600);
  }
});
