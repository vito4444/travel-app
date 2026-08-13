// 纯文本行程单导出（与 iOS 版 ExportService 同格式）。
const dateUtil = require('./date.js');
const meta = require('./meta.js');
const store = require('./store.js');

function platformLabel(item) {
  if (!item.platform) return '';
  if (item.platform === 'custom') return item.customPlatformName || '自定义平台';
  const p = meta.PLATFORMS[item.platform];
  return p ? p.label : '';
}

function itemSubtitle(item) {
  if (item.type === 'flight' || item.type === 'train' || item.type === 'transport') {
    const route = [item.departurePlace, item.arrivalPlace].filter(Boolean).join(' → ');
    const parts = [item.transportNumber, route].filter(Boolean);
    if (parts.length) return parts.join(' · ');
  }
  if (item.type === 'hotel' && item.checkInDate && item.checkOutDate) {
    return dateUtil.monthDayZH(item.checkInDate) + '入住 · ' + dateUtil.monthDayZH(item.checkOutDate) + '退房';
  }
  return item.locationName || item.address || '';
}

function tripText(trip) {
  const lines = [];
  lines.push('【' + trip.name + '】');
  let headline = dateUtil.monthDayZH(trip.startDate) + ' - ' + dateUtil.monthDayZH(trip.endDate) +
    ' · 共' + store.dayCount(trip) + '天';
  if (trip.destination) headline += ' · ' + trip.destination;
  lines.push(headline);
  if (trip.notes) lines.push('备注：' + trip.notes);
  lines.push('');

  const days = store.dayCount(trip);
  for (let day = 0; day < days; day++) {
    const date = store.dateForDay(trip, day);
    lines.push('— 第' + (day + 1) + '天 ' + dateUtil.monthDayZH(date) + ' ' + dateUtil.weekdayZH(date) + ' —');
    const items = store.itemsForDay(trip, day);
    if (!items.length) lines.push('（暂无安排）');
    items.forEach((item) => {
      let line = '';
      if (item.startTime) {
        line += item.startTime;
        if (item.endTime) line += '-' + item.endTime;
        line += ' ';
      }
      const typeMeta = meta.ITEM_TYPES[item.type] || meta.ITEM_TYPES.other;
      line += '[' + typeMeta.label + '] ' + item.title;
      const subtitle = itemSubtitle(item);
      if (subtitle) line += '（' + subtitle + '）';
      lines.push(line);

      const bookingParts = [];
      const label = platformLabel(item);
      if (label) bookingParts.push(label);
      if (item.orderNumber) bookingParts.push('订单 ' + item.orderNumber);
      if (item.phoneNumber) bookingParts.push('电话 ' + item.phoneNumber);
      if (bookingParts.length) lines.push('    预订：' + bookingParts.join(' · '));
      if (item.notes) lines.push('    备注：' + item.notes);
    });
    lines.push('');
  }

  const total = store.totalExpense(trip);
  if (total > 0) lines.push('已记录花费：' + dateUtil.moneyZH(total));
  lines.push('—— 由「行程管家」小程序导出');
  return lines.join('\n');
}

module.exports = { tripText, itemSubtitle, platformLabel };
