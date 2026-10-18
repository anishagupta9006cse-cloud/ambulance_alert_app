 
Server · JS
// Ambulance Alert Server v2
// - Driver app: start + destination -> route junctions auto-select
// - Police app: apni location bhejta hai, server khud detect karta hai ki ambulance aa rahi hai ya nahi
const http = require('http');
const PORT = process.env.PORT || 5000;
 
// ============================================================
// JUNCTIONS - YAHAN APNE ASLI JUNCTIONS KI COORDINATES DAALO
// (Google Maps me junction par long-press karo -> upar coordinates
//  dikhenge, jaise 24.8028, 85.0056 -> pehla number lat, doosra lng)
// Neeche ke 5 junctions sirf SAMPLE hain.
// ============================================================
const JUNCTIONS = [
  { id: 'Junction-1', name: 'Junction-1', lat: 24.8028, lng: 85.0056 },
  { id: 'Junction-2', name: 'Junction-2', lat: 24.8065, lng: 85.009 },
  { id: 'Junction-3', name: 'Junction-3', lat: 24.811, lng: 85.013 },
  { id: 'Junction-4', name: 'Junction-4', lat: 24.8, lng: 85.0 },
  { id: 'Junction-5', name: 'Junction-5', lat: 24.796, lng: 84.996 },
];
 
const FRESH_MS = 20000; // itne ms se purani location ignore
const REACH_M = 40; // junction ke itne meter ke andar = pahunch gayi
const PASSED_M = 80; // pahunchne ke baad itna door = junction cross ho gaya
const DEFAULT_SPEED = 8.3; // m/s (~30 km/h), jab phone ki speed 0 ho
 
const ambulances = {};
 
function distM(lat1, lng1, lat2, lng2) {
  const R = 6371000;
  const rad = (x) => (x * Math.PI) / 180;
  const dLat = rad(lat2 - lat1);
  const dLng = rad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(rad(lat1)) * Math.cos(rad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.min(1, Math.sqrt(a)));
}
 
function etaSeconds(distance, speed) {
  const v = speed > 3 ? speed : DEFAULT_SPEED;
  return Math.round(distance / v);
}
 
function sendJson(res, status, obj) {
  res.writeHead(status, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  });
  res.end(JSON.stringify(obj));
}
 
function updateAmbulance(d) {
  if (!d.ambulanceId || typeof d.lat !== 'number' || typeof d.lng !== 'number') {
    return false;
  }
  const route = (Array.isArray(d.route) ? d.route : []).filter(
    (j) => j && j.id && typeof j.lat === 'number' && typeof j.lng === 'number'
  );
  const prev = ambulances[d.ambulanceId];
  const sameRoute =
    prev && prev.route.map((j) => j.id).join('|') === route.map((j) => j.id).join('|');
  const reached = sameRoute ? prev.reached : {};
  for (const j of route) {
    if (distM(d.lat, d.lng, j.lat, j.lng) <= REACH_M) reached[j.id] = true;
  }
  ambulances[d.ambulanceId] = {
    lat: d.lat,
    lng: d.lng,
    speed: typeof d.speed === 'number' ? d.speed : 0,
    route,
    reached,
    emergency: d.emergency === true,
    updatedAt: Date.now(),
  };
  return true;
}
 
function cleanup() {
  const now = Date.now();
  for (const [id, a] of Object.entries(ambulances)) {
    if (!a.demo && now - a.updatedAt > 10 * 60 * 1000) delete ambulances[id];
  }
}
 
const server = http.createServer((req, res) => {
  if (req.method === 'OPTIONS') return sendJson(res, 204, {});
 
  const url = new URL(req.url, `http://${req.headers.host}`);
  const path = url.pathname;
 
  if (req.method === 'GET' && path === '/') {
    return sendJson(res, 200, { ok: true, message: 'Ambulance server is running' });
  }
 
  // ---------- Junction list (dono apps yahan se leti hain) ----------
  if (req.method === 'GET' && path === '/api/junctions') {
    return sendJson(res, 200, { junctions: JUNCTIONS });
  }
 
  // ---------- Driver location + route ----------
  if (req.method === 'POST' && path === '/api/ambulance/location') {
    let body = '';
    req.on('data', (c) => (body += c));
    req.on('end', () => {
      try {
        const d = JSON.parse(body);
        if (!updateAmbulance(d)) return sendJson(res, 400, { error: 'missing fields' });
        console.log(
          `[Driver] ${d.ambulanceId} emergency=${d.emergency} junctions=${(d.route || [])
            .map((j) => j.id)
            .join('>')}`
        );
        cleanup();
        sendJson(res, 200, { ok: true });
      } catch (e) {
        sendJson(res, 400, { error: 'bad json' });
      }
    });
    return;
  }
 
  // ---------- Police alert detection ----------
  // GET /api/police/alerts?lat=..&lng=..&radius=500
  if (req.method === 'GET' && path === '/api/police/alerts') {
    const lat = parseFloat(url.searchParams.get('lat'));
    const lng = parseFloat(url.searchParams.get('lng'));
    const radius = parseFloat(url.searchParams.get('radius')) || 500;
    if (isNaN(lat) || isNaN(lng)) return sendJson(res, 400, { error: 'lat and lng required' });
 
    const now = Date.now();
    let best = null;
    for (const [id, a] of Object.entries(ambulances)) {
      if (!a.emergency) continue;
      if (!a.demo && now - a.updatedAt > FRESH_MS) continue;
      for (const j of a.route) {
        if (distM(lat, lng, j.lat, j.lng) > radius) continue; // junction police ke area me nahi
        const dAmb = distM(a.lat, a.lng, j.lat, j.lng);
        if (a.reached[j.id] && dAmb > PASSED_M) continue; // ambulance nikal chuki hai
        const eta = etaSeconds(dAmb, a.speed);
        if (!best || eta < best.etaSeconds) {
          best = {
            alert: true,
            siren: true,
            ambulanceId: id,
            junctionName: j.name || j.id,
            etaSeconds: eta,
            distanceMeters: Math.round(dAmb),
          };
        }
      }
    }
    return sendJson(res, 200, best || { alert: false, siren: false });
  }
 
  // ---------- Demo shortcut (bina driver ke police app test karne ke liye) ----------
  // Chalu: /demo/on/Junction-1     Band: /demo/off/Junction-1
  const d1 = path.match(/^\/demo\/on\/([^/]+)$/);
  if (d1) {
    const j = JUNCTIONS.find((x) => x.id === decodeURIComponent(d1[1]));
    if (!j) return sendJson(res, 404, { error: 'unknown junction' });
    ambulances['DEMO-AMB'] = {
      lat: j.lat + 0.004, // junction se ~450 m door
      lng: j.lng,
      speed: DEFAULT_SPEED,
      route: [j],
      reached: {},
      emergency: true,
      updatedAt: Date.now(),
      demo: true,
    };
    return sendJson(res, 200, { ok: true, message: 'Demo alert ON' });
  }
  if (path.startsWith('/demo/off/')) {
    delete ambulances['DEMO-AMB'];
    return sendJson(res, 200, { ok: true, message: 'Demo alert OFF' });
  }
 
  sendJson(res, 404, { error: 'not found' });
});
 
server.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
});
 
