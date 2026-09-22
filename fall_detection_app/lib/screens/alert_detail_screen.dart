import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/fall_event.dart';
import '../services/fall_detection_provider.dart';

class AlertDetailScreen extends StatelessWidget {
  final FallEvent fallEvent;

  const AlertDetailScreen({super.key, required this.fallEvent});

  Future<void> _makeCall(BuildContext context, String phone) async {
    final Uri callUri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(callUri)) {
      await launchUrl(callUri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot initiate phone call to $phone')),
        );
      }
    }
  }

  Future<void> _sendSms(BuildContext context, String phone) async {
    final Uri smsUri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: {
        'body': 'Emergency Check: [${fallEvent.triage} Alert] Activity: ${fallEvent.activity}. Fall detected at ${DateFormat('hh:mm a').format(fallEvent.timestamp)}. Are you okay?'
      },
    );
    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot send SMS to $phone')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FallDetectionProvider>();
    final phone = provider.caregiverPhone;
    final timeFormat = DateFormat('hh:mm:ss a');
    final dateFormat = DateFormat('EEEE, dd MMMM yyyy');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Clinical Incident Breakdown', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Prominent Triage Banner Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: fallEvent.triageColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: fallEvent.triageColor, width: 2),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    backgroundColor: fallEvent.triageColor,
                    radius: 30,
                    child: Icon(fallEvent.triageIcon, color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${fallEvent.triage} PRIORITY TRIAGE',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: fallEvent.triageColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fallEvent.still
                        ? 'CRITICAL ALERT: Senior is unmoving post-impact'
                        : 'NOTICE: Subject regained motion post-impact',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: fallEvent.still ? Colors.red.shade900 : Colors.green.shade900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // TinyML Clinical Risk & Physics Grid
            const Text(
              'TinyML Signal Physics & Risk Analysis',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _detailRow(
                    icon: Icons.directions_walk_rounded,
                    title: 'Pre-Impact Activity',
                    value: fallEvent.activity,
                    valueColor: const Color(0xFF0F172A),
                  ),
                  const Divider(height: 1),
                  _detailRow(
                    icon: Icons.height_rounded,
                    title: 'Fall Height Estimation (h)',
                    value: '${fallEvent.fallHeightM.toStringAsFixed(2)} meters',
                  ),
                  const Divider(height: 1),
                  _detailRow(
                    icon: Icons.speed_rounded,
                    title: 'Peak Impact Acceleration',
                    value: '${fallEvent.peakG.toStringAsFixed(2)} g',
                    valueColor: fallEvent.peakG > 3.0 ? Colors.red : Colors.blueGrey.shade800,
                  ),
                  const Divider(height: 1),
                  _detailRow(
                    icon: Icons.medical_services_outlined,
                    title: 'Fracture Risk Analysis (FRA)',
                    value: fallEvent.fraLevel,
                    valueColor: fallEvent.fraLevel == 'Severe' || fallEvent.fraLevel == 'High'
                        ? Colors.red
                        : Colors.green.shade800,
                  ),
                  const Divider(height: 1),
                  _detailRow(
                    icon: Icons.analytics_outlined,
                    title: 'Composite Severity Score (CFSS-7)',
                    value: '${fallEvent.cfss7.toStringAsFixed(1)} / 100',
                  ),
                  if (fallEvent.sleepStatus != null) ...[
                    const Divider(height: 1),
                    _detailRow(
                      icon: Icons.bedtime_outlined,
                      title: 'Sleep/Syncope Diagnosis',
                      value: fallEvent.sleepStatus!,
                      valueColor: Colors.red.shade800,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Incident Metrics Grid
            const Text(
              'Incident Details',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _detailRow(
                    icon: Icons.access_time_filled,
                    title: 'Time of Incident',
                    value: timeFormat.format(fallEvent.timestamp),
                  ),
                  const Divider(height: 1),
                  _detailRow(
                    icon: Icons.calendar_today,
                    title: 'Date',
                    value: dateFormat.format(fallEvent.timestamp),
                  ),
                  const Divider(height: 1),
                  _detailRow(
                    icon: Icons.place,
                    title: 'Location Area',
                    value: fallEvent.location,
                  ),
                  const Divider(height: 1),
                  _detailRow(
                    icon: Icons.directions_walk,
                    title: 'Post-Fall Status',
                    value: fallEvent.still ? 'Still (Unresponsive)' : 'Recovered / Moving',
                    valueColor: fallEvent.still ? Colors.red : Colors.green,
                  ),
                  const Divider(height: 1),
                  _detailRow(
                    icon: Icons.battery_charging_full,
                    title: 'Wearable Battery',
                    value: '${fallEvent.battery}%',
                  ),
                  const Divider(height: 1),
                  _detailRow(
                    icon: Icons.memory,
                    title: 'Device ID',
                    value: fallEvent.deviceId,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons (Call Elderly & Send SMS)
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                      ),
                      icon: const Icon(Icons.call, size: 22),
                      label: const Text(
                        'Call Elderly Person',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _makeCall(context, phone),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    height: 54,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF1E293B), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Icon(Icons.sms_outlined, color: Color(0xFF1E293B)),
                      onPressed: () => _sendSms(context, phone),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Caregiver Guidelines
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.amber.shade900),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Clinical Triage Protocol',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          fallEvent.triage == 'CRITICAL'
                              ? '1. Call the senior immediately.\n2. If no response within 60s, dispatch ambulance / emergency team due to high impact (${fallEvent.peakG}g) and unresponsiveness.\n3. Suspected syncope requires immediate vital signs evaluation.'
                              : fallEvent.triage == 'HIGH'
                                  ? '1. High impact from ${fallEvent.activity} (${fallEvent.peakG}g). Verify for fractures (${fallEvent.fraLevel} Risk).\n2. Confirm subject is seated safely.'
                                  : '1. Near-fall stumble detected. Check for tripping hazards or sudden weakness.',
                          style: TextStyle(fontSize: 12, color: Colors.amber.shade900, height: 1.4),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow({
    required IconData icon,
    required String title,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blueGrey),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: valueColor ?? const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
