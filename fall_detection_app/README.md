# Caregiver Mobile App (IoT-Based Motion & Fall Detection System)

This mobile app is designed for caregivers to monitor elderly individuals wearing an ESP32-S3 motion & fall detection device.

---

## 📱 Key Features

1. **Real-Time Push Notifications**: Instant high-priority alert when a fall is detected by the wearable.
2. **Device Telemetry Dashboard**: Real-time Online/Offline indicator and battery percentage gauge for the paired wearable unit.
3. **Comprehensive Fall History**: Chronological list of past incidents with date, time, and severity filtering (Severe / Moderate / Mild).
4. **Post-Fall Mobility Indicator**: Differentiates between **Still (Unresponsive / Critical)** and **Recovered (Motion Detected)** states.
5. **Instant One-Touch Emergency Call**: Quick button to dial the elderly person immediately from the dashboard or alert detail screen.
6. **Built-in Presentation & Demo Simulator**: Includes an in-app simulator sheet and a Python script (`tools/simulate_esp32.py`) to trigger live demo alerts without requiring active physical hardware during presentations.

---

## 🏗️ Project Structure

```
fall_detection_app/
├── android/
│   ├── app/
│   │   ├── build.gradle               # Android Gradle config with Firebase BoM
│   │   └── src/main/
│   │       ├── AndroidManifest.xml    # Permissions (CALL_PHONE, POST_NOTIFICATIONS, INTERNET)
│   │       └── kotlin/.../MainActivity.kt
│   └── build.gradle                   # Root build script with google-services plugin
├── lib/
│   ├── models/
│   │   ├── fall_event.dart            # Fall event data model & parsing
│   │   └── device_status.dart         # Wearable telemetry model
│   ├── services/
│   │   ├── notification_service.dart  # Local notification channel & FCM handlers
│   │   ├── firebase_service.dart      # Firestore streams for falls & devices
│   │   └── fall_detection_provider.dart # State management & simulation provider
│   ├── screens/
│   │   ├── splash_screen.dart         # Animated launch & pairing screen
│   │   ├── home_dashboard.dart        # Main caregiver dashboard & quick call
│   │   ├── history_screen.dart        # Incident list with severity filter
│   │   ├── alert_detail_screen.dart   # Incident breakdown & action buttons
│   │   └── settings_screen.dart       # Emergency phone & device pairing config
│   └── main.dart                      # App entry point & theme setup
├── tools/
│   └── simulate_esp32.py              # CLI simulator for ESP32 fall events
└── pubspec.yaml                       # Dependencies
```

---

## 🚀 How to Run the App

### 1. Install Flutter & Dependencies
Once the Flutter SDK is installed:
```bash
cd fall_detection_app
flutter pub get
```

### 2. Connect to Firebase (When Ready)
1. Go to [Firebase Console](https://console.firebase.google.com/) and create a project (`FallDetectionSystem`).
2. Add an Android app with package name: `com.example.fall_detection_app`.
3. Download `google-services.json` and place it in `fall_detection_app/android/app/`.
4. In Firestore, create two collections:
   - `falls`:
     ```json
     {
       "deviceId": "ESP32_001",
       "timestamp": "2026-09-22T14:35:22",
       "type": "Fall",
       "severity": "Severe",
       "still": true,
       "battery": 78,
       "location": "Home"
     }
     ```
   - `devices`:
     ```json
     {
       "deviceId": "ESP32_001",
       "status": "online",
       "battery": 78,
       "lastSeen": "2026-09-22T14:30:00"
     }
     ```

### 3. Run the App
```bash
flutter run
```

---

## 🧪 Testing & Presentations (Demo Mode)

The app comes preconfigured with **Demo / Simulation Mode** enabled by default:
- You can tap the red **"Simulate Fall Alert"** button on the Home Dashboard to trigger real-time **Severe**, **Moderate**, or **Mild** falls.
- It will immediately display the high-priority incident card, play the alert, and let you test the **"Call Elderly Person"** flow.
- You can also run `python tools/simulate_esp32.py` in your terminal to see the exact JSON payloads sent over the air from the ESP32.
