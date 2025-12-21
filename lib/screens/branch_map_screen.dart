import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;

class BranchMapScreen extends StatefulWidget {
  final double latitude;
  final double longitude;

  const BranchMapScreen({
    Key? key,
    required this.latitude,
    required this.longitude,
  }) : super(key: key);

  @override
  State<BranchMapScreen> createState() => _BranchMapScreenState();
}

class _BranchMapScreenState extends State<BranchMapScreen> {
  mapbox.MapboxMap? mapController;
  Position? _currentPosition;
  String? travelTime;

  final String _accessToken =
      "pk.eyJ1IjoiZml6YWtoYW5uIiwiYSI6ImNtaG02bzFyaTIwMTAyanFxNHlpdW1jNHYifQ.NFvJ6OYabjb5l9tf_oRnnA";

  @override
  void initState() {
    super.initState();
    mapbox.MapboxOptions.setAccessToken(_accessToken);
    _determinePosition();
  }

  /// Get user's current location
  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) return;

    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPosition = position;
      });

      if (mapController != null) {
        _addMarkersAndRoute();
      }
    } catch (e) {
      print("Failed to get location: $e");
    }
  }

  /// Adds user & destination markers + route
  Future<void> _addMarkersAndRoute() async {
    if (_currentPosition == null || mapController == null) return;

    final userPoint = mapbox.Point(
      coordinates: mapbox.Position(
          _currentPosition!.longitude, _currentPosition!.latitude),
    );

    final branchPoint = mapbox.Point(
      coordinates: mapbox.Position(widget.longitude, widget.latitude),
    );

    try {
      final annotationMgr =
      await mapController!.annotations.createPointAnnotationManager();

      // Branch marker
      final ByteData branchData =
      await rootBundle.load("assets/branch_marker.png");
      final Uint8List branchBytes = branchData.buffer.asUint8List();

      await annotationMgr.create(mapbox.PointAnnotationOptions(
        geometry: branchPoint,
        image: branchBytes,
        iconSize: 0.2,
      ));

      // User marker
      final ByteData userData =
      await rootBundle.load("assets/user_marker.png");
      final Uint8List userBytes = userData.buffer.asUint8List();

      await annotationMgr.create(mapbox.PointAnnotationOptions(
        geometry: userPoint,
        image: userBytes,
        iconSize: 0.6,
      ));

      // Draw route & fetch travel time
      await _drawRouteAndTime(userPoint, branchPoint);
    } catch (e) {
      print("Failed to add markers or draw route: $e");
    }
  }

  /// Fetch route and draw it on the map
  Future<void> _drawRouteAndTime(
      mapbox.Point user, mapbox.Point branch) async {
    final url =
        "https://api.mapbox.com/directions/v5/mapbox/driving/${user.coordinates.lng},${user.coordinates.lat};${branch.coordinates.lng},${branch.coordinates.lat}?geometries=geojson&overview=full&annotations=congestion,duration&access_token=$_accessToken";

    try {
      final response = await http.get(Uri.parse(url));
      final data = jsonDecode(response.body);

      if (data["routes"] == null || data["routes"].isEmpty) {
        print("No routes returned by Mapbox API");
        return;
      }

      final route = data["routes"][0];
      final geometry = route["geometry"]["coordinates"];
      // Use traffic-aware duration if available, otherwise fall back to standard duration
      final duration = route["duration_in_traffic"] ?? route["duration"]; // in seconds

      setState(() {
        travelTime = (duration / 60).toStringAsFixed(1); // minutes
      });

      final points = geometry
          .map<mapbox.Position>((e) => mapbox.Position(e[0], e[1]))
          .toList();

      final polylineMgr =
      await mapController!.annotations.createPolylineAnnotationManager();

      await polylineMgr.create(mapbox.PolylineAnnotationOptions(
        geometry: mapbox.LineString(coordinates: points),
        lineColor: Colors.blue.value,
        lineWidth: 5.0,
      ));
    } catch (e) {
      print("Failed to fetch route or draw polyline: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C30A3),
        title: Text(
          "Branch Location",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        elevation: 4,
        iconTheme: const IconThemeData(
          color: Colors.white, // This makes the back arrow white
        ),
      ),
      body: Stack(
        children: [
          mapbox.MapWidget(
            styleUri: mapbox.MapboxStyles.MAPBOX_STREETS,
            cameraOptions: mapbox.CameraOptions(
              center: mapbox.Point(
                coordinates: mapbox.Position(
                  widget.longitude,
                  widget.latitude,
                ),
              ),
              zoom: 13.5,
            ),
            onMapCreated: (controller) async {
              mapController = controller;
              if (_currentPosition != null) {
                _addMarkersAndRoute();
              }
            },
          ),

          // Display estimated travel time
          if (travelTime != null)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Container(
                padding:
                const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  "Estimated Travel Time: $travelTime min",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: const Color(0xFF1C30A3),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

          // ✅ My Location Button
          Positioned(
            bottom: 90,
            right: 20,
            child: FloatingActionButton(
              backgroundColor: const Color(0xFF1C30A3),
              child: const Icon(Icons.my_location, color: Colors.white),
              onPressed: () async {
                await _determinePosition();
                if (_currentPosition != null && mapController != null) {
                  await mapController!.setCamera(
                    mapbox.CameraOptions(
                      center: mapbox.Point(
                        coordinates: mapbox.Position(
                          _currentPosition!.longitude,
                          _currentPosition!.latitude,
                        ),
                      ),
                      zoom: 14.0,
                    ),
                  );
                  _addMarkersAndRoute();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
