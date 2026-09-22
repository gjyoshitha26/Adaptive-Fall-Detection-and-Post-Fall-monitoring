import 'package:flutter/material.dart';

class DeviceStatus {
  final String deviceId;
  final String status; // "online", "offline"
  final int battery;
  final DateTime lastSeen;

  DeviceStatus({
    required this.deviceId,
    required this.status,
    required this.battery,
    required this.lastSeen,
  });

  bool get isOnline => status.toLowerCase() == 'online';

  Color get batteryColor {
    if (battery > 50) return Colors.green.shade600;
    if (battery > 20) return Colors.orange.shade700;
    return Colors.red.shade700;
  }

  IconData get batteryIcon {
    if (battery >= 90) return Icons.battery_full_rounded;
    if (battery >= 60) return Icons.battery_5_bar_rounded;
    if (battery >= 30) return Icons.battery_3_bar_rounded;
    if (battery >= 15) return Icons.battery_1_bar_rounded;
    return Icons.battery_alert_rounded;
  }

  factory DeviceStatus.fromMap(Map<String, dynamic> map) {
    DateTime parsedTime;
    if (map['lastSeen'] is String) {
      parsedTime = DateTime.tryParse(map['lastSeen']) ?? DateTime.now();
    } else if (map['lastSeen'] != null && map['lastSeen'].runtimeType.toString().contains('Timestamp')) {
      parsedTime = (map['lastSeen'] as dynamic).toDate();
    } else {
      parsedTime = DateTime.now();
    }

    return DeviceStatus(
      deviceId: map['deviceId'] ?? 'ESP32_001',
      status: map['status'] ?? 'offline',
      battery: (map['battery'] as num?)?.toInt() ?? 0,
      lastSeen: parsedTime,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'status': status,
      'battery': battery,
      'lastSeen': lastSeen.toIso8601String(),
    };
  }
}
