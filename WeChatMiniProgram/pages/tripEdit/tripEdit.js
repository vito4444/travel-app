const store = require('../../utils/store.js');
const meta = require('../../utils/meta.js');
const dateUtil = require('../../utils/date.js');

Page({
  data: {
    tripId: '',
    name: '',
    destination: '',
    startDate: dateUtil.todayString(),
    endDate: dateUtil.addDays(dateUtil.todayString(), 2),
    colorHex: meta.TRIP_COLORS[0],
    colors: meta.TRIP_COLORS,
    budget: '',
    notes: '',
    destLat: null,
    destLon: null,
    dayCountText: ''
  },

  onLoad(options) {
    if (options.id) {
      const trip = store.getTrip(options.id);
      if (trip) {
        this.setData({
          tripId: trip.id,
          name: trip.name,
          destination: trip.destination,
          startDate: trip.startDate,
          endDate: trip.endDate,
          colorHex: trip.colorHex,
          budget: trip.budget > 0 ? String(trip.budget) : '',
          notes: trip.notes,
          destLat: trip.destLat,
          destLon: trip.destLon
        });
        wx.setNavigationBarTitle({ title: '行程设置' });
      }
    }
    this.updateDayCount();
  },

  updateDayCount() {
    const days = Math.max(1, dateUtil.daysBetween(this.data.startDate, this.data.endDate) + 1);
    this.setData({ dayCountText: '共 ' + days + ' 天，每天自动生成日程分组' });
  },

  onInput(e) {
    this.setData({ [e.currentTarget.dataset.field]: e.detail.value });
  },

  onStartDate(e) {
    const startDate = e.detail.value;
    let endDate = this.data.endDate;
    if (endDate < startDate) endDate = startDate;
    this.setData({ startDate, endDate });
    this.updateDayCount();
  },

  onEndDate(e) {
    this.setData({ endDate: e.detail.value });
    this.updateDayCount();
  },

  onPickColor(e) {
    this.setData({ colorHex: e.currentTarget.dataset.color });
  },

  /** 用内置地图选目的地中心点（用于天气与地图初始视野）。 */
  onChooseDestination() {
    wx.chooseLocation({
      success: (res) => {
        const update = { destLat: res.latitude, destLon: res.longitude };
        if (!this.data.destination && res.name) update.destination = res.name;
        this.setData(update);
        wx.showToast({ title: '已设置目的地坐标', icon: 'success' });
      },
      fail: () => {}
    });
  },

  onSave() {
    const name = this.data.name.trim();
    if (!name) {
      wx.showToast({ title: '请填写行程名称', icon: 'none' });
      return;
    }
    const fields = {
      name,
      destination: this.data.destination.trim(),
      startDate: this.data.startDate,
      endDate: this.data.endDate,
      colorHex: this.data.colorHex,
      budget: Number(this.data.budget) || 0,
      notes: this.data.notes,
      destLat: this.data.destLat,
      destLon: this.data.destLon
    };
    if (this.data.tripId) {
      store.updateTrip(this.data.tripId, fields);
    } else {
      store.createTrip(fields);
    }
    wx.navigateBack();
  }
});
