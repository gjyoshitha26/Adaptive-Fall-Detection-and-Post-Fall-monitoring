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

  // TinyML Pipeline Clinical Triage & Signal Physics Metrics
  final String triage;       // "CRITICAL", "HIGH", "WATCH", "QUIET"
  final String activity;     // "WALK", "RUN", "SIT", "STAND", "SLEEP", "STAIRS"
  final double fallHeightM;  // Fall height estimation in meters (h = 0.5 * g * t_ff^2)
  final double peakG;        // Peak impact acceleration in g
  final String fraLevel;     // Fracture Risk Analysis ("Severe", "High", "Moderate", "Low")
  final double cfss7;        // Composite Fall Severity Score (0 - 100)
  final String? sleepStatus; // Sleep vs Syncope/Collapse disambiguation

  FallEvent({
    required this.id,
    required this.deviceId,
    required this.timestamp,
    this.type = 'Fall',
    required this.severity,
    required this.still,
    required this.battery,
    this.location = 'Home',
    this.triage = 'HIGH',
    this.activity = 'WALK',
    this.fallHeightM = 0.82,
    this.peakG = 3.2,
    this.fraLevel = 'Moderate',
    this.cfss7 = 64.0,
    this.sleepStatus,
  });

  bool get isRecovered => !still;
  bool get isCritical => triage.toUpperCase() == 'CRITICAL';

  Color get triageColor {
    switch (triage.toUpperCase()) {
      case 'CRITICAL':
        return const Color(0xFFDC2626); // Red 600
      case 'HIGH':
        return const Color(0xFFEA580C); // Orange 600
      case 'WATCH':
        return const Color(0xFFD97706); // Amber 600
      case 'QUIET':
      default:
        return const Color(0xFF16A34A); // Green 600
    }
  }

  IconData get triageIcon {
    switch (triage.toUpperCase()) {
      case 'CRITICAL':
        return Icons.emergency_rounded;
      case 'HIGH':
        return Icons.warning_amber_rounded;
      case 'WATCH':
        return Icons.visibility_outlined;
      case 'QUIET':
      default:
        return Icons.check_circle_outline;
    }
  }

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
      parsedTime = (map['timestamp'] as dynamic).toDate();
    } else {
      parsedTime = DateTime.now();
    }

    // Default triage mapping based on severity if not explicitly provided
    String detectedTriage = map['triage'] ?? '';
    if (detectedTriage.isEmpty) {
      final s = (map['severity'] ?? 'Moderate').toString().toLowerCase();
      final isStill = map['still'] ?? true;
      if (s == 'severe' || isStill) {
        detectedTriage = 'CRITICAL';
      } else if (s == 'moderate') {
        detectedTriage = 'HIGH';
      } else {
        detectedTriage = 'WATCH';
      }
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
      triage: detectedTriage,
      activity: map['activity'] ?? 'WALK',
      fallHeightM: (map['fallHeightM'] ?? map['fall_height_m'] as num?)?.toDouble() ?? 0.85,
      peakG: (map['peakG'] ?? map['peak_g'] as num?)?.toDouble() ?? 3.4,
      fraLevel: map['fraLevel'] ?? map['fra_level'] ?? 'Moderate',
      cfss7: (map['cfss7'] as num?)?.toDouble() ?? 62.0,
      sleepStatus: map['sleepStatus'] ?? map['sleep_status'],
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
      'triage': triage,
      'activity': activity,
      'fall_height_m': fallHeightM,
      'peak_g': peakG,
      'fra_level': fraLevel,
      'cfss7': cfss7,
      if (sleepStatus != null) 'sleep_status': sleepStatus,
    };
  }
}
