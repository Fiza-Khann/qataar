import 'package:http/http.dart' as http;
import 'dart:convert';

/// Sends booking data to backend for notification only.
/// Backend will send FCM notification without saving to Firestore.
Future<void> sendBookingNotification({
  required String userId,
  required String branchId,
  required String branchName,
  required String serviceId,
  required String serviceName,
  required String categoryId,
  required String categoryName,
  required String city,
  required String fcmToken,
  required int tokenNumber,
}) async {
  final url = Uri.parse('http://192.168.18.7:3000/sendNotification');

  try {
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'branchId': branchId,
        'branchName': branchName,
        'serviceId': serviceId,
        'serviceName': serviceName,
        'categoryId': categoryId,
        'categoryName': categoryName,
        'city': city,
        'fcmToken': fcmToken,
        'tokenNumber': tokenNumber,
      }),
    );

    if (response.statusCode == 200) {
      print('Notification sent successfully: ${response.body}');
    } else {
      print('Failed to send notification: ${response.statusCode}, ${response.body}');
    }
  } catch (e) {
    print('Error sending notification: $e');
  }
}
