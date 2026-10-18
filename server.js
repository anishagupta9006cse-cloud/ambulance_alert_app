// Ambulance Alert Server v2
// - Driver app: start + destination -> route junctions auto-select
// - Police app: apni location bhejta hai, server khud detect karta hai ki ambulance aa rahi hai ya nahi
const http = require('http');
const PORT = process.env.PORT || 5000;

// ============================================================
// JUNCTIONS - YAHAN APNE ASLI JUNCTIONS KI COORDINATES DAALO
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
const policeStations = {};

function distM(lat1, lng1, lat2, lng2) {
  const R = 6371000;
  const rad = (x) => (x * Math.PI) / 180;
  const dLat = rad(lat2 - lat1);
  const dLng = lng2 ? rad(lng2 - lng1) : 0; // safe handling
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos(rad(lat1)) * Math.cos(rad(lat2)) *
            Math.sin(dLng / 2) * Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

const server = http.createServer((req, res) => {
  // CORS headers enable karna taaki Flutter app easily connect ho sake
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'OPTIONS, GET, POST');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  let body = '';
  req.on('data', chunk => {
    body += chunk.toString();
  });

  req.on('end', () => {
    let data = {};
    try {
      if (body) data = JSON.parse(body);
    } catch (e) {
      res.writeHead(400, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Invalid JSON' }));
      return;
    }

    // 1. Driver Update Endpoint
    if (req.url === '/update-driver' && req.method === 'POST') {
      const { driverId, lat, lng, speed } = data;
      ambulances[driverId] = {
        lat,
        lng,
        speed: speed || DEFAULT_SPEED,
        time: Date.now()
      };
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ status: 'success', message: 'Location updated' }));
      return;
    }

    // 2. Police Check Endpoint (Auto-detects incoming ambulance near police location)
    if (req.url === '/police-check' && req.method === 'POST') {
      const { policeId, lat, lng } = data;
      
      let incomingAlert = false;
      let closestEta = null;
      let activeJunction = 'Nearby Area';

      // Check if any active ambulance is close to this police officer's location or junctions
      const now = Date.now();
      for (let dId in ambulances) {
        const amb = ambulances[dId];
        if (now - amb.time < FRESH_MS) {
          const distance = distM(lat, lng, amb.lat, amb.lng);
          if (distance <= 500) { // Agar 500 meter ke andar ambulance hai
            incomingAlert = true;
            const speed = amb.speed > 0 ? amb.speed : DEFAULT_SPEED;
            const etaSeconds = Math.round(distance / speed);
            closestEta = `${etaSeconds} seconds`;
            break;
          }
        }
      }

      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        alert: incomingAlert,
        eta: closestEta,
        message: incomingAlert ? 'RED ALERT: Ambulance Approaching!' : 'No Active Ambulance'
      }));
      return;
    }

    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Endpoint not found' }));
  });
});

server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});