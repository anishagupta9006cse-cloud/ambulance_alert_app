// Ambulance Alert Server (online deploy ke liye taiyaar)
const http = require('http');
const PORT = process.env.PORT || 5000;

const ambulances = {};
const manualAlerts = {};

function sendJson(res, status, obj) {
  res.writeHead(status, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  });
  res.end(JSON.stringify(obj));
}

const server = http.createServer((req, res) => {
  if (req.method === 'OPTIONS') return sendJson(res, 204, {});

  const url = new URL(req.url, `http://${req.headers.host}`);
  const path = url.pathname;

  // Home page check
  if (req.method === 'GET' && path === '/') {
    return sendJson(res, 200, { ok: true, message: 'Ambulance server is running' });
  }

  // 1) Driver location receive
  if (req.method === 'POST' && path === '/api/ambulance/location') {
    let body = '';
    req.on('data', (c) => (body += c));
    req.on('end', () => {
      try {
        const d = JSON.parse(body);
        ambulances[d.ambulanceId] = {
          lat: d.lat,
          lng: d.lng,
          speed: d.speed || 0,
          route: d.route || [],
          emergency: d.emergency === true,
          updatedAt: Date.now(),
        };
        console.log(`[Driver] ${d.ambulanceId} emergency=${d.emergency} route=${(d.route || []).join('>')}`);
        sendJson(res, 200, { ok: true });
      } catch (e) {
        sendJson(res, 400, { error: 'bad json' });
      }
    });
    return;
  }

  // 2) Police alerts
  const m = path.match(/^\/api\/junction\/([^/]+)\/alerts$/);
  if (req.method === 'GET' && m) {
    const junction = decodeURIComponent(m[1]);

    if (manualAlerts[junction]) {
      return sendJson(res, 200, {
        alert: true,
        siren: true,
        ambulanceId: manualAlerts[junction].ambulanceId,
        etaSeconds: manualAlerts[junction].etaSeconds,
      });
    }

    const now = Date.now();
    for (const [id, a] of Object.entries(ambulances)) {
      const fresh = now - a.updatedAt < 15000;
      const idx = a.route.indexOf(junction);
      if (a.emergency && fresh && idx !== -1) {
        return sendJson(res, 200, {
          alert: true,
          siren: true,
          ambulanceId: id,
          etaSeconds: (idx + 1) * 60,
        });
      }
    }
    return sendJson(res, 200, { alert: false, siren: false });
  }

  // 3) Demo shortcut
  const d1 = path.match(/^\/demo\/on\/([^/]+)$/);
  if (d1) {
    manualAlerts[decodeURIComponent(d1[1])] = { ambulanceId: 'AMB-101', etaSeconds: 90 };
    return sendJson(res, 200, { ok: true, message: 'Alert ON' });
  }
  const d2 = path.match(/^\/demo\/off\/([^/]+)$/);
  if (d2) {
    delete manualAlerts[decodeURIComponent(d2[1])];
    return sendJson(res, 200, { ok: true, message: 'Alert OFF' });
  }

  sendJson(res, 404, { error: 'not found' });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
});
