import 'dart:convert';
import 'package:http/http.dart' as http;

class RouteService {
  static const String _accessToken =
      "pk.eyJ1IjoiZml6YWtoYW5uIiwiYSI6ImNtaG02bzFyaTIwMTAyanFxNHlpdW1jNHYifQ.NFvJ6OYabjb5l9tf_oRnnA";

  /// Fetch route duration in seconds between two points
  static Future<int?> getRouteDuration(double startLng, double startLat, double endLng, double endLat) async {
    final url =
        "https://api.mapbox.com/directions/v5/mapbox/driving/$startLng,$startLat;$endLng,$endLat?geometries=geojson&overview=full&annotations=congestion,duration&access_token=$_accessToken";

    try {
      final response = await http.get(Uri.parse(url));
      final data = jsonDecode(response.body);

      if (data["routes"] == null || data["routes"].isEmpty) {
        print("No routes returned by Mapbox API");
        return null;
      }

      final route = data["routes"][0];
      // Use traffic-aware duration if available, otherwise fall back to standard duration
      final duration = (route["duration_in_traffic"] ?? route["duration"]) as double; // in seconds
      return duration.toInt();
    } catch (e) {
      print("Failed to fetch route duration: $e");
      return null;
    }
  }
}
