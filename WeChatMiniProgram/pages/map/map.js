const store = require('../../utils/store.js');
const dateUtil = require('../../utils/date.js');
const meta = require('../../utils/meta.js');
const optimizer = require('../../utils/optimizer.js');

Page({
  data: {
    tripId: '',
    days: [],
    selectedDay: 0,
    mode: 'driving',
    markers: [],
    polyline: [],
    includePoints: [],
    legs: [],
    totalKm: '',
    isEmpty: true,
    colorHex: '#1E7ADB'
  },

  onLoad(options) {
    const trip = store.getTrip(options.tripId);
    if (!trip) {
      wx.navigateBack();
      return;
    }
    this.trip = trip;
    this.ordered = [];
    const count = store.dayCount(trip);
    const days = [];
    for (let i = 0; i < count; i++) {
      days.push({
        index: i,
        label: '第' + (i + 1) + '天',
        dateLabel: dateUtil.monthDayZH(store.dateForDay(trip, i))
      });
    }
    // 默认天：旅行中选当天，否则第 1 天。
    let selectedDay = 0;
    const today = dateUtil.todayString();
    if (today >= trip.startDate && today <= trip.endDate) {
      selectedDay = Math.min(dateUtil.daysBetween(trip.startDate, today), count - 1);
    }
    this.setData({ tripId: trip.id, days, selectedDay, colorHex: trip.colorHex });
    this.reload();
  },

  onPickDay(e) {
    this.setData({ selectedDay: Number(e.currentTarget.dataset.day) });
    this.reload();
  },

  onPickMode(e) {
    this.setData({ mode: e.currentTarget.dataset.mode });
    this.recalc();
  },

  reload() {
    const trip = store.getTrip(this.data.tripId);
    this.trip = trip;
    this.ordered = store.itemsForDay(trip, this.data.selectedDay)
      .filter((it) => it.lat != null && it.lon != null);
    this.recalc();
  },

  recalc() {
    const items = this.ordered;
    if (!items.length) {
      this.setData({ isEmpty: true, markers: [], polyline: [], includePoints: [], legs: [], totalKm: '' });
      return;
    }
    const markers = items.map((it, i) => ({
      id: i,
      latitude: it.lat,
      longitude: it.lon,
      width: 28,
      height: 28,
      label: {
        content: (i + 1) + ' ' + it.title,
        color: '#1c1c1e',
        bgColor: '#ffffff',
        padding: 4,
        borderRadius: 6,
        fontSize: 11,
        anchorY: 2
      }
    }));
    const points = items.map((it) => ({ latitude: it.lat, longitude: it.lon }));
    const coords = items.map((it) => ({ lat: it.lat, lon: it.lon }));

    const legs = [];
    for (let i = 0; i + 1 < items.length; i++) {
      const minutes = optimizer.estimateLegMinutes(coords[i], coords[i + 1], this.data.mode);
      legs.push({
        seq: (i + 1) + ' → ' + (i + 2),
        toTitle: items[i + 1].title,
        minutes,
        text: dateUtil.durationZH(minutes)
      });
    }

    this.setData({
      isEmpty: false,
      markers,
      includePoints: points,
      polyline: points.length > 1 ? [{
        points,
        color: this.data.colorHex + 'E6',
        width: 4,
        dottedLine: true
      }] : [],
      legs,
      totalKm: points.length > 1 ? (optimizer.totalDistance(coords) / 1000).toFixed(1) : ''
    });
  },

  onOptimize() {
    if (this.ordered.length < 3) {
      wx.showToast({ title: '至少 3 个定位点才能优化', icon: 'none' });
      return;
    }
    const coords = this.ordered.map((it) => ({ lat: it.lat, lon: it.lon }));
    const order = optimizer.optimizeOrder(coords);
    this.ordered = order.map((idx) => this.ordered[idx]);
    this.recalc();
    wx.showToast({ title: '已按顺路重排', icon: 'success' });
  },

  onApply() {
    if (!this.ordered.length) return;
    const legsMinutes = this.data.legs.map((leg) => leg.minutes);
    store.applyRoute(
      this.data.tripId,
      this.data.selectedDay,
      this.ordered.map((it) => it.id),
      legsMinutes
    );
    wx.showToast({ title: '已应用到行程', icon: 'success' });
    this.reload();
  }
});
