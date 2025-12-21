import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qataar/screens/daily_counter.dart'; 

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DailyCounter', () {
    late DailyCounter counter;

    setUp(() {
      counter = DailyCounter();
      SharedPreferences.setMockInitialValues({});
    });

    test('getCounter returns 0 on first call', () async {
      final value = await DailyCounter.getCounter();
      expect(value, 0);
    });

    test('increment increases counter', () async {
      await DailyCounter.increment();
      final value = await DailyCounter.getCounter();
      expect(value, 1);
    });

    test('counter resets on new day', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1)).toIso8601String().split('T')[0];
      SharedPreferences.setMockInitialValues({
        'dailyTokenCounter': 5,
        'lastResetDate': yesterday,
      });

      final value = await DailyCounter.getCounter();
      expect(value, 0); 
    });

    test('counter persists on same day', () async {
      SharedPreferences.setMockInitialValues({
        'dailyTokenCounter': 3,
        'lastResetDate': DateTime.now().toIso8601String().split('T')[0],
      });

      final value = await DailyCounter.getCounter();
      expect(value, 3);
    });
  });
}
