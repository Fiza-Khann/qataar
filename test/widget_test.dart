// Initial widget_test.dart restored at the start of the task  

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qataar/main.dart';

void main() {
  testWidgets('Firebase connection screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());

    expect(find.text('Firebase is connected 🎉'), findsOneWidget);
  });
}
