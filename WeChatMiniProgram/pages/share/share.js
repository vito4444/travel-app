const store = require('../../utils/store.js');
const meta = require('../../utils/meta.js');
const dateUtil = require('../../utils/date.js');
const exporter = require('../../utils/exporter.js');

const CANVAS_W = 750;

Page({
  data: {
    tripId: '',
    tripName: '',
    canvasHeightPx: 600,
    canvasStyleHeight: 600,
    ready: false
  },

  onLoad(options) {
    this.setData({ tripId: options.tripId || '' });
  },

  onReady() {
    this.trip = store.getTrip(this.data.tripId);
    if (!this.trip) {
      wx.navigateBack();
      return;
    }
    this.setData({ tripName: this.trip.name });
    this.draw();
  },

  /** 生成绘制行。 */
  buildLines(trip) {
    const lines = [];
    const days = store.dayCount(trip);
    for (let day = 0; day < days; day++) {
      const date = store.dateForDay(trip, day);
      lines.push({
        kind: 'day',
        text: '第' + (day + 1) + '天 · ' + dateUtil.monthDayZH(date) + ' ' + dateUtil.weekdayZH(date)
      });
      const items = store.itemsForDay(trip, day);
      if (!items.length) {
        lines.push({ kind: 'sub', text: '暂无安排' });
      }
      items.forEach((item) => {
        const typeMeta = meta.ITEM_TYPES[item.type] || meta.ITEM_TYPES.other;
        const time = item.startTime ? item.startTime + '  ' : '';
        lines.push({
          kind: 'item',
          color: typeMeta.color,
          text: time + typeMeta.icon + ' ' + item.title
        });
        const subtitle = exporter.itemSubtitle(item);
        if (subtitle) lines.push({ kind: 'sub', text: subtitle });
      });
    }
    return lines;
  },

  draw() {
    const trip = this.trip;
    const lines = this.buildLines(trip);
    const headerH = 190;
    const footerH = 90;
    const lineHeights = { day: 66, item: 52, sub: 40 };
    let height = headerH + 30 + footerH;
    lines.forEach((line) => { height += lineHeights[line.kind]; });

    // 屏幕预览高度按宽度等比：样式宽 686rpx。
    this.setData({
      canvasHeightPx: height,
      canvasStyleHeight: Math.round(height * (686 / CANVAS_W)),
      ready: false
    });

    wx.createSelectorQuery()
      .select('#poster')
      .fields({ node: true, size: true })
      .exec((res) => {
        if (!res || !res[0] || !res[0].node) return;
        const canvas = res[0].node;
        const ctx = canvas.getContext('2d');
        const scale = 2;
        canvas.width = CANVAS_W * scale;
        canvas.height = height * scale;
        ctx.scale(scale, scale);

        // 背景
        ctx.fillStyle = '#ffffff';
        ctx.fillRect(0, 0, CANVAS_W, height);

        // 头部渐变
        const grad = ctx.createLinearGradient(0, 0, CANVAS_W, headerH);
        grad.addColorStop(0, trip.colorHex);
        grad.addColorStop(1, trip.colorHex + 'B8');
        ctx.fillStyle = grad;
        ctx.fillRect(0, 0, CANVAS_W, headerH);

        ctx.fillStyle = '#ffffff';
        ctx.font = 'bold 44px sans-serif';
        ctx.fillText(trip.name, 40, 86);
        ctx.font = '26px sans-serif';
        let headline = dateUtil.monthDayZH(trip.startDate) + ' - ' + dateUtil.monthDayZH(trip.endDate) +
          ' · 共' + store.dayCount(trip) + '天';
        if (trip.destination) headline = '📍 ' + trip.destination + ' · ' + headline;
        ctx.fillText(headline, 40, 140);

        // 正文
        let y = headerH + 40;
        lines.forEach((line) => {
          if (line.kind === 'day') {
            y += 24;
            ctx.fillStyle = trip.colorHex;
            ctx.font = 'bold 30px sans-serif';
            ctx.fillText(line.text, 40, y);
            y += lineHeights.day - 24;
          } else if (line.kind === 'item') {
            ctx.fillStyle = '#1c1c1e';
            ctx.font = '28px sans-serif';
            ctx.fillText(this.clip(line.text, 30), 56, y);
            y += lineHeights.item;
          } else {
            ctx.fillStyle = '#8e8e93';
            ctx.font = '22px sans-serif';
            ctx.fillText(this.clip(line.text, 38), 130, y - 14);
            y += lineHeights.sub;
          }
        });

        // 页脚
        ctx.fillStyle = '#c7c7cc';
        ctx.font = '22px sans-serif';
        ctx.textAlign = 'center';
        ctx.fillText('—— 行程管家 · 微信小程序版 ——', CANVAS_W / 2, height - 36);
        ctx.textAlign = 'left';

        this.canvasNode = canvas;
        this.setData({ ready: true });
      });
  },

  clip(text, maxChars) {
    return text.length > maxChars ? text.slice(0, maxChars) + '…' : text;
  },

  onCopyText() {
    wx.setClipboardData({
      data: exporter.tripText(this.trip),
      success: () => wx.showToast({ title: '行程单已复制', icon: 'success' })
    });
  },

  onSaveImage() {
    if (!this.canvasNode) return;
    wx.canvasToTempFilePath({
      canvas: this.canvasNode,
      success: (res) => {
        wx.saveImageToPhotosAlbum({
          filePath: res.tempFilePath,
          success: () => wx.showToast({ title: '已保存到相册', icon: 'success' }),
          fail: (err) => {
            if (err.errMsg && err.errMsg.indexOf('auth') >= 0) {
              wx.showModal({
                title: '需要相册权限',
                content: '请在设置中允许保存到相册后重试。',
                confirmText: '去设置',
                success: (modal) => {
                  if (modal.confirm) wx.openSetting();
                }
              });
            }
          }
        });
      },
      fail: () => wx.showToast({ title: '生成失败，重试一次', icon: 'none' })
    });
  },

  onShareAppMessage() {
    return {
      title: this.data.tripName + ' 的行程安排',
      path: '/pages/trips/trips'
    };
  }
});
