// 对外跳转：平台小程序、电话、剪贴板、地图导航。
const meta = require('./meta.js');

/**
 * 打开预订平台：
 * 1. 条目带用户粘贴的小程序链接（shortLink，目标小程序菜单「复制链接」获得）→ 直接跳，任意平台可用；
 * 2. 平台注册表里有确认过的 appId（目前携程）→ 按 appId 跳；
 * 3. 都没有 → 复制订单号并提示去对应平台粘贴查单。
 * 微信在跳转前会统一弹「即将打开另一个小程序」确认框，属平台行为。
 */
function openPlatform(item) {
  const platform = meta.PLATFORMS[item.platform];
  const label = item.platform === 'custom'
    ? (item.customPlatformName || '预订平台')
    : (platform ? platform.label : '预订平台');

  if (item.bookingShortLink) {
    wx.navigateToMiniProgram({
      shortLink: item.bookingShortLink,
      fail: () => fallbackCopy(item, label)
    });
    return;
  }
  if (platform && platform.appId) {
    wx.navigateToMiniProgram({
      appId: platform.appId,
      fail: () => fallbackCopy(item, label)
    });
    return;
  }
  fallbackCopy(item, label);
}

function fallbackCopy(item, label) {
  if (item.orderNumber) {
    wx.setClipboardData({
      data: item.orderNumber,
      success: () => {
        wx.showModal({
          title: '订单号已复制',
          content: '微信内暂无「' + label + '」的直跳配置。已复制订单号，去' + label + '小程序/App 粘贴即可查单。也可在条目编辑里粘贴对方小程序链接实现一键直跳。',
          showCancel: false
        });
      }
    });
  } else {
    wx.showModal({
      title: '暂无法直跳',
      content: '在条目编辑里粘贴「' + label + '」小程序的复制链接（对方小程序菜单 → 复制链接），即可一键直跳。',
      showCancel: false
    });
  }
}

function call(phoneNumber) {
  const cleaned = String(phoneNumber || '').replace(/[\s]/g, '');
  if (!cleaned) return;
  wx.makePhoneCall({ phoneNumber: cleaned, fail: () => {} });
}

function copy(text, tip) {
  wx.setClipboardData({
    data: String(text || ''),
    success: () => wx.showToast({ title: tip || '已复制', icon: 'success' })
  });
}

/** 打开微信内置地图查看位置（面板自带跳第三方导航入口）。 */
function openLocation(item) {
  if (item.lat == null || item.lon == null) return;
  wx.openLocation({
    latitude: item.lat,
    longitude: item.lon,
    name: item.locationName || item.title,
    address: item.address || ''
  });
}

module.exports = { openPlatform, call, copy, openLocation };
