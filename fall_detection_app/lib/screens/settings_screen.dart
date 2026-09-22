import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/fall_detection_provider.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _phoneController;
  late TextEditingController _deviceController;
  bool _soundEnabled = true;

  @override
  void initState() {
    super.initState();
    final provider = context.read<FallDetectionProvider>();
    _phoneController = TextEditingController(text: provider.caregiverPhone);
    _deviceController = TextEditingController(text: provider.deviceId);
    _soundEnabled = provider.soundEnabled;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _deviceController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    context.read<FallDetectionProvider>().updateSettings(
          phone: _phoneController.text.trim(),
          devId: _deviceController.text.trim(),
          sound: _soundEnabled,
        );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Caregiver settings saved successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FallDetectionProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('App & System Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Emergency Contacts & Device Pairing',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Elderly Contact Phone Number',
                      hintText: '+91 9876543210',
                      prefixIcon: Icon(Icons.phone),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _deviceController,
                    decoration: const InputDecoration(
                      labelText: 'Paired ESP32 Wearable Device ID',
                      hintText: 'ESP32_001',
                      prefixIcon: Icon(Icons.developer_board),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.save),
                      label: const Text('Save Device & Contact Settings'),
                      onPressed: _saveSettings,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Alerts & Notifications',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('High-Priority Sound Alert'),
                    subtitle: const Text('Play sound and vibrate on fall detection'),
                    value: _soundEnabled,
                    activeThumbColor: Colors.redAccent,
                    onChanged: (val) {
                      setState(() {
                        _soundEnabled = val;
                      });
                      _saveSettings();
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.notifications_active, color: Colors.blueAccent),
                    title: const Text('Test Local Push Notification'),
                    subtitle: const Text('Verify that alerts trigger on your screen'),
                    trailing: const Icon(Icons.send),
                    onTap: () {
                      NotificationService().showFallAlertNotification(
                        title: '⚠️ Test Fall Alert',
                        body: 'This is a test notification verifying your caregiver alert settings.',
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Test notification dispatched! Check your status bar.')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Operation Mode',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Demo / Simulation Mode'),
                    subtitle: Text(
                      provider.useSimulationMode
                          ? 'Active: Ready for presentation/demo testing without live Firebase.'
                          : 'Disabled: Listening to live Firebase Firestore & FCM streams.',
                    ),
                    value: provider.useSimulationMode,
                    activeThumbColor: Colors.deepPurple,
                    onChanged: (val) {
                      provider.toggleSimulationMode(val);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
