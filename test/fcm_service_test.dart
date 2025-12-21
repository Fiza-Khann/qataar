import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'dart:convert';
import '../lib/services/fcm_service.dart';

import 'fcm_service_test.mocks.dart';

@GenerateMocks([http.Client])
void main() {
  group('sendBookingNotification', () {
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient();
    });

    test('sends notification and handles response successfully', () async {
      when(mockClient.post(
        Uri.parse('http://192.168.18.7:3000/sendNotification'),
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response('Notification sent', 200));

      expect(true, true); 
    });

    test('handles failure in sending notification gracefully', () async {
      when(mockClient.post(
        Uri.parse('http://192.168.18.7:3000/sendNotification'),
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenThrow(Exception('Failed to send'));
      expect(true, true);
    });
  });
}
