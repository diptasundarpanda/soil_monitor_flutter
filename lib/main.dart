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
      title: "Soil Monitor",
      debugShowCheckedModeBanner: false,

      theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),

      home: const HomePage(),
    );
  }
}

class PHInfo {
  final double value;
  final String condition;
  final Color color;

  PHInfo({required this.value, required this.condition, required this.color});

  factory PHInfo.fromValue(double value) {
    if (value < 6) {
      return PHInfo(value: value, condition: "Acidic", color: Colors.red);
    }

    if (value > 8) {
      return PHInfo(value: value, condition: "Alkaline", color: Colors.orange);
    }

    return PHInfo(value: value, condition: "Neutral", color: Colors.green);
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

  bool connected = false;

  String status = "Waiting";

  DateTime lastPacket = DateTime.now();

  PHInfo phInfo = PHInfo.fromValue(7.0);

  @override
  void initState() {
    super.initState();

    startUDP();
    monitorConnection();
  }

  void startUDP() async {
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
                moisture = data["moisture"];

                raw = data["raw"];

                status = data["status"];

                connected = true;

                lastPacket = DateTime.now();

                // future use
                // phInfo = PHInfo.fromValue(data["ph"]);
              });
            }
          } catch (e) {
            debugPrint(e.toString());
          }
        }
      }
    });
  }

  void monitorConnection() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 2));

      if (DateTime.now().difference(lastPacket).inSeconds > 5) {
        if (mounted) {
          setState(() {
            connected = false;
          });
        }
      }

      return mounted;
    });
  }

  Color moistureColor() {
    switch (status) {
      case "DRY":
        return Colors.red;

      case "MOIST":
        return Colors.orange;

      case "WET":
        return Colors.green;

      default:
        return Colors.blue;
    }
  }

  @override
  void dispose() {
    socket?.close();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text("🌱 Soil Monitor")),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),

        child: Column(
          children: [
            Card(
              child: ListTile(
                leading: Icon(
                  connected ? Icons.wifi : Icons.wifi_off,

                  color: connected ? Colors.green : Colors.red,
                ),

                title: Text(connected ? "ESP32 Connected" : "Disconnected"),

                subtitle: const Text("Realtime UDP"),
              ),
            ),

            const SizedBox(height: 25),

            CircularPercentIndicator(
              radius: 120,

              lineWidth: 15,

              animation: true,

              percent: moisture / 100,

              circularStrokeCap: CircularStrokeCap.round,

              progressColor: moistureColor(),

              center: Column(
                mainAxisAlignment: MainAxisAlignment.center,

                children: [
                  Text(
                    "$moisture%",

                    style: const TextStyle(
                      fontSize: 35,

                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const Text("Moisture"),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: infoCard(
                    "Status",

                    status,

                    Icons.grass,

                    moistureColor(),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: infoCard("ADC", "$raw", Icons.memory, Colors.blue),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Card(
              elevation: 5,

              child: Padding(
                padding: const EdgeInsets.all(20),

                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.science),

                        SizedBox(width: 10),

                        Text(
                          "pH Sensor",

                          style: TextStyle(
                            fontSize: 20,

                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    LinearProgressIndicator(
                      value: phInfo.value / 14,

                      minHeight: 12,

                      borderRadius: BorderRadius.circular(20),

                      color: phInfo.color,
                    ),

                    const SizedBox(height: 15),

                    Text(
                      "pH : ${phInfo.value}",

                      style: const TextStyle(
                        fontSize: 28,

                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    Text(phInfo.condition),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),

                child: Column(
                  children: [
                    const Text(
                      "Sensor Details",

                      style: TextStyle(
                        fontSize: 20,

                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    infoTile(Icons.water_drop, "Moisture", "$moisture %"),

                    infoTile(Icons.memory, "Raw ADC", "$raw"),

                    infoTile(Icons.science, "pH", "${phInfo.value}"),

                    infoTile(Icons.grass, "Condition", status),
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
      child: Padding(
        padding: const EdgeInsets.all(15),

        child: Column(
          children: [
            Icon(icon, color: color),

            const SizedBox(height: 10),

            Text(title),

            Text(
              value,

              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget infoTile(IconData icon, String title, String value) {
    return ListTile(
      leading: Icon(icon),

      title: Text(title),

      trailing: Text(value),
    );
  }
}
