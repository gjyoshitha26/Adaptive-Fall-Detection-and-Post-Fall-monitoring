import 'package:flutter/material.dart';

class FallEvent {
  final String id;
  final String deviceId;
  final DateTime timestamp;
  final String type;
  final String severity; // "Severe", "Moderate", "Mild"
  final bool still;      // true: still / unmoving, false: movement / recovered
  final int battery;
  final String location;

  FallEvent({
    required this.id,
    required this.deviceId,
    required this.timestamp,
    this.type = 'Fall',
    required this.severity,
    required this.still,
    required this.battery,
    this.location = 'Home',
  });

  bool get isRecovered => !still;

  Color get severityColor {
    switch (severity.toLowerCase()) {
      case 'severe':
        return Colors.redAccent.shade700;
      case 'moderate':
        return Colors.orange.shade800;
      case 'mild':
        return Colors.amber.shade700;
      default:
        return Colors.blueGrey;
    }
  }

  IconData get severityIcon {
    switch (severity.toLowerCase()) {
      case 'severe':
        return Icons.warning_amber_rounded;
      case 'moderate':
        return Icons.report_problem_outlined;
      case 'mild':
        return Icons.info_outline;
      default:
        return Icons.help_outline;
    }
  }

  factory FallEvent.fromMap(Map<String, dynamic> map, [String? id]) {
    DateTime parsedTime;
    if (map['timestamp'] is String) {
      parsedTime = DateTime.tryParse(map['timestamp']) ?? DateTime.now();
    } else if (map['timestamp'] != null && map['timestamp'].runtimeType.toString().contains('Timestamp')) {
      // Firebase Timestamp handling
      parsedTime = (map['timestamp'] as dynamic).toDate();
    } else {
      parsedTime = DateTime.now();
    }

    return FallEvent(
      id: id ?? map['id'] ?? UniqueKey().toString(),
      deviceId: map['deviceId'] ?? 'ESP32_001',
      timestamp: parsedTime,
      type: map['type'] ?? 'Fall',
      severity: map['severity'] ?? 'Moderate',
      still: map['still'] ?? true,
      battery: (map['battery'] as num?)?.toInt() ?? 100,
      location: map['location'] ?? 'Home',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'timestamp': timestamp.toIso8601String(),
      'type': type,
      'severity': severity,
      'still': still,
      'battery': battery,
      'location': location,
    };
  }
}
