import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

void main() {
  runApp(const SoilMonitorApp());
}

class SoilMonitorApp extends StatelessWidget {
  const SoilMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Soil & pH Monitor",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.teal,
      ),
      home: const HomePage(),
    );
  }
}

class PHInfo {
  final double value;
  final String condition;
  final Color color;

  PHInfo({
    required this.value,
    required this.condition,
    required this.color,
  });

  factory PHInfo.fromValue(double value, {String? conditionOverride}) {
    double clamped = value.clamp(0.0, 14.0);
    String cond = conditionOverride ?? "";
    Color c = Colors.green;

    if (cond.isEmpty) {
      if (clamped < 6.0) {
        cond = "Acidic";
      } else if (clamped > 8.0) {
        cond = "Alkaline";
      } else {
        cond = "Neutral";
      }
    }

    if (cond.contains("Acid")) {
      c = Colors.redAccent;
    } else if (cond.contains("Alk")) {
      c = Colors.orangeAccent;
    } else {
      c = Colors.greenAccent;
    }

    return PHInfo(value: clamped, condition: cond, color: c);
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  RawDatagramSocket? socket;

  int moisture = 0;
  int raw = 0;
  double voltage = 0.0;
  double phValue = 7.0;
  String status = "Waiting";
  String phCondition = "Neutral";
  
  // Selected measuring mode: 'moisture' or 'ph'
  String selectedMode = "moisture";

  bool connected = false;
  DateTime lastPacket = DateTime.now();

  @override
  void initState() {
    super.initState();
    startUDP();
    monitorConnection();
  }

  void startUDP() async {
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 4210);

      socket!.listen((event) {
        if (event == RawSocketEvent.read) {
          Datagram? packet = socket!.receive();

          if (packet != null) {
            try {
              String message = utf8.decode(packet.data);
              Map<String, dynamic> data = jsonDecode(message);

              if (mounted) {
                setState(() {
                  moisture = (data["moisture"] as num?)?.toInt() ?? 0;
                  raw = (data["raw"] as num?)?.toInt() ?? 0;
                  voltage = (data["voltage"] as num?)?.toDouble() ?? 0.0;
                  phValue = (data["ph"] as num?)?.toDouble() ?? 7.0;
                  status = data["status"]?.toString() ?? "Waiting";
                  phCondition = data["phCondition"]?.toString() ?? "Neutral";

                  if (data.containsKey("mode")) {
                    String devMode = data["mode"].toString();
                    if (devMode.isNotEmpty) {
                      selectedMode = devMode;
                    }
                  }

                  connected = true;
                  lastPacket = DateTime.now();
                });
              }
            } catch (e) {
              debugPrint("JSON Parse Error: $e");
            }
          }
        }
      });
    } catch (e) {
      debugPrint("UDP Socket Error: $e");
    }
  }

  void monitorConnection() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 2));

      if (DateTime.now().difference(lastPacket).inSeconds > 5) {
        if (mounted && connected) {
          setState(() {
            connected = false;
          });
        }
      }

      return mounted;
    });
  }

  Future<void> sendModeToDevice(String newMode) async {
    setState(() {
      selectedMode = newMode;
    });

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 2);
      final request = await client.getUrl(
        Uri.parse("http://192.168.4.1/setMode?mode=$newMode"),
      );
      final response = await request.close();
      client.close();
      debugPrint("Mode changed to $newMode, status: ${response.statusCode}");
    } catch (e) {
      debugPrint("HTTP setMode error (ESP8266 might be unreachable): $e");
    }
  }

  Color moistureColor() {
    switch (status.toUpperCase()) {
      case "DRY":
        return Colors.redAccent;
      case "MOIST":
        return Colors.orangeAccent;
      case "WET":
        return Colors.greenAccent;
      default:
        return Colors.blueAccent;
    }
  }

  @override
  void dispose() {
    socket?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    PHInfo phInfo = PHInfo.fromValue(phValue, conditionOverride: phCondition);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("🌱 Soil & pH Monitor"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              sendModeToDevice(selectedMode);
            },
            tooltip: "Sync Mode with ESP8266",
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection Status Banner
            Card(
              elevation: 2,
              child: ListTile(
                leading: Icon(
                  connected ? Icons.wifi : Icons.wifi_off,
                  color: connected ? Colors.green : Colors.red,
                  size: 30,
                ),
                title: Text(
                  connected ? "ESP8266 Connected" : "Disconnected",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  connected
                      ? "Realtime UDP | IP: 192.168.4.1"
                      : "Connect phone Wi-Fi to 'SoilMonitor'",
                ),
                trailing: Chip(
                  label: Text(
                    selectedMode == "ph" ? "pH Mode" : "Moisture Mode",
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: selectedMode == "ph"
                      ? Colors.purple.withValues(alpha: 0.3)
                      : Colors.teal.withValues(alpha: 0.3),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Mode Selector Toggle
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    const Text(
                      "Select Active Measurement Pin (A0)",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment<String>(
                          value: "moisture",
                          label: Text("🌿 Soil Moisture"),
                          icon: Icon(Icons.water_drop),
                        ),
                        ButtonSegment<String>(
                          value: "ph",
                          label: Text("🧪 pH Sensor"),
                          icon: Icon(Icons.science),
                        ),
                      ],
                      selected: {selectedMode},
                      onSelectionChanged: (Set<String> newSelection) {
                        if (newSelection.isNotEmpty) {
                          sendModeToDevice(newSelection.first);
                        }
                      },
                      style: ButtonStyle(
                        shape: WidgetStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Primary Gauge View based on selectedMode
            if (selectedMode == "moisture") ...[
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      CircularPercentIndicator(
                        radius: 110,
                        lineWidth: 16,
                        animation: true,
                        percent: (moisture / 100).clamp(0.0, 1.0),
                        circularStrokeCap: CircularStrokeCap.round,
                        progressColor: moistureColor(),
                        backgroundColor: Colors.white10,
                        center: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "$moisture%",
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text("Soil Moisture"),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Chip(
                        avatar: const Icon(Icons.grass, size: 18),
                        label: Text(
                          status,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        backgroundColor: moistureColor().withValues(alpha: 0.2),
                        side: BorderSide(color: moistureColor()),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.science, color: Colors.purpleAccent),
                          SizedBox(width: 8),
                          Text(
                            "pH Electrode Level",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: (phInfo.value / 14.0).clamp(0.0, 1.0),
                          minHeight: 16,
                          color: phInfo.color,
                          backgroundColor: Colors.white10,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("0 (Acidic)", style: TextStyle(fontSize: 11)),
                          Text("7 (Neutral)", style: TextStyle(fontSize: 11)),
                          Text("14 (Alkaline)", style: TextStyle(fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "${phInfo.value.toStringAsFixed(2)} pH",
                        style: const TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Chip(
                        label: Text(
                          phInfo.condition,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        backgroundColor: phInfo.color.withValues(alpha: 0.2),
                        side: BorderSide(color: phInfo.color),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Secondary Stats Cards
            Row(
              children: [
                Expanded(
                  child: infoCard(
                    "Raw ADC",
                    "$raw",
                    Icons.memory,
                    Colors.blueAccent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: infoCard(
                    "Voltage",
                    "${voltage.toStringAsFixed(3)} V",
                    Icons.bolt,
                    Colors.amberAccent,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Detailed Sensor Matrix Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Live Pin A0 Sensor Details",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    infoTile(
                      Icons.tune,
                      "Active Selection",
                      selectedMode == "ph" ? "pH Sensor" : "Soil Moisture",
                    ),
                    infoTile(Icons.water_drop, "Moisture", "$moisture %"),
                    infoTile(
                      Icons.science,
                      "pH Reading",
                      "${phInfo.value.toStringAsFixed(2)} (${phInfo.condition})",
                    ),
                    infoTile(Icons.bolt, "Pin Voltage", "${voltage.toStringAsFixed(3)} V"),
                    infoTile(Icons.memory, "10-bit ADC Value", "$raw (0 - 1023)"),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Shared Pin Hardware Hint
            Card(
              color: Colors.blueGrey.shade900,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.cyanAccent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "NodeMCU Pin A0 is currently reading ${selectedMode == 'ph' ? 'pH Sensor' : 'Soil Moisture Sensor'}. Ensure the sensor signal wire is connected to A0.",
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget infoCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget infoTile(IconData icon, String title, String value) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 20, color: Colors.tealAccent),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      trailing: Text(
        value,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
  }
}
