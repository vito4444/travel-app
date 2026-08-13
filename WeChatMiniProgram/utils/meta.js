// 类型、平台、分类等常量表（与 iOS 版语义一致）。

const ITEM_TYPES = {
  flight: { label: '航班', icon: '✈️', color: '#1E7ADB', defaultDuration: 150, pointToPoint: true },
  train: { label: '火车', icon: '🚄', color: '#2FA35C', defaultDuration: 180, pointToPoint: true },
  hotel: { label: '酒店', icon: '🛏️', color: '#5A5FD6', defaultDuration: 60, pointToPoint: false },
  attraction: { label: '景点', icon: '📍', color: '#E88F2A', defaultDuration: 90, pointToPoint: false },
  food: { label: '餐饮', icon: '🍜', color: '#D6508E', defaultDuration: 60, pointToPoint: false },
  transport: { label: '交通', icon: '🚗', color: '#1FA8A0', defaultDuration: 45, pointToPoint: true },
  other: { label: '其他', icon: '📦', color: '#8E8E93', defaultDuration: 60, pointToPoint: false }
};

const TYPE_ORDER = ['flight', 'train', 'hotel', 'attraction', 'food', 'transport', 'other'];

// 订票平台注册表。
// appId 仅收录经网络检索确认的（携程 wx0e6ed4f51db9d078，2026-08 确认）；
// 其余平台通过条目里用户粘贴的小程序链接（shortLink）跳转，或复制订单号兜底。
const PLATFORMS = {
  ctrip: { label: '携程', appId: 'wx0e6ed4f51db9d078' },
  qunar: { label: '去哪儿', appId: '' },
  fliggy: { label: '飞猪', appId: '' },
  rail12306: { label: '铁路12306', appId: '' },
  meituan: { label: '美团', appId: '' },
  dianping: { label: '大众点评', appId: '' },
  elong: { label: '艺龙', appId: '' },
  didi: { label: '滴滴出行', appId: '' },
  umetrip: { label: '航旅纵横', appId: '' },
  custom: { label: '自定义', appId: '' }
};

const PLATFORM_ORDER = ['ctrip', 'qunar', 'fliggy', 'rail12306', 'meituan', 'dianping', 'elong', 'didi', 'umetrip', 'custom'];

const EXPENSE_CATEGORIES = {
  transport: { label: '交通', icon: '🚗', color: '#1FA8A0' },
  hotel: { label: '住宿', icon: '🛏️', color: '#5A5FD6' },
  food: { label: '餐饮', icon: '🍜', color: '#D6508E' },
  ticket: { label: '门票', icon: '🎫', color: '#E88F2A' },
  shopping: { label: '购物', icon: '🛍️', color: '#8656D6' },
  other: { label: '其他', icon: '📦', color: '#8E8E93' }
};

const EXPENSE_ORDER = ['transport', 'hotel', 'food', 'ticket', 'shopping', 'other'];

const TRIP_COLORS = ['#1E7ADB', '#E8574C', '#2FA35C', '#8656D6', '#E88F2A', '#1FA8A0', '#D6508E', '#5A6B7C'];

const CHECKLIST_TEMPLATE = [
  { category: '证件', titles: ['身份证', '护照/签证', '学生证/优惠证件', '行程单打印件', '现金与银行卡'] },
  { category: '电子', titles: ['手机充电器', '充电宝', '耳机', '相机与存储卡', '转换插头'] },
  { category: '衣物', titles: ['换洗衣物', '外套', '舒适步行鞋', '帽子/墨镜', '雨伞/雨衣'] },
  { category: '洗漱', titles: ['牙刷牙膏', '洗面奶', '防晒霜', '护肤品', '毛巾'] },
  { category: '药品', titles: ['感冒药', '肠胃药', '创可贴', '晕车药', '个人常用药'] }
];

const CHECKLIST_CATEGORIES = ['证件', '电子', '衣物', '洗漱', '药品', '其他'];

module.exports = {
  ITEM_TYPES,
  TYPE_ORDER,
  PLATFORMS,
  PLATFORM_ORDER,
  EXPENSE_CATEGORIES,
  EXPENSE_ORDER,
  TRIP_COLORS,
  CHECKLIST_TEMPLATE,
  CHECKLIST_CATEGORIES
};
