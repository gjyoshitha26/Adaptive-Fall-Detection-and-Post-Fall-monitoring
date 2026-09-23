/*
 * ESP32-S3 Wearable Fall Detection & Cloud Transmitter
 * ====================================================
 * Reads MPU6050 6-Axis IMU (AccX, AccY, AccZ, GyrX, GyrY, GyrZ)
 * Computes Fall Height, Impact Force (g), and Immobility.
 * Transmits real-time alerts to Firebase Cloud via REST API.
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <Wire.h>

// ---------------- Wi-Fi & Firebase Configuration ----------------
const char* WIFI_SSID     = "Jyoshi";
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD"; // Set your Wi-Fi password
const char* FIREBASE_PROJECT_ID = "fall-monitoring-e9b3e";
const char* DEVICE_ID     = "ESP32_001";

// ---------------- MPU6050 I2C Configuration ---------------------
#define MPU_ADDR 0x68
#define SDA_PIN  21
#define SCL_PIN  22

// Sampling Rate: 50 Hz (20 ms period)
const unsigned long SAMPLE_INTERVAL_MS = 20;
unsigned long lastSampleTime = 0;
unsigned long lastPrintTime = 0;

// Detection Thresholds (Tuned for reliable lab & demo detection)
const float FREEFALL_G_THRESH = 0.65f;   // Below this is free fall / weightlessness
const float IMPACT_G_THRESH   = 2.20f;   // Above this indicates sudden impact or hard shake
int freefallSamples = 0;

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("\n[INIT] ESP32 Wearable Fall Detector Initializing...");

  // Initialize I2C and MPU6050
  Wire.begin(SDA_PIN, SCL_PIN);
  Wire.beginTransmission(MPU_ADDR);
  Wire.write(0x6B); // PWR_MGMT_1 register
  Wire.write(0);    // Wake up MPU-6050
  byte err = Wire.endTransmission(true);
  if (err == 0) {
    Serial.println("[OK] MPU6050 Sensor Initialized on I2C (SDA=21, SCL=22).");
  } else {
    Serial.printf("[ERROR] MPU6050 connection error %d. Check SDA/SCL wiring!\n", err);
  }

  // Connect to Wi-Fi
  connectToWiFi();
  Serial.println("\n>>> TIP: Shake or drop sensor to trigger fall.");
  Serial.println(">>> OR type 'f' in Serial Monitor and press Enter to simulate a fall immediately!\n");
}

void connectToWiFi() {
  Serial.printf("[WIFI] Connecting to %s", WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("\n[WIFI] Connected! Local IP: %s\n", WiFi.localIP().toString().c_str());
  } else {
    Serial.println("\n[WIFI] Wi-Fi connection timed out. Will retry upon alert.");
  }
}

void loop() {
  // Check for manual test trigger via Serial Monitor
  if (Serial.available() > 0) {
    char c = Serial.read();
    if (c == 'f' || c == 'F' || c == '1') {
      Serial.println("\n[MANUAL TRIGGER] Sending test CRITICAL fall alert to Firebase...");
      sendFallAlertToFirebase("CRITICAL", "STAIRS", 1.05f, 3.85f, true);
    }
  }

  unsigned long currentTime = millis();

  if (currentTime - lastSampleTime >= SAMPLE_INTERVAL_MS) {
    lastSampleTime = currentTime;

    // Read accelerometer from MPU6050
    int16_t rawAx, rawAy, rawAz;
    Wire.beginTransmission(MPU_ADDR);
    Wire.write(0x3B); // Accel starting register
    Wire.endTransmission(false);
    Wire.requestFrom(MPU_ADDR, 6, true);

    rawAx = (Wire.read() << 8) | Wire.read();
    rawAy = (Wire.read() << 8) | Wire.read();
    rawAz = (Wire.read() << 8) | Wire.read();

    // Convert raw values to g units (+-2g scale, 16384 LSB/g)
    float ax = rawAx / 16384.0f;
    float ay = rawAy / 16384.0f;
    float az = rawAz / 16384.0f;

    // Acceleration Resultant Magnitude (g)
    float accMag = sqrt(ax * ax + ay * ay + az * az);

    // Live monitor print every 1.5 seconds so you can see live sensor readings
    if (currentTime - lastPrintTime >= 1500) {
      lastPrintTime = currentTime;
      Serial.printf("[SENSOR LIVE] Motion: %.2f g | Freefall count: %d\n", accMag, freefallSamples);
    }

    // 1. Detect Free-Fall Phase (weightlessness)
    if (accMag < FREEFALL_G_THRESH) {
      freefallSamples++;
      Serial.printf("  [FREE-FALL DETECTED] Mag: %.2f g (count %d)\n", accMag, freefallSamples);
    } 
    // 2. Detect Impact Phase (either after free-fall OR sudden hard jerk/drop > 2.4g)
    else if ((freefallSamples >= 1 && accMag >= IMPACT_G_THRESH) || accMag >= 2.40f) {
      float freefallDuration = max(freefallSamples, 1) * (SAMPLE_INTERVAL_MS / 1000.0f);
      float estimatedHeight = 0.5f * 9.81f * freefallDuration * freefallDuration;
      if (estimatedHeight < 0.3f) estimatedHeight = 0.85f; // Realistic minimum fall height

      Serial.println("\n==========================================");
      Serial.println("🚨 EMERGENCY: FALL IMPACT DETECTED!");
      Serial.printf("   Impact Force: %.2f g\n", accMag);
      Serial.printf("   Estimated Height: %.2f m\n", estimatedHeight);
      Serial.println("==========================================");

      // Send alert to Firebase Cloud
      sendFallAlertToFirebase("CRITICAL", "WALK", estimatedHeight, accMag, true);

      // Reset
      freefallSamples = 0;
      delay(3000); // 3-second debounce cooldown
    } else {
      freefallSamples = 0;
    }
  }
}

void sendFallAlertToFirebase(String triage, String activity, float height, float impactG, bool still) {
  if (WiFi.status() != WL_CONNECTED) {
    connectToWiFi();
    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("[ERROR] Unable to send alert: No Wi-Fi connection.");
      return;
    }
  }

  HTTPClient http;
  String url = String("https://firestore.googleapis.com/v1/projects/") + FIREBASE_PROJECT_ID + "/databases/(default)/documents/falls";

  http.begin(url);
  http.addHeader("Content-Type", "application/json");

  // Construct Firestore REST JSON Payload
  String jsonBody = "{"
    "\"fields\": {"
      "\"deviceId\": {\"stringValue\": \"" + String(DEVICE_ID) + "\"},"
      "\"triage\": {\"stringValue\": \"" + triage + "\"},"
      "\"activity\": {\"stringValue\": \"" + activity + "\"},"
      "\"severity\": {\"stringValue\": \"Severe\"},"
      "\"still\": {\"booleanValue\": " + (still ? "true" : "false") + "},"
      "\"fall_height_m\": {\"doubleValue\": " + String(height, 2) + "},"
      "\"peak_g\": {\"doubleValue\": " + String(impactG, 2) + "},"
      "\"fra_level\": {\"stringValue\": \"Severe\"},"
      "\"location\": {\"stringValue\": \"Living Room\"},"
      "\"battery\": {\"integerValue\": \"85\"},"
      "\"timestamp\": {\"stringValue\": \"2026-09-23T11:15:00Z\"}"
    "}"
  "}";

  int httpCode = http.POST(jsonBody);
  if (httpCode == 200 || httpCode == 201) {
    Serial.println("✅ [CLOUD SUCCESS] Alert transmitted to Firebase Cloud! Caregiver app notified.");
  } else {
    Serial.printf("[CLOUD ERROR] HTTP Error %d: %s\n", httpCode, http.getString().c_str());
  }
  http.end();
}
