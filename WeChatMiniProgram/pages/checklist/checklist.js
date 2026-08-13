const store = require('../../utils/store.js');
const meta = require('../../utils/meta.js');

Page({
  data: {
    tripId: '',
    groups: [],
    done: 0,
    total: 0,
    percent: 0,
    categories: meta.CHECKLIST_CATEGORIES,
    newTitle: '',
    newCategoryIndex: 5
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
    const groups = meta.CHECKLIST_CATEGORIES
      .map((category) => ({
        category,
        items: trip.checklist.filter((c) => c.category === category)
      }))
      .filter((g) => g.items.length > 0);
    const total = trip.checklist.length;
    const done = trip.checklist.filter((c) => c.done).length;
    this.setData({
      groups,
      total,
      done,
      percent: total ? Math.round(done / total * 100) : 0
    });
  },

  onToggle(e) {
    store.toggleChecklistItem(this.data.tripId, e.currentTarget.dataset.id);
    this.refresh();
  },

  onDelete(e) {
    store.deleteChecklistItem(this.data.tripId, e.currentTarget.dataset.id);
    this.refresh();
  },

  onInputTitle(e) {
    this.setData({ newTitle: e.detail.value });
  },

  onPickCategory(e) {
    this.setData({ newCategoryIndex: Number(e.detail.value) });
  },

  onAdd() {
    const title = this.data.newTitle.trim();
    if (!title) return;
    store.addChecklistItem(this.data.tripId, title, this.data.categories[this.data.newCategoryIndex]);
    this.setData({ newTitle: '' });
    this.refresh();
  },

  onImportTemplate() {
    const options = ['导入全部模板'].concat(meta.CHECKLIST_TEMPLATE.map((g) => '导入「' + g.category + '」'));
    wx.showActionSheet({
      itemList: options,
      success: (res) => {
        const categories = res.tapIndex === 0
          ? meta.CHECKLIST_TEMPLATE.map((g) => g.category)
          : [meta.CHECKLIST_TEMPLATE[res.tapIndex - 1].category];
        store.importChecklistTemplate(this.data.tripId, categories);
        this.refresh();
      }
    });
  }
});
