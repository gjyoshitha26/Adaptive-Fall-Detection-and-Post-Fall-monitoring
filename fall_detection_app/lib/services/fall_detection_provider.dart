import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/fall_event.dart';
import '../models/device_status.dart';
import 'firebase_service.dart';
import 'notification_service.dart';

class FallDetectionProvider extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final NotificationService _notificationService = NotificationService();

  bool _isFirebaseConnected = false;
  bool _useSimulationMode = true; // Enabled by default for easy student testing/demo
  String _caregiverPhone = "+919876543210";
  String _deviceId = "ESP32_001";
  bool _soundEnabled = true;

  DeviceStatus _deviceStatus = DeviceStatus(
    deviceId: "ESP32_001",
    status: "online",
    battery: 84,
    lastSeen: DateTime.now(),
  );

  List<FallEvent> _fallHistory = [];
  StreamSubscription? _fallsSubscription;
  StreamSubscription? _deviceSubscription;

  // Getters
  bool get isFirebaseConnected => _isFirebaseConnected;
  bool get useSimulationMode => _useSimulationMode;
  String get caregiverPhone => _caregiverPhone;
  String get deviceId => _deviceId;
  bool get soundEnabled => _soundEnabled;
  DeviceStatus get deviceStatus => _deviceStatus;
  List<FallEvent> get fallHistory => _fallHistory;
  FallEvent? get latestAlert => _fallHistory.isNotEmpty ? _fallHistory.first : null;

  FallDetectionProvider() {
    _loadSettings();
    _loadInitialMockData();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _caregiverPhone = prefs.getString('caregiver_phone') ?? _caregiverPhone;
      _deviceId = prefs.getString('device_id') ?? _deviceId;
      _soundEnabled = prefs.getBool('sound_enabled') ?? _soundEnabled;
      _useSimulationMode = prefs.getBool('simulation_mode') ?? true;
      notifyListeners();
    } catch (_) {}
  }

  void _loadInitialMockData() {
    final now = DateTime.now();
    _fallHistory = [
      FallEvent(
        id: 'mock_1',
        deviceId: _deviceId,
        timestamp: now.subtract(const Duration(minutes: 8)),
        severity: 'Severe',
        still: true,
        battery: 82,
        location: 'Bedroom',
      ),
      FallEvent(
        id: 'mock_2',
        deviceId: _deviceId,
        timestamp: now.subtract(const Duration(hours: 3, minutes: 24)),
        severity: 'Moderate',
        still: false,
        battery: 88,
        location: 'Living Room',
      ),
      FallEvent(
        id: 'mock_3',
        deviceId: _deviceId,
        timestamp: now.subtract(const Duration(days: 1, hours: 5)),
        severity: 'Mild',
        still: false,
        battery: 94,
        location: 'Garden Walkway',
      ),
    ];
    notifyListeners();
  }

  void toggleSimulationMode(bool enabled) {
    _useSimulationMode = enabled;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('simulation_mode', enabled);
    });

    if (!_useSimulationMode) {
      initFirebaseStreams();
    } else {
      _fallsSubscription?.cancel();
      _deviceSubscription?.cancel();
      _isFirebaseConnected = false;
    }
    notifyListeners();
  }

  Future<void> updateSettings({
    required String phone,
    required String devId,
    required bool sound,
  }) async {
    _caregiverPhone = phone;
    _deviceId = devId;
    _soundEnabled = sound;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('caregiver_phone', phone);
    await prefs.setString('device_id', devId);
    await prefs.setBool('sound_enabled', sound);

    if (!_useSimulationMode) {
      initFirebaseStreams();
    }
    notifyListeners();
  }

  void initFirebaseStreams() {
    try {
      _fallsSubscription?.cancel();
      _deviceSubscription?.cancel();

      _fallsSubscription = _firebaseService.getFallsStream(deviceId: _deviceId).listen(
        (falls) {
          _isFirebaseConnected = true;
          // Check if a new fall arrived
          if (falls.isNotEmpty && (_fallHistory.isEmpty || falls.first.timestamp.isAfter(_fallHistory.first.timestamp))) {
            _onNewFallDetected(falls.first);
          }
          _fallHistory = falls;
          notifyListeners();
        },
        onError: (e) {
          _isFirebaseConnected = false;
          notifyListeners();
        },
      );

      _deviceSubscription = _firebaseService.getDeviceStatusStream(_deviceId).listen(
        (status) {
          if (status != null) {
            _deviceStatus = status;
            notifyListeners();
          }
        },
      );
    } catch (e) {
      _isFirebaseConnected = false;
      notifyListeners();
    }
  }

  void _onNewFallDetected(FallEvent fall) {
    _notificationService.showFallAlertNotification(
      title: "🚨 EMERGENCY: Fall Detected!",
      body: "Severity: ${fall.severity} | Post-fall: ${fall.still ? 'Still (Unresponsive)' : 'Movement detected'}",
      payload: fall.id,
    );
  }

  // Simulation Trigger: simulate a fall event directly from the app or testing
  void simulateFallEvent({
    required String severity,
    required bool still,
    String location = 'Hallway',
  }) {
    final event = FallEvent(
      id: 'sim_${DateTime.now().millisecondsSinceEpoch}',
      deviceId: _deviceId,
      timestamp: DateTime.now(),
      severity: severity,
      still: still,
      battery: _deviceStatus.battery,
      location: location,
    );

    _fallHistory.insert(0, event);
    _onNewFallDetected(event);
    notifyListeners();
  }

  // Simulation Trigger: change wearable device state
  void simulateDeviceState({required String status, required int battery}) {
    _deviceStatus = DeviceStatus(
      deviceId: _deviceId,
      status: status,
      battery: battery,
      lastSeen: DateTime.now(),
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _fallsSubscription?.cancel();
    _deviceSubscription?.cancel();
    super.dispose();
  }
}
