import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:qataar/screens/login_screen.dart';
import 'package:qataar/screens/splash_screen.dart';
import 'package:qataar/services/notification_service.dart';

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  // 🔹 Register background handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // 🔹 Initialize local notifications
  await initializeNotifications();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    requestPermission();
    getFCMToken();
  }

  void requestPermission() async {
    NotificationSettings settings =
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print("🔐 Permission status: ${settings.authorizationStatus}");
  }

  void getFCMToken() async {
    String? token = await FirebaseMessaging.instance.getToken();
    print("⭐ FCM Token: $token");

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      print("🔄 Token refreshed: $newToken");
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Qataar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF1C30A3),
      ),
      home: const SplashScreen(),
    );
  }
}
