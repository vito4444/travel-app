// 日期工具：行程日期统一用 'YYYY-MM-DD' 字符串，时间用 'HH:mm' 字符串。

const WEEKDAYS = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];

function pad(n) {
  return n < 10 ? '0' + n : '' + n;
}

function toDateString(date) {
  return date.getFullYear() + '-' + pad(date.getMonth() + 1) + '-' + pad(date.getDate());
}

function parseDate(str) {
  if (!str) return null;
  const parts = str.split('-').map(Number);
  if (parts.length !== 3 || parts.some(isNaN)) return null;
  return new Date(parts[0], parts[1] - 1, parts[2]);
}

function todayString() {
  return toDateString(new Date());
}

/** a 到 b 的整天数（b - a）。 */
function daysBetween(aStr, bStr) {
  const a = parseDate(aStr);
  const b = parseDate(bStr);
  if (!a || !b) return 0;
  return Math.round((b.getTime() - a.getTime()) / 86400000);
}

function addDays(str, days) {
  const d = parseDate(str);
  if (!d) return str;
  d.setDate(d.getDate() + days);
  return toDateString(d);
}

/** '2026-08-14' → '8月14日' */
function monthDayZH(str) {
  const d = parseDate(str);
  if (!d) return '';
  return (d.getMonth() + 1) + '月' + d.getDate() + '日';
}

/** '2026-08-14' → '2026年8月14日' */
function yearMonthDayZH(str) {
  const d = parseDate(str);
  if (!d) return '';
  return d.getFullYear() + '年' + (d.getMonth() + 1) + '月' + d.getDate() + '日';
}

function weekdayZH(str) {
  const d = parseDate(str);
  if (!d) return '';
  return WEEKDAYS[d.getDay()];
}

/** 'HH:mm' → 分钟数；无效返回 null。 */
function timeToMinutes(t) {
  if (!t) return null;
  const m = /^(\d{1,2}):(\d{2})$/.exec(t);
  if (!m) return null;
  return Number(m[1]) * 60 + Number(m[2]);
}

/** 分钟数 → 'HH:mm'（0-1439 循环内取值）。 */
function minutesToTime(mins) {
  const clamped = ((Math.round(mins) % 1440) + 1440) % 1440;
  return pad(Math.floor(clamped / 60)) + ':' + pad(clamped % 60);
}

/** 分钟时长 → '1小时20分' / '35分' */
function durationZH(mins) {
  const m = Math.round(mins);
  const h = Math.floor(m / 60);
  const rest = m % 60;
  if (h > 0 && rest > 0) return h + '小时' + rest + '分';
  if (h > 0) return h + '小时';
  return rest + '分';
}

function moneyZH(amount) {
  const n = Number(amount) || 0;
  if (Math.abs(n - Math.round(n)) < 1e-9) return '¥' + Math.round(n);
  return '¥' + n.toFixed(2);
}

module.exports = {
  toDateString,
  parseDate,
  todayString,
  daysBetween,
  addDays,
  monthDayZH,
  yearMonthDayZH,
  weekdayZH,
  timeToMinutes,
  minutesToTime,
  durationZH,
  moneyZH
};
