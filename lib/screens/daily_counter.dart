import 'package:shared_preferences/shared_preferences.dart';

class DailyCounter {
  static const String _counterKey = "dailyTokenCounter";
  static const String _dateKey = "lastResetDate";

  // Get counter (resets if new day)
  static Future<int> getCounter() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0]; // YYYY-MM-DD
    final lastReset = prefs.getString(_dateKey) ?? today;

    if (lastReset != today) {
      // New day → reset counter
      await prefs.setInt(_counterKey, 0);
      await prefs.setString(_dateKey, today);
      return 0;
    }

    return prefs.getInt(_counterKey) ?? 0;
  }

  // Increment counter
  static Future<int> increment() async {
    final prefs = await SharedPreferences.getInstance();
    int counter = await getCounter();
    counter++;
    await prefs.setInt(_counterKey, counter);
    return counter;
  }
}
