const store = require('../../utils/store.js');
const meta = require('../../utils/meta.js');
const dateUtil = require('../../utils/date.js');

Page({
  data: {
    tripId: '',
    totalText: '¥0',
    budgetLine: '',
    overBudget: false,
    percent: 0,
    categorySummary: [],
    expenses: [],
    // 添加表单
    amount: '',
    categoryOrder: meta.EXPENSE_ORDER,
    categoryLabels: meta.EXPENSE_ORDER.map((c) => meta.EXPENSE_CATEGORIES[c].icon + ' ' + meta.EXPENSE_CATEGORIES[c].label),
    categoryIndex: 2,
    note: '',
    date: dateUtil.todayString()
  },

  onLoad(options) {
    this.setData({ tripId: options.tripId || '' });
  },

  onShow() {
    this.refresh();
  },

  refresh() {
    const trip = store.getTrip(this.data.tripId);
    if (!trip) {
      wx.navigateBack();
      return;
    }
    const total = store.totalExpense(trip);
    let budgetLine = '';
    let overBudget = false;
    let percent = 0;
    if (trip.budget > 0) {
      overBudget = total > trip.budget;
      percent = Math.min(100, Math.round(total / trip.budget * 100));
      budgetLine = overBudget
        ? '已超预算 ' + dateUtil.moneyZH(total - trip.budget)
        : '预算 ' + dateUtil.moneyZH(trip.budget) + '，还剩 ' + dateUtil.moneyZH(trip.budget - total);
    } else {
      budgetLine = '未设置预算，可在「行程设置」里填写';
    }

    const sums = {};
    trip.expenses.forEach((e) => {
      sums[e.category] = (sums[e.category] || 0) + (Number(e.amount) || 0);
    });
    const categorySummary = meta.EXPENSE_ORDER
      .filter((c) => sums[c])
      .map((c) => ({
        key: c,
        icon: meta.EXPENSE_CATEGORIES[c].icon,
        label: meta.EXPENSE_CATEGORIES[c].label,
        color: meta.EXPENSE_CATEGORIES[c].color,
        amountText: dateUtil.moneyZH(sums[c])
      }));

    const expenses = trip.expenses
      .slice()
      .sort((a, b) => (a.date < b.date ? 1 : -1))
      .map((e) => ({
        id: e.id,
        icon: (meta.EXPENSE_CATEGORIES[e.category] || meta.EXPENSE_CATEGORIES.other).icon,
        title: e.note || (meta.EXPENSE_CATEGORIES[e.category] || meta.EXPENSE_CATEGORIES.other).label,
        dateText: dateUtil.monthDayZH(e.date),
        amountText: dateUtil.moneyZH(e.amount)
      }));

    this.setData({
      totalText: dateUtil.moneyZH(total),
      budgetLine,
      overBudget,
      percent,
      categorySummary,
      expenses,
      hasBudget: trip.budget > 0
    });
  },

  onInput(e) {
    this.setData({ [e.currentTarget.dataset.field]: e.detail.value });
  },

  onPickCategory(e) {
    this.setData({ categoryIndex: Number(e.detail.value) });
  },

  onPickDate(e) {
    this.setData({ date: e.detail.value });
  },

  onAdd() {
    const amount = Number(this.data.amount);
    if (!amount || amount <= 0) {
      wx.showToast({ title: '请填写金额', icon: 'none' });
      return;
    }
    store.addExpense(this.data.tripId, {
      amount,
      category: this.data.categoryOrder[this.data.categoryIndex],
      note: this.data.note.trim(),
      date: this.data.date
    });
    this.setData({ amount: '', note: '' });
    this.refresh();
  },

  onDeleteExpense(e) {
    const id = e.currentTarget.dataset.id;
    wx.showModal({
      title: '删除这笔记录？',
      confirmText: '删除',
      confirmColor: '#e8574c',
      success: (res) => {
        if (res.confirm) {
          store.deleteExpense(this.data.tripId, id);
          this.refresh();
        }
      }
    });
  }
});
