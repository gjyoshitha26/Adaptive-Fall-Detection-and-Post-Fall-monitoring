import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'services/notification_service.dart';
import 'services/fall_detection_provider.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Local Notifications
  final notificationService = NotificationService();
  await notificationService.initialize();

  // Try to initialize Firebase safely (if google-services.json is present)
  try {
    await Firebase.initializeApp();
    await notificationService.setupFirebaseMessaging();
    if (kDebugMode) {
      print("Firebase initialized successfully.");
    }
  } catch (e) {
    if (kDebugMode) {
      print("Firebase initialization warning (running in standalone/demo mode): $e");
    }
  }

  runApp(const FallDetectionApp());
}

class FallDetectionApp extends StatelessWidget {
  const FallDetectionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<FallDetectionProvider>(
      create: (_) => FallDetectionProvider(),
      child: MaterialApp(
        title: 'FallSafe Caregiver',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1E293B),
            primary: const Color(0xFF1E293B),
            secondary: const Color(0xFFEF4444),
            surface: const Color(0xFFF8FAFC),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1E293B),
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: false,
          ),
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
