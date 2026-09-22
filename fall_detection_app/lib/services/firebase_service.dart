import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/fall_event.dart';
import '../models/device_status.dart';

class FirebaseService {
  // Lazily and safely access Firestore only when Firebase is initialized
  FirebaseFirestore? get _firestore {
    if (Firebase.apps.isEmpty) return null;
    return FirebaseFirestore.instance;
  }

  // Stream of fall history ordered by latest first
  Stream<List<FallEvent>> getFallsStream({String? deviceId}) {
    final firestore = _firestore;
    if (firestore == null) {
      return const Stream.empty();
    }

    Query query = firestore.collection('falls').orderBy('timestamp', descending: true);
    
    if (deviceId != null && deviceId.isNotEmpty) {
      query = query.where('deviceId', isEqualTo: deviceId);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return FallEvent.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  // Stream of device status (Online/Offline, Battery, Last Seen)
  Stream<DeviceStatus?> getDeviceStatusStream(String deviceId) {
    final firestore = _firestore;
    if (firestore == null) {
      return const Stream.empty();
    }

    return firestore.collection('devices').doc(deviceId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return DeviceStatus.fromMap(snapshot.data() as Map<String, dynamic>);
    });
  }

  // Record a new fall event (called by backend or test trigger)
  Future<void> recordFallEvent(FallEvent event) async {
    final firestore = _firestore;
    if (firestore == null) return;

    try {
      await firestore.collection('falls').add(event.toMap());
    } catch (e) {
      if (kDebugMode) {
        print("Error saving fall event: $e");
      }
      rethrow;
    }
  }

  // Update wearable device heartbeat
  Future<void> updateDeviceStatus(DeviceStatus status) async {
    final firestore = _firestore;
    if (firestore == null) return;

    try {
      await firestore.collection('devices').doc(status.deviceId).set(
            status.toMap(),
            SetOptions(merge: true),
          );
    } catch (e) {
      if (kDebugMode) {
        print("Error updating device status: $e");
      }
      rethrow;
    }
  }
}
