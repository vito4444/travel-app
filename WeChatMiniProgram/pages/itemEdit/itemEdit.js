const store = require('../../utils/store.js');
const meta = require('../../utils/meta.js');

const TYPE_PLACEHOLDERS = {
  flight: '标题（如：北京 → 成都）',
  train: '标题（如：G89 北京西 → 成都东）',
  hotel: '酒店名称',
  attraction: '景点名称',
  food: '餐厅/美食名称',
  transport: '交通安排（如：机场大巴）',
  other: '标题'
};

Page({
  data: {
    tripId: '',
    itemId: '',
    typeOrder: meta.TYPE_ORDER,
    typeLabels: meta.TYPE_ORDER.map((t) => meta.ITEM_TYPES[t].icon + ' ' + meta.ITEM_TYPES[t].label),
    typeIndex: 3,
    isPointToPoint: false,
    isHotel: false,
    titlePlaceholder: TYPE_PLACEHOLDERS.attraction,
    dayOptions: [],
    dayIndex: 0,
    platformOrder: [''].concat(meta.PLATFORM_ORDER),
    platformLabels: ['未关联'].concat(meta.PLATFORM_ORDER.map((p) => meta.PLATFORMS[p].label)),
    platformIndex: 0,
    item: null,
    // 表单字段
    title: '',
    startTime: '',
    endTime: '',
    locationName: '',
    address: '',
    lat: null,
    lon: null,
    price: '',
    transportNumber: '',
    departurePlace: '',
    arrivalPlace: '',
    checkInDate: '',
    checkOutDate: '',
    customPlatformName: '',
    orderNumber: '',
    phoneNumber: '',
    bookingShortLink: '',
    notes: '',
    photos: []
  },

  onLoad(options) {
    const trip = store.getTrip(options.tripId);
    if (!trip) {
      wx.navigateBack();
      return;
    }
    this.trip = trip;
    const count = store.dayCount(trip);
    const dayOptions = [];
    for (let i = 0; i < count; i++) {
      dayOptions.push('第' + (i + 1) + '天 · ' + store.dateForDay(trip, i));
    }
    this.setData({ tripId: trip.id, dayOptions });

    if (options.itemId) {
      const item = trip.items.find((it) => it.id === options.itemId);
      if (item) {
        wx.setNavigationBarTitle({ title: '编辑安排' });
        this.setData({
          itemId: item.id,
          typeIndex: Math.max(0, meta.TYPE_ORDER.indexOf(item.type)),
          dayIndex: item.dayIndex,
          title: item.title,
          startTime: item.startTime,
          endTime: item.endTime,
          locationName: item.locationName,
          address: item.address,
          lat: item.lat,
          lon: item.lon,
          price: item.price > 0 ? String(item.price) : '',
          transportNumber: item.transportNumber,
          departurePlace: item.departurePlace,
          arrivalPlace: item.arrivalPlace,
          checkInDate: item.checkInDate,
          checkOutDate: item.checkOutDate,
          platformIndex: item.platform ? meta.PLATFORM_ORDER.indexOf(item.platform) + 1 : 0,
          customPlatformName: item.customPlatformName,
          orderNumber: item.orderNumber,
          phoneNumber: item.phoneNumber,
          bookingShortLink: item.bookingShortLink,
          notes: item.notes,
          photos: item.photos || []
        });
      }
    } else if (options.day != null) {
      this.setData({ dayIndex: Math.min(Math.max(0, Number(options.day) || 0), count - 1) });
    }
    this.applyType();
  },

  applyType() {
    const type = this.data.typeOrder[this.data.typeIndex];
    this.setData({
      isPointToPoint: !!meta.ITEM_TYPES[type].pointToPoint,
      isHotel: type === 'hotel',
      titlePlaceholder: TYPE_PLACEHOLDERS[type] || '标题'
    });
  },

  onInput(e) {
    this.setData({ [e.currentTarget.dataset.field]: e.detail.value });
  },

  onPickerChange(e) {
    this.setData({ [e.currentTarget.dataset.field]: Number(e.detail.value) });
    if (e.currentTarget.dataset.field === 'typeIndex') this.applyType();
  },

  onTimeChange(e) {
    this.setData({ [e.currentTarget.dataset.field]: e.detail.value });
  },

  onDateChange(e) {
    this.setData({ [e.currentTarget.dataset.field]: e.detail.value });
  },

  onClearTime(e) {
    this.setData({ [e.currentTarget.dataset.field]: '' });
  },

  onChooseLocation() {
    wx.chooseLocation({
      success: (res) => {
        this.setData({
          locationName: res.name || this.data.locationName,
          address: res.address || '',
          lat: res.latitude,
          lon: res.longitude
        });
      },
      fail: (err) => {
        if (err && err.errMsg && err.errMsg.indexOf('auth') >= 0) {
          wx.showModal({
            title: '需要位置权限',
            content: '请在小程序设置中允许使用位置信息，用于地图选点。',
            showCancel: false
          });
        }
      }
    });
  },

  onClearLocation() {
    this.setData({ locationName: '', address: '', lat: null, lon: null });
  },

  // ---------- 照片附件 ----------

  onAddPhotos() {
    const remain = 5 - this.data.photos.length;
    if (remain <= 0) {
      wx.showToast({ title: '最多 5 张', icon: 'none' });
      return;
    }
    wx.chooseMedia({
      count: remain,
      mediaType: ['image'],
      sizeType: ['compressed'],
      success: (res) => {
        const fs = wx.getFileSystemManager();
        const photos = this.data.photos.slice();
        res.tempFiles.forEach((file) => {
          try {
            const saved = fs.saveFileSync(file.tempFilePath);
            photos.push(saved);
          } catch (e) {
            // 保存失败跳过该张
          }
        });
        this.setData({ photos });
      }
    });
  },

  onPreviewPhoto(e) {
    wx.previewImage({
      current: e.currentTarget.dataset.src,
      urls: this.data.photos
    });
  },

  onDeletePhoto(e) {
    const src = e.currentTarget.dataset.src;
    const photos = this.data.photos.filter((p) => p !== src);
    try {
      wx.getFileSystemManager().removeSavedFile({ filePath: src });
    } catch (err) {
      // 已不存在则忽略
    }
    this.setData({ photos });
  },

  // ---------- 保存/删除 ----------

  onSave() {
    const title = this.data.title.trim();
    if (!title) {
      wx.showToast({ title: '请填写标题', icon: 'none' });
      return;
    }
    const existing = this.data.itemId
      ? this.trip.items.find((it) => it.id === this.data.itemId)
      : null;
    const item = existing || store.newItem(this.data.dayIndex);

    item.title = title;
    item.type = this.data.typeOrder[this.data.typeIndex];
    item.dayIndex = this.data.dayIndex;
    item.startTime = this.data.startTime;
    item.endTime = this.data.endTime;
    item.locationName = this.data.locationName;
    item.address = this.data.address;
    item.lat = this.data.lat;
    item.lon = this.data.lon;
    item.price = Number(this.data.price) || 0;
    item.transportNumber = this.data.transportNumber.trim();
    item.departurePlace = this.data.departurePlace;
    item.arrivalPlace = this.data.arrivalPlace;
    item.checkInDate = this.data.checkInDate;
    item.checkOutDate = this.data.checkOutDate;
    item.platform = this.data.platformIndex === 0 ? '' : meta.PLATFORM_ORDER[this.data.platformIndex - 1];
    item.customPlatformName = this.data.customPlatformName;
    item.orderNumber = this.data.orderNumber.trim();
    item.phoneNumber = this.data.phoneNumber.trim();
    item.bookingShortLink = this.data.bookingShortLink.trim();
    item.notes = this.data.notes;
    item.photos = this.data.photos;

    if (existing) {
      store.updateItem(this.data.tripId, item);
    } else {
      store.addItem(this.data.tripId, item);
    }
    wx.navigateBack();
  },

  onDelete() {
    wx.showModal({
      title: '删除此条目？',
      confirmText: '删除',
      confirmColor: '#e8574c',
      success: (res) => {
        if (res.confirm) {
          store.deleteItem(this.data.tripId, this.data.itemId);
          wx.navigateBack();
        }
      }
    });
  }
});
