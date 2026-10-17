import 'package:flutter/material.dart';

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
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool isEmergencyActive = false;
  String trafficStatus = "GREEN (Clear Route)";

  void toggleEmergency() {
    setState(() {
      isEmergencyActive = !isEmergencyActive;
      if (isEmergencyActive) {
        trafficStatus = "ALERT SENT: Traffic Clearance Requested!";
      } else {
        trafficStatus = "GREEN (Clear Route)";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Ambulance Alert System'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Ambulance Status Card
            Card(
              color: isEmergencyActive ? Colors.red.shade100 : Colors.green.shade100,
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
                      isEmergencyActive ? "EMERGENCY MODE ACTIVE" : "NORMAL MODE",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isEmergencyActive ? Colors.red.shade900 : Colors.green.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Traffic Signal Status Box
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
            const SizedBox(height: 40),

            // Emergency Trigger Button
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
                isEmergencyActive ? "STOP EMERGENCY ALERT" : "TRIGGER EMERGENCY ALERT",
                style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}