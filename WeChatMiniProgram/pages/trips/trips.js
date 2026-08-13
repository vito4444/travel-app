const store = require('../../utils/store.js');
const dateUtil = require('../../utils/date.js');

Page({
  data: {
    trips: []
  },

  onShow() {
    this.refresh();
  },

  refresh() {
    const trips = store.getTrips().map((trip) => ({
      id: trip.id,
      name: trip.name,
      destination: trip.destination || '未设置目的地',
      colorHex: trip.colorHex,
      statusText: store.statusText(trip),
      dateRange: dateUtil.monthDayZH(trip.startDate) + ' - ' + dateUtil.monthDayZH(trip.endDate),
      dayCount: store.dayCount(trip),
      itemCount: trip.items.length
    }));
    this.setData({ trips });
  },

  onCreate() {
    wx.navigateTo({ url: '/pages/tripEdit/tripEdit' });
  },

  onOpenTrip(e) {
    wx.navigateTo({ url: '/pages/detail/detail?id=' + e.currentTarget.dataset.id });
  },

  onLongPressTrip(e) {
    const id = e.currentTarget.dataset.id;
    const trip = store.getTrip(id);
    if (!trip) return;
    wx.showActionSheet({
      itemList: ['编辑行程', '删除行程'],
      success: (res) => {
        if (res.tapIndex === 0) {
          wx.navigateTo({ url: '/pages/tripEdit/tripEdit?id=' + id });
        } else if (res.tapIndex === 1) {
          wx.showModal({
            title: '删除「' + trip.name + '」？',
            content: '行程下的所有条目、清单与账目将一并删除，且不可恢复。',
            confirmText: '删除',
            confirmColor: '#e8574c',
            success: (modal) => {
              if (modal.confirm) {
                store.deleteTrip(id);
                this.refresh();
              }
            }
          });
        }
      }
    });
  }
});
