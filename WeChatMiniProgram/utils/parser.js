// 订票短信/确认文本离线解析（与 iOS 版 BookingTextParser 同规则移植）。

const SAMPLES = {
  train: '【铁路12306】订单EB12345678，王小明您已购5月1日G1371次列车2车12A号，北京南站09:05开。请提前换取纸质车票或直接刷证进站。',
  flight: '【携程旅行】您已预订5月2日CA4102航班，北京首都T2 08:30起飞，11:05到达成都天府T1，乘机人王小明，订单号8890123456，如需改签退票请打开携程App操作。',
  hotel: '【去哪儿旅行】您已成功预订成都望江宾馆高级大床房1间2晚，5月2日入住，5月4日离店，订单号1234567890，酒店电话028-85221234，退订改期请在App内处理。'
};

function first(pattern, text) {
  const m = pattern.exec(text);
  return m || null;
}

function isTrain(text) {
  if (text.indexOf('12306') >= 0) return true;
  if (text.indexOf('次列车') >= 0) return true;
  return /[GDCKTZY]\d{1,4}次/.test(text) && text.indexOf('站') >= 0;
}

function isFlight(text) {
  if (text.indexOf('航班') < 0 && text.indexOf('起飞') < 0 && text.indexOf('登机') < 0) return false;
  return /[A-Z]{2}\d{3,4}/.test(text);
}

function isHotel(text) {
  const keywords = ['酒店', '宾馆', '饭店', '民宿', '客栈', '度假村', '公寓', '旅馆'];
  if (!keywords.some((k) => text.indexOf(k) >= 0)) return false;
  return text.indexOf('入住') >= 0 || text.indexOf('预订') >= 0 || text.indexOf('预定') >= 0;
}

function detectPlatform(text) {
  if (text.indexOf('12306') >= 0) return 'rail12306';
  if (text.indexOf('携程') >= 0) return 'ctrip';
  if (text.indexOf('去哪儿') >= 0) return 'qunar';
  if (text.indexOf('飞猪') >= 0) return 'fliggy';
  if (text.indexOf('美团') >= 0) return 'meituan';
  if (text.indexOf('大众点评') >= 0) return 'dianping';
  if (text.indexOf('艺龙') >= 0) return 'elong';
  if (text.indexOf('航旅纵横') >= 0) return 'umetrip';
  return '';
}

function applyCommon(result, text) {
  const order = first(/(?:订单号|订单编号|订单)[^A-Za-z0-9]{0,3}([A-Za-z0-9]{6,20})/, text);
  if (order) result.orderNumber = order[1];
  const phone = first(/(400[0-9\-]{6,10}|0\d{2,3}-?\d{7,8}|1[3-9]\d{9})/, text);
  if (phone) result.phoneNumber = phone[1];
  result.platform = detectPlatform(text);
}

function applyDate(result, text) {
  if (result.month != null) return;
  const m = first(/(\d{1,2})月(\d{1,2})(?:日|号)/, text);
  if (m) {
    result.month = Number(m[1]);
    result.day = Number(m[2]);
  }
}

function parseTrain(text) {
  const result = emptyResult('train');
  const number = first(/([GDCKTZY]?\d{1,4})次/, text);
  if (number) result.transportNumber = number[1];
  applyDate(result, text);
  const dep = first(/([\u4e00-\u9fa5]+?站)\s*(\d{1,2}):(\d{2})开/, text);
  if (dep) {
    result.departurePlace = dep[1];
    result.hour = Number(dep[2]);
    result.minute = Number(dep[3]);
  } else {
    const t = first(/(\d{1,2}):(\d{2})开/, text);
    if (t) {
      result.hour = Number(t[1]);
      result.minute = Number(t[2]);
    }
  }
  const arr = first(/(?:到|至)([\u4e00-\u9fa5]+?站)/, text);
  if (arr) result.arrivalPlace = arr[1];
  const seat = first(/(\d{1,2}车\d{1,3}[A-Fa-f]?号?)/, text);
  if (seat) result.extraNote = '座位：' + seat[1];
  applyCommon(result, text);
  if (!result.platform) result.platform = 'rail12306';

  const parts = [];
  if (result.transportNumber) parts.push(result.transportNumber);
  const route = [result.departurePlace, result.arrivalPlace].filter(Boolean).join(' → ');
  if (route) parts.push(route);
  result.title = parts.length ? parts.join(' ') : '火车出行';
  return result;
}

function parseFlight(text) {
  const result = emptyResult('flight');
  const number = first(/([A-Z]{2}\d{3,4})/, text);
  if (number) result.transportNumber = number[1];
  applyDate(result, text);
  const dep = first(/([\u4e00-\u9fa5]+(?:T\d)?)\s*(\d{1,2}):(\d{2})起飞/, text);
  if (dep) {
    result.departurePlace = dep[1];
    result.hour = Number(dep[2]);
    result.minute = Number(dep[3]);
  } else {
    const t = first(/(\d{1,2}):(\d{2})起飞/, text);
    if (t) {
      result.hour = Number(t[1]);
      result.minute = Number(t[2]);
    }
  }
  const arr = first(/(?:到达|抵达)([\u4e00-\u9fa5]+(?:T\d)?)/, text);
  if (arr) result.arrivalPlace = arr[1];
  applyCommon(result, text);

  const parts = [];
  if (result.transportNumber) parts.push(result.transportNumber);
  const route = [result.departurePlace, result.arrivalPlace].filter(Boolean).join(' → ');
  if (route) parts.push(route);
  result.title = parts.length ? parts.join(' ') : '航班出行';
  return result;
}

function parseHotel(text) {
  const result = emptyResult('hotel');
  const name = first(/(?:预订|预定|入住)([\u4e00-\u9fa5A-Za-z0-9]+?(?:酒店|宾馆|饭店|民宿|客栈|度假村|公寓|旅馆))/, text) ||
    first(/([\u4e00-\u9fa5A-Za-z0-9]{2,18}(?:酒店|宾馆|饭店|民宿|客栈|度假村|旅馆))/, text);
  result.title = name ? name[1] : '酒店入住';
  const checkIn = first(/(\d{1,2})月(\d{1,2})(?:日|号)入住/, text);
  if (checkIn) {
    result.month = Number(checkIn[1]);
    result.day = Number(checkIn[2]);
  } else {
    applyDate(result, text);
  }
  const checkOut = first(/(\d{1,2})月(\d{1,2})(?:日|号)(?:离店|退房)/, text);
  if (checkOut) {
    result.checkOutMonth = Number(checkOut[1]);
    result.checkOutDay = Number(checkOut[2]);
  }
  applyCommon(result, text);
  return result;
}

function emptyResult(type) {
  return {
    type,
    title: '',
    transportNumber: '',
    departurePlace: '',
    arrivalPlace: '',
    month: null,
    day: null,
    hour: null,
    minute: null,
    checkOutMonth: null,
    checkOutDay: null,
    orderNumber: '',
    phoneNumber: '',
    platform: '',
    extraNote: ''
  };
}

/** 解析入口；识别不了返回 null。 */
function parse(rawText) {
  const text = String(rawText || '')
    .replace(/：/g, ':')
    .replace(/（/g, '(')
    .replace(/）/g, ')');
  if (!text.trim()) return null;
  if (isTrain(text)) return parseTrain(text);
  if (isFlight(text)) return parseFlight(text);
  if (isHotel(text)) return parseHotel(text);
  return null;
}

module.exports = { parse, SAMPLES };
