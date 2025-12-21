import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  print("🔄 Background message received: ${message.notification?.title}");
  print("📄 Background message data: ${message.data}");

  // Initialize flutter_local_notifications in background isolate
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/kouf');

  const InitializationSettings initializationSettings =
  InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Create notification channel
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'qataar_channel', // Must match manifest
    'Qataar Notifications',
    description: 'Notifications for Qataar App',
    importance: Importance.max,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await _showNotification(
    title: message.notification?.title ?? message.data['title'] ?? 'Qataar',
    body: message.notification?.body ?? message.data['body'] ?? '',
  );
}

Future<void> initializeNotifications() async {
  // 1️⃣ Create Android notification channel
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'qataar_channel', // Must match manifest
    'Qataar Notifications',
    description: 'Notifications for Qataar App',
    importance: Importance.max,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // 2️⃣ Initialize local notifications
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/kouf');

  const InitializationSettings initializationSettings =
  InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (details) {
      print('Notification tapped: ${details.payload}');
    },
  );

  // 3️⃣ Request notification permissions
  NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  print('Notification permission: ${settings.authorizationStatus}');

  // 4️⃣ Foreground message handler
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    print("💬 Foreground message received: ${message.notification?.title}");
    print("📄 Message data: ${message.data}");
    print("🔍 Full message: $message");

    // Check if it's a notification message or data message
    if (message.notification != null) {
      print("🔔 Notification message received");
      await _showNotification(
        title: message.notification!.title ?? 'Qataar',
        body: message.notification!.body ?? '',
      );
    } else if (message.data.isNotEmpty) {
      print("📦 Data message received");
      await _showNotification(
        title: message.data['title'] ?? 'Qataar',
        body: message.data['body'] ?? '',
      );
    }
  });

  // 5️⃣ Notification tapped when app is background/terminated
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print("🔔 Notification clicked: ${message.notification?.title}");
  });

  // 6️⃣ Print FCM token
  String? token = await FirebaseMessaging.instance.getToken();
  print("⭐ FCM Token: $token");
}

/// Show local notification
Future<void> _showNotification({
  required String title,
  required String body,
}) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'qataar_channel',
    'Qataar Notifications',
    channelDescription: 'Notifications for Qataar App',
    importance: Importance.max,
    priority: Priority.high,
    ticker: 'ticker',
  );

  const NotificationDetails platformDetails =
  NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000, // unique ID
    title,
    body,
    platformDetails,
  );
}

class NotificationService {
  /// Show travel time notification
  static Future<void> showTravelTimeNotification() async {
    await _showNotification(
      title: 'Time to Leave!',
      body: 'Your token is up soon. Start heading to the branch now.',
    );
  }
}
