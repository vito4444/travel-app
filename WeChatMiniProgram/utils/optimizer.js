// 路线顺序优化：最近邻 + 2-opt（固定首尾），与 iOS 版 RouteOptimizer 同算法。
// 坐标对象形如 { lat, lon }。

/** 球面距离（米）。 */
function haversine(a, b) {
  const R = 6371000;
  const rad = Math.PI / 180;
  const lat1 = a.lat * rad;
  const lat2 = b.lat * rad;
  const dLat = (b.lat - a.lat) * rad;
  const dLon = (b.lon - a.lon) * rad;
  const h = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) * Math.sin(dLon / 2);
  return 2 * R * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
}

/** 返回优化后的索引顺序；元素数 > 2 时固定首尾，只重排中间点。 */
function optimizeOrder(coords) {
  const n = coords.length;
  if (n <= 2) return coords.map((_, i) => i);

  const dist = [];
  for (let i = 0; i < n; i++) {
    dist.push(new Array(n).fill(0));
  }
  for (let i = 0; i < n; i++) {
    for (let j = i + 1; j < n; j++) {
      const d = haversine(coords[i], coords[j]);
      dist[i][j] = d;
      dist[j][i] = d;
    }
  }

  // 最近邻：从 0 出发，终点 n-1 固定。
  const last = n - 1;
  const remaining = new Set();
  for (let i = 1; i < last; i++) remaining.add(i);
  const order = [0];
  let current = 0;
  while (remaining.size > 0) {
    let best = -1;
    let bestD = Infinity;
    remaining.forEach((idx) => {
      if (dist[current][idx] < bestD) {
        bestD = dist[current][idx];
        best = idx;
      }
    });
    order.push(best);
    remaining.delete(best);
    current = best;
  }
  order.push(last);

  // 2-opt：反转能缩短总长的区间，首尾不参与。
  let improved = true;
  while (improved) {
    improved = false;
    if (order.length < 4) break;
    for (let i = 1; i < order.length - 2; i++) {
      for (let j = i + 1; j < order.length - 1; j++) {
        const a = order[i - 1], b = order[i];
        const c = order[j], d = order[j + 1];
        const before = dist[a][b] + dist[c][d];
        const after = dist[a][c] + dist[b][d];
        if (after + 0.001 < before) {
          const segment = order.slice(i, j + 1).reverse();
          order.splice(i, segment.length, ...segment);
          improved = true;
        }
      }
    }
  }
  return order;
}

/** 按给定顺序的连线总长（米）。 */
function totalDistance(coords) {
  let total = 0;
  for (let i = 0; i + 1 < coords.length; i++) {
    total += haversine(coords[i], coords[i + 1]);
  }
  return total;
}

/**
 * 分段交通时长估算（分钟）：直线距离 × 平均速度。
 * 小程序端无路线规划服务（需要地图厂商 key），统一按估算并在 UI 标注「估算」。
 * 驾车 30km/h（城市均速），步行 4.5km/h。
 */
function estimateLegMinutes(a, b, mode) {
  const meters = haversine(a, b);
  const speedKmh = mode === 'walking' ? 4.5 : 30;
  return meters / 1000 / speedKmh * 60;
}

module.exports = { haversine, optimizeOrder, totalDistance, estimateLegMinutes };
