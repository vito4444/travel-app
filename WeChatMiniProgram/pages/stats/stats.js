const store = require('../../utils/store.js');

Page({
  data: {
    tripCount: 0,
    totalDays: 0,
    destinations: [],
    markers: [],
    includePoints: [],
    hasTrips: false,
    locatedCount: 0
  },

  onShow() {
    const trips = store.getTrips();
    const destinations = [];
    const seen = new Set();
    let totalDays = 0;
    const markers = [];
    const points = [];

    trips.forEach((trip) => {
      totalDays += store.dayCount(trip);
      const name = (trip.destination || '').trim();
      if (name && !seen.has(name)) {
        seen.add(name);
        destinations.push(name);
      }
      trip.items.forEach((item) => {
        if (item.lat != null && item.lon != null) {
          markers.push({
            id: markers.length,
            latitude: item.lat,
            longitude: item.lon,
            width: 18,
            height: 26,
            title: item.title
          });
          points.push({ latitude: item.lat, longitude: item.lon });
        }
      });
    });

    this.setData({
      tripCount: trips.length,
      totalDays,
      destinations,
      markers,
      includePoints: points,
      hasTrips: trips.length > 0,
      locatedCount: markers.length
    });
  }
});
