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
        'body': 'Are you okay? Fall alert received from your wearable device at ${DateFormat('hh:mm a').format(fallEvent.timestamp)}.'
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
        title: const Text('Incident Breakdown', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Prominent Severity Banner Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: fallEvent.severityColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: fallEvent.severityColor, width: 2),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    backgroundColor: fallEvent.severityColor,
                    radius: 30,
                    child: Icon(fallEvent.severityIcon, color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${fallEvent.severity.toUpperCase()} FALL DETECTED',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: fallEvent.severityColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fallEvent.still
                        ? 'CRITICAL: No movement detected post-impact'
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
                          'Recommended Protocol',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          fallEvent.still
                              ? '1. Call the senior immediately.\n2. If no response within 60 seconds, notify local emergency services or neighbor.\n3. Keep calm and dispatch assistance.'
                              : '1. Check in to ensure no dizziness or fracture.\n2. Confirm the senior is comfortable and hydrated.',
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
