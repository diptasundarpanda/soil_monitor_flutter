# 🤖 Flutter Application AGENTS.md

This directory contains the cross-platform mobile application for the **Smart Soil & pH Monitor** project.

---

## 📌 Key Architecture & Dependencies

- **Dart SDK**: `^3.11.0` | **Material 3**: Enabled (`useMaterial3: true`).
- **Main Entrypoint**: `lib/main.dart`
- **Network Protocol**:
  - Receives UDP packets on port `4210` (`RawDatagramSocket`).
  - Sends HTTP GET requests to `http://192.168.4.1/setMode?mode=...` to toggle measuring mode on ESP8266.
- **UI Components**:
  - `SegmentedButton` for switching active pin A0 mode (Moisture vs pH).
  - `CircularPercentIndicator` for Soil Moisture gauge.
  - `LinearProgressIndicator` & custom pH meter scale for pH values.

---

## 🛠️ Build & Verification Command

```bash
flutter analyze
```

*Ensure `flutter analyze` runs with 0 warnings before completing any changes.*
