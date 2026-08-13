const meta = require('../../utils/meta.js');

Page({
  data: {
    platforms: meta.PLATFORM_ORDER
      .filter((p) => p !== 'custom')
      .map((p) => ({
        key: p,
        label: meta.PLATFORMS[p].label,
        jumpText: meta.PLATFORMS[p].appId ? '支持一键直跳' : '粘贴小程序链接可直跳'
      }))
  }
});
