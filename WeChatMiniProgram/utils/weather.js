// Open-Meteo 免费日预报（无需 key）。
// 注意：正式发布需在微信公众平台把 https://api.open-meteo.com 加入 request 合法域名；
// 开发者工具调试可勾选「不校验合法域名」。
const dateUtil = require('./date.js');

/** WMO weather code → emoji 图标。 */
function symbol(code) {
  if (code === 0) return '☀️';
  if (code === 1 || code === 2) return '⛅';
  if (code === 3) return '☁️';
  if (code === 45 || code === 48) return '🌫️';
  if (code >= 51 && code <= 57) return '🌦️';
  if (code >= 61 && code <= 67) return '🌧️';
  if ((code >= 71 && code <= 77) || code === 85 || code === 86) return '🌨️';
  if (code >= 80 && code <= 82) return '🌧️';
  if (code >= 95) return '⛈️';
  return '☁️';
}

/**
 * 拉取行程区间与「今天起 16 天窗口」交集的每日预报。
 * 成功回调 { 'YYYY-MM-DD': { icon, tempText } }；失败/无交集回调 {}。
 */
function forecast(lat, lon, startDate, endDate, callback) {
  const today = dateUtil.todayString();
  const horizon = dateUtil.addDays(today, 15);
  const start = startDate > today ? startDate : today;
  const end = endDate < horizon ? endDate : horizon;
  if (start > end || lat == null || lon == null) {
    callback({});
    return;
  }
  wx.request({
    url: 'https://api.open-meteo.com/v1/forecast',
    data: {
      latitude: Number(lat).toFixed(4),
      longitude: Number(lon).toFixed(4),
      daily: 'weather_code,temperature_2m_max,temperature_2m_min',
      timezone: 'auto',
      start_date: start,
      end_date: end
    },
    success: (res) => {
      const daily = res.data && res.data.daily;
      if (!daily || !Array.isArray(daily.time)) {
        callback({});
        return;
      }
      const map = {};
      daily.time.forEach((day, i) => {
        const code = daily.weather_code && daily.weather_code[i];
        const tMax = daily.temperature_2m_max && daily.temperature_2m_max[i];
        const tMin = daily.temperature_2m_min && daily.temperature_2m_min[i];
        if (code == null || tMax == null || tMin == null) return;
        map[day] = {
          icon: symbol(code),
          tempText: Math.round(tMin) + '°~' + Math.round(tMax) + '°'
        };
      });
      callback(map);
    },
    fail: () => callback({})
  });
}

module.exports = { forecast, symbol };
