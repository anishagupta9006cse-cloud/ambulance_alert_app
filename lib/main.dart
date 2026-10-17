import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

// ============================================================
// SETTINGS - CHANGE ONLY HERE
// ============================================================
// Backend server address.
// PC demo:            http://localhost:5000
// Phone on same WiFi: http://<PC-IP>:5000  (e.g. http://10.146.52.87:5000)
const String baseUrl = 'https://ambulance-alert-app.onrender.com';

// Junctions for route selection (edit as needed)
const List<String> allJunctions = [
  'Junction-1',
  'Junction-2',
  'Junction-3',
  'Junction-4',
  'Junction-5',
];

void main() {
  runApp(const AmbulanceAlertApp());
}

class AmbulanceAlertApp extends StatelessWidget {
  const AmbulanceAlertApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Ambulance Alert',
      theme: ThemeData(
        primarySwatch: Colors.red,
        useMaterial3: true,
      ),
      home: const ModeSelectScreen(),
    );
  }
}

// ============================================================
// SCREEN 1: MODE SELECT
// ============================================================
class ModeSelectScreen extends StatelessWidget {
  const ModeSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Ambulance Alert System'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.emergency, size: 90, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Select your mode',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 80,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.medical_services, size: 32),
                label: const Text('Driver Mode\n(Ambulance Driver)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18)),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DriverScreen()),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 80,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade800,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.local_police, size: 32),
                label: const Text('Police Mode\n(Traffic Police)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18)),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PoliceLoginScreen()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SCREEN 2: DRIVER MODE
// (Dashboard + Map + GPS + Route + live location)
// ============================================================
class DriverScreen extends StatefulWidget {
  const DriverScreen({super.key});

  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _ambulanceIdController =
      TextEditingController(text: 'AMB-101');

  StreamSubscription<Position>? _positionSub;
  LatLng? _current;
  final List<String> _selectedRoute = [];

  bool isEmergencyActive = false;
  String trafficStatus = "GREEN (Clear Route)";

  Future<bool> _checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => trafficStatus = 'Please turn ON phone GPS/Location');
      return false;
    }
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      setState(() => trafficStatus = 'Location permission denied');
      return false;
    }
    return true;
  }

  Future<void> toggleEmergency() async {
    if (isEmergencyActive) {
      _stopEmergency();
    } else {
      await _startEmergency();
    }
  }

  Future<void> _startEmergency() async {
    if (_selectedRoute.isEmpty) {
      setState(() => trafficStatus = 'Please select a route (junctions) first');
      return;
    }
    if (!await _checkPermission()) return;

    setState(() {
      isEmergencyActive = true;
      trafficStatus = "ALERT SENT: Traffic Clearance Requested!";
    });

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // update every 5 meters
    );

    _positionSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen((Position pos) {
      final point = LatLng(pos.latitude, pos.longitude);
      setState(() => _current = point);
      _mapController.move(point, 16);
      _sendLocation(pos, true);
    });
  }

  void _stopEmergency() {
    _positionSub?.cancel();
    _positionSub = null;
    // Tell the server the emergency has ended
    if (_current != null) {
      _sendLocation(
        Position(
          latitude: _current!.latitude,
          longitude: _current!.longitude,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        ),
        false,
      );
    }
    setState(() {
      isEmergencyActive = false;
      trafficStatus = "GREEN (Clear Route)";
    });
  }

  Future<void> _sendLocation(Position pos, bool emergency) async {
    try {
      await http
          .post(
            Uri.parse('$baseUrl/api/ambulance/location'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'ambulanceId': _ambulanceIdController.text.trim(),
              'lat': pos.latitude,
              'lng': pos.longitude,
              'speed': pos.speed, // meters/second
              'route': _selectedRoute,
              'emergency': emergency,
              'timestamp': DateTime.now().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      if (mounted && isEmergencyActive) {
        setState(() => trafficStatus = 'ALERT ON, but cannot connect to server');
      }
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _ambulanceIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Ambulance Alert System'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---------- Ambulance Status Card ----------
            Card(
              color: isEmergencyActive
                  ? Colors.red.shade100
                  : Colors.green.shade100,
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.medical_services,
                      size: 60,
                      color: isEmergencyActive ? Colors.red : Colors.green,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isEmergencyActive
                          ? "EMERGENCY MODE ACTIVE"
                          : "NORMAL MODE",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isEmergencyActive
                            ? Colors.red.shade900
                            : Colors.green.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ---------- MAP ----------
            SizedBox(
              height: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FlutterMap(
                  mapController: _mapController,
                  options: const MapOptions(
                    initialCenter: LatLng(28.6139, 77.2090), // Delhi default
                    initialZoom: 12,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.ambulance_alert_app',
                    ),
                    if (_current != null)
                      MarkerLayer(markers: [
                        Marker(
                          point: _current!,
                          width: 50,
                          height: 50,
                          child: const Icon(Icons.local_hospital,
                              color: Colors.red, size: 40),
                        ),
                      ]),
                  ],
                ),
              ),
            ),
            if (_current != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Lat: ${_current!.latitude.toStringAsFixed(5)}, Lng: ${_current!.longitude.toStringAsFixed(5)}',
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 16),

            // ---------- Ambulance ID + Route select ----------
            TextField(
              controller: _ambulanceIdController,
              enabled: !isEmergencyActive,
              decoration: const InputDecoration(
                labelText: 'Ambulance ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Select route (tap junctions in order):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Wrap(
              spacing: 8,
              children: allJunctions.map((j) {
                final selected = _selectedRoute.contains(j);
                return FilterChip(
                  label: Text(j),
                  selected: selected,
                  onSelected: isEmergencyActive
                      ? null
                      : (v) => setState(() {
                            v ? _selectedRoute.add(j) : _selectedRoute.remove(j);
                          }),
                );
              }).toList(),
            ),
            const SizedBox(height: 6),
            Text(
              _selectedRoute.isEmpty
                  ? 'Route: none selected'
                  : 'Route: ${_selectedRoute.join("  →  ")}',
            ),
            const SizedBox(height: 20),

            // ---------- Traffic Signal Status Box ----------
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: Column(
                children: [
                  const Text(
                    "IoT Traffic Signal Status:",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    trafficStatus,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isEmergencyActive ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // ---------- Emergency Trigger Button ----------
            ElevatedButton(
              onPressed: toggleEmergency,
              style: ElevatedButton.styleFrom(
                backgroundColor: isEmergencyActive ? Colors.grey : Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Text(
                isEmergencyActive
                    ? "STOP EMERGENCY ALERT"
                    : "TRIGGER EMERGENCY ALERT",
                style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SCREEN 3: POLICE MODE - Junction ID input
// ============================================================
class PoliceLoginScreen extends StatefulWidget {
  const PoliceLoginScreen({super.key});

  @override
  State<PoliceLoginScreen> createState() => _PoliceLoginScreenState();
}

class _PoliceLoginScreenState extends State<PoliceLoginScreen> {
  final TextEditingController _junctionController = TextEditingController();
  String? _error;

  void _submit() {
    final id = _junctionController.text.trim();
    if (id.isEmpty) {
      setState(() => _error = 'Junction ID is required');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PoliceAlertScreen(junctionId: id)),
    );
  }

  @override
  void dispose() {
    _junctionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Police Mode'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.local_police, size: 80, color: Colors.blue),
            const SizedBox(height: 24),
            TextField(
              controller: _junctionController,
              decoration: InputDecoration(
                labelText: 'Junction ID (e.g. Junction-1)',
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _submit,
                child: const Text('Start Receiving Alerts',
                    style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SCREEN 4: POLICE ALERT SCREEN (Red Alert, Siren, ETA)
// ============================================================
class PoliceAlertScreen extends StatefulWidget {
  final String junctionId;
  const PoliceAlertScreen({super.key, required this.junctionId});

  @override
  State<PoliceAlertScreen> createState() => _PoliceAlertScreenState();
}

class _PoliceAlertScreenState extends State<PoliceAlertScreen> {
  Timer? _pollTimer;
  Timer? _sirenTimer;

  bool _alert = false;
  bool _siren = false;
  int? _etaSeconds;
  String _ambulanceId = '';
  String _info = 'Waiting for alerts from server...';

  @override
  void initState() {
    super.initState();
    _fetchAlert();
    _pollTimer =
        Timer.periodic(const Duration(seconds: 3), (_) => _fetchAlert());
  }

  Future<void> _fetchAlert() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/junction/${widget.junctionId}/alerts'))
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final bool alert = data['alert'] == true;
        final bool siren = data['siren'] == true;

        setState(() {
          _alert = alert;
          _siren = siren;
          _etaSeconds = data['etaSeconds'] is num
              ? (data['etaSeconds'] as num).toInt()
              : null;
          _ambulanceId = (data['ambulanceId'] ?? '').toString();
          _info = alert ? 'Ambulance approaching!' : 'No alerts - all normal';
        });
        _handleSiren(alert && siren);
      } else {
        setState(() => _info = 'Server error: ${res.statusCode}');
      }
    } catch (e) {
      setState(() => _info = 'Cannot connect to server');
    }
  }

  // Siren: phone vibration + alert sound every 1 second
  void _handleSiren(bool on) {
    if (on && _sirenTimer == null) {
      _sirenTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
      });
    } else if (!on) {
      _sirenTimer?.cancel();
      _sirenTimer = null;
    }
  }

  String _formatEta(int? sec) {
    if (sec == null) return '--';
    if (sec < 60) return '$sec sec';
    return '${sec ~/ 60} min ${sec % 60} sec';
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _sirenTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _alert ? Colors.red.shade700 : Colors.green.shade700;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(widget.junctionId),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _alert ? Icons.warning_amber_rounded : Icons.check_circle,
                size: 120,
                color: Colors.white,
              ),
              const SizedBox(height: 16),
              Text(
                _alert ? 'RED ALERT' : 'ALL CLEAR',
                style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(_info,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, color: Colors.white)),
              if (_alert) ...[
                const SizedBox(height: 24),
                Text('Ambulance: $_ambulanceId',
                    style: const TextStyle(fontSize: 20, color: Colors.white)),
                const SizedBox(height: 8),
                const Text('ETA',
                    style: TextStyle(fontSize: 18, color: Colors.white70)),
                Text(_formatEta(_etaSeconds),
                    style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 12),
                Text(_siren ? '🔊 SIREN ON' : '🔇 Siren off',
                    style: const TextStyle(fontSize: 20, color: Colors.white)),
                const SizedBox(height: 8),
                const Text('Clear the traffic!',
                    style: TextStyle(fontSize: 22, color: Colors.yellow)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}