# Adaptive Fall Detection & Post-Fall Monitoring System

An end-to-end IoT, Edge-AI, and Mobile Healthcare solution for real-time motion analysis, fall detection, clinical risk triage, and caregiver emergency dispatch.

---

## 🌟 System Architecture

```
[ ESP32-S3 Wearable / IMU Sensors ]
       │ 50 Hz Raw Signals (AccX, AccY, AccZ, GyrX, GyrY, GyrZ)
       ▼
[ TinyML 1D-CNN & Physics Engine ] (fall_detection_pipeline.py)
       ├─ Dual-Head Inference: Activity (6 classes) & Event (3 classes)
       ├─ Signal Physics: Fall Height Estimation (h = 0.5 * g * t_ff^2), Peak Impact (g)
       ├─ Clinical Triage: CRITICAL / HIGH / WATCH / QUIET
       └─ Risk Scoring: CFSS-7 (0-100), Fracture Risk Analysis (FRA: Severe/High/Mod/Low)
       │
       ▼ REST / MQTT / WebSocket
[ Firebase Cloud Platform ]
       ├─ Cloud Firestore: 'falls' & 'devices' collections
       └─ Cloud Functions: onFallIncidentCreated -> Automatic FCM Dispatcher
       │
       ▼ Push Notification (FCM / Local High-Priority Channel)
[ Caregiver Mobile App (Flutter) ]
       ├─ Real-time Dashboard: Online/Offline, Battery gauge, Clinical Triage Alert
       ├─ Incident Breakdown: Activity before fall, Fall height, Impact force, Fracture risk
       └─ Emergency Response: One-touch Call Elderly Person & SMS Check-in
```

---

## 📁 Repository Structure

```
Adaptive-Fall-Detection-and-Post-Fall-monitoring/
├── fall_detection_pipeline.py    # TinyML dual-head CNN, physics & clinical triage engine
├── cloud_backend/                # Cloud functions & push notification services
│   ├── functions/
│   │   ├── index.js              # Automated Firestore-to-FCM notification trigger
│   │   └── package.json          # Cloud functions dependencies
│   └── send_fcm_alert.py         # Direct FCM alert test tool
├── fall_detection_app/           # Caregiver Mobile Application (Flutter)
│   ├── lib/
│   │   ├── models/
│   │   │   ├── fall_event.dart   # Clinical triage, physics & fall schema
│   │   │   └── device_status.dart# Wearable telemetry model
│   │   ├── screens/
│   │   │   ├── splash_screen.dart
│   │   │   ├── home_dashboard.dart
│   │   │   ├── history_screen.dart
│   │   │   ├── alert_detail_screen.dart
│   │   │   └── settings_screen.dart
│   │   ├── services/
│   │   │   ├── fall_detection_provider.dart
│   │   │   ├── firebase_service.dart
│   │   │   └── notification_service.dart
│   │   └── main.dart
│   ├── android/                  # Android permissions & Gradle setup
│   ├── web/                      # Web platform scaffolding
│   └── pubspec.yaml
└── tools/
    ├── pipeline_cloud_bridge.py  # Bridges pipeline physics & sends alerts to Firestore
    └── simulate_esp32.py         # ESP32 telemetry simulator
```

---

## 🚀 Quickstart & Execution

### 1. Run the Caregiver Mobile App
To run the caregiver app on your browser or device:
```bash
cd fall_detection_app
flutter pub get
flutter run -d chrome
```
*Note: The app includes a built-in **Simulation / Demo Mode** allowing you to test CRITICAL, HIGH, and WATCH alerts on the fly without live hardware.*

### 2. Test the Pipeline Cloud Bridge
To generate clinical triage events and send them to the Firebase Cloud:
```bash
python tools/pipeline_cloud_bridge.py
```

### 3. Deploy the Firebase Cloud Function (When ready for live Cloud FCM)
```bash
cd cloud_backend/functions
npm install
firebase deploy --only functions
```
Once deployed, any fall incident written to Firestore will automatically dispatch a high-priority push notification to all caregiver phones!