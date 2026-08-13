const store = require('../../utils/store.js');
const dateUtil = require('../../utils/date.js');
const meta = require('../../utils/meta.js');
const weather = require('../../utils/weather.js');
const deeplink = require('../../utils/deeplink.js');
const exporter = require('../../utils/exporter.js');

Page({
  data: {
    tripId: '',
    name: '',
    destination: '',
    statusText: '',
    dateText: '',
    budgetLine: '',
    notes: '',
    colorHex: '#1E7ADB',
    days: [],
    editMode: false
  },

  onLoad(options) {
    this.setData({ tripId: options.id || '' });
    this.weatherMap = null;
  },

  onShow() {
    this.refresh();
    this.loadWeatherOnce();
  },

  refresh() {
    const trip = store.getTrip(this.data.tripId);
    if (!trip) {
      wx.navigateBack();
      return;
    }
    const total = store.totalExpense(trip);
    let budgetLine = '';
    if (trip.budget > 0) {
      budgetLine = '已花 ' + dateUtil.moneyZH(total) + ' / 预算 ' + dateUtil.moneyZH(trip.budget);
    } else if (total > 0) {
      budgetLine = '已花 ' + dateUtil.moneyZH(total);
    }

    const days = [];
    const count = store.dayCount(trip);
    for (let day = 0; day < count; day++) {
      const date = store.dateForDay(trip, day);
      const items = store.itemsForDay(trip, day).map((item) => this.viewItem(item));
      days.push({
        index: day,
        date,
        title: '第' + (day + 1) + '天 · ' + dateUtil.monthDayZH(date) + ' ' + dateUtil.weekdayZH(date),
        weather: (this.weatherMap && this.weatherMap[date]) || null,
        items
      });
    }

    wx.setNavigationBarTitle({ title: trip.name });
    this.setData({
      name: trip.name,
      destination: trip.destination || '未设置目的地',
      statusText: store.statusText(trip),
      dateText: dateUtil.yearMonthDayZH(trip.startDate) + ' - ' + dateUtil.monthDayZH(trip.endDate) +
        ' · 共' + count + '天 · ' + trip.items.length + '个安排',
      budgetLine,
      notes: trip.notes,
      colorHex: trip.colorHex,
      days
    });
  },

  viewItem(item) {
    const typeMeta = meta.ITEM_TYPES[item.type] || meta.ITEM_TYPES.other;
    let platformLabel = '';
    if (item.platform) {
      platformLabel = item.platform === 'custom'
        ? (item.customPlatformName || '自定义平台')
        : meta.PLATFORMS[item.platform].label;
    }
    let bookingLine = '';
    if (platformLabel && item.orderNumber) {
      bookingLine = platformLabel + ' · 订单 ' + item.orderNumber;
    } else if (platformLabel) {
      bookingLine = '已在' + platformLabel + '预订';
    }
    return {
      id: item.id,
      title: item.title,
      startTime: item.startTime || '--:--',
      endTime: item.endTime,
      icon: typeMeta.icon,
      color: typeMeta.color,
      typeLabel: typeMeta.label,
      subtitle: exporter.itemSubtitle(item),
      bookingLine,
      platformLabel,
      canOpenPlatform: !!(item.bookingShortLink || (item.platform && item.platform !== 'custom') || (item.platform === 'custom' && item.bookingShortLink)),
      hasPhone: !!item.phoneNumber,
      hasOrder: !!item.orderNumber,
      hasLocation: item.lat != null && item.lon != null
    };
  },

  loadWeatherOnce() {
    if (this.weatherMap) {
      this.refresh();
      return;
    }
    const trip = store.getTrip(this.data.tripId);
    if (!trip) return;
    let lat = trip.destLat;
    let lon = trip.destLon;
    if (lat == null || lon == null) {
      const located = trip.items.find((it) => it.lat != null && it.lon != null);
      if (located) {
        lat = located.lat;
        lon = located.lon;
      }
    }
    if (lat == null || lon == null) return;
    weather.forecast(lat, lon, trip.startDate, trip.endDate, (map) => {
      this.weatherMap = map;
      this.refresh();
    });
  },

  // ---------- 条目操作 ----------

  findItem(e) {
    const itemId = e.currentTarget.dataset.item;
    const trip = store.getTrip(this.data.tripId);
    if (!trip) return null;
    return trip.items.find((it) => it.id === itemId) || null;
  },

  onAddItem(e) {
    wx.navigateTo({
      url: '/pages/itemEdit/itemEdit?tripId=' + this.data.tripId + '&day=' + e.currentTarget.dataset.day
    });
  },

  onTapItem(e) {
    wx.navigateTo({
      url: '/pages/itemEdit/itemEdit?tripId=' + this.data.tripId + '&itemId=' + e.currentTarget.dataset.item
    });
  },

  onLongPressItem(e) {
    const item = this.findItem(e);
    if (!item) return;
    const actions = [];
    if (item.lat != null) actions.push('查看位置 / 导航');
    actions.push('删除条目');
    wx.showActionSheet({
      itemList: actions,
      success: (res) => {
        const picked = actions[res.tapIndex];
        if (picked === '查看位置 / 导航') {
          deeplink.openLocation(item);
        } else if (picked === '删除条目') {
          store.deleteItem(this.data.tripId, item.id);
          this.refresh();
        }
      }
    });
  },

  onOpenPlatform(e) {
    const item = this.findItem(e);
    if (item) deeplink.openPlatform(item);
  },

  onCall(e) {
    const item = this.findItem(e);
    if (item) deeplink.call(item.phoneNumber);
  },

  onCopyOrder(e) {
    const item = this.findItem(e);
    if (item) deeplink.copy(item.orderNumber, '订单号已复制');
  },

  // ---------- 排序 ----------

  onToggleEdit() {
    this.setData({ editMode: !this.data.editMode });
  },

  onMove(e) {
    const { day, pos, dir } = e.currentTarget.dataset;
    store.moveItem(this.data.tripId, day, pos, pos + (dir === 'up' ? -1 : 1));
    this.refresh();
  },

  onDeleteItem(e) {
    store.deleteItem(this.data.tripId, e.currentTarget.dataset.item);
    this.refresh();
  },

  // ---------- 工具入口 ----------

  onOpenTool(e) {
    const tool = e.currentTarget.dataset.tool;
    const id = this.data.tripId;
    const urls = {
      map: '/pages/map/map?tripId=' + id,
      checklist: '/pages/checklist/checklist?tripId=' + id,
      budget: '/pages/budget/budget?tripId=' + id,
      import: '/pages/import/import?tripId=' + id,
      share: '/pages/share/share?tripId=' + id,
      settings: '/pages/tripEdit/tripEdit?id=' + id
    };
    if (urls[tool]) wx.navigateTo({ url: urls[tool] });
  },

  onShareAppMessage() {
    return {
      title: this.data.name + ' · ' + this.data.dateText,
      path: '/pages/trips/trips'
    };
  }
});
