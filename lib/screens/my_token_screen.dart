import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'branch_map_screen.dart';
import '../services/route_service.dart';
import '../services/notification_service.dart';

class MyTokenScreen extends StatefulWidget {
  const MyTokenScreen({Key? key}) : super(key: key);

  @override
  State<MyTokenScreen> createState() => _MyTokenScreenState();
}

class _MyTokenScreenState extends State<MyTokenScreen>
    with SingleTickerProviderStateMixin {
  int? _lastAppliedDuration;
  final todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  late AnimationController _animController;
  Duration _remaining = Duration.zero;
  int? _routeTimeSeconds;
  bool _notificationSent = false;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
    } catch (e) {
      print("Failed to get current location: $e");
    }
  }

  Future<void> _fetchRouteTime(double branchLat, double branchLng) async {
    // Get current location if not already fetched
    if (_currentPosition == null) {
      await _getCurrentLocation();
    }

    if (_currentPosition != null) {
      // Fetch route duration with traffic data
      _routeTimeSeconds = await RouteService.getRouteDuration(
        _currentPosition!.longitude,
        _currentPosition!.latitude,
        branchLng,
        branchLat,
      );
      print("Fetched route time: $_routeTimeSeconds seconds");
    }
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final hours = two(d.inHours);
    final minutes = two(d.inMinutes.remainder(60));
    final seconds = two(d.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1C30A3), Color(0xFF3F51B5)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: Text(
                  "My Token",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 18, // reduced
                  ),
                ),
                centerTitle: true,
                iconTheme: const IconThemeData(color: Colors.white),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('tokens')
                      .doc(todayDate)
                      .collection('bookings')
                      .where('userId', isEqualTo: uid)
                      .orderBy('bookingTime', descending: true)
                      .limit(1)
                      .snapshots(),
                  builder: (context, tokenSnap) {
                    if (!tokenSnap.hasData || tokenSnap.data!.docs.isEmpty) {
                      return Center(
                        child: Text(
                          "You haven't booked a token yet.",
                          style: GoogleFonts.poppins(
                              fontSize: 14, color: Colors.white70), // reduced
                        ),
                      );
                    }

                    final tokenDoc = tokenSnap.data!.docs.first;
                    final token = tokenDoc.data() as Map<String, dynamic>;
                    final tokenStatus = token['status'] ?? 'booked';
                    final yourToken = (token['tokenNumber'] ?? 0) as int;
                    final categoryId = token['categoryId'] as String;
                    final branchId = token['branchId'] as String;

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('tokens')
                          .doc(todayDate)
                          .collection('bookings')
                          .where('branchId', isEqualTo: branchId)
                          .where('status', isEqualTo: 'serving')
                          .orderBy('tokenNumber', descending: true)
                          .limit(1)
                          .snapshots(),
                      builder: (context, currentSnap) {
                        int currentTokenNumber = 0;
                        if (currentSnap.hasData &&
                            currentSnap.data!.docs.isNotEmpty) {
                          currentTokenNumber =
                          currentSnap.data!.docs.first['tokenNumber'];
                        }

                        final tokensBeforeYou =
                        math.max(0, yourToken - currentTokenNumber - 1);

                        final serviceRef = FirebaseFirestore.instance
                            .collection('categories')
                            .doc(categoryId)
                            .collection('branches')
                            .doc(branchId)
                            .collection('services')
                            .doc(token['serviceId']);

                        return StreamBuilder<DocumentSnapshot>(
                          stream: serviceRef.snapshots(),
                          builder: (context, serviceSnap) {
                            if (!serviceSnap.hasData || !serviceSnap.data!.exists) {
                              return Center(
                                child: Text(
                                  "Service info not found. Please try again.",
                                  style: GoogleFonts.poppins(
                                      fontSize: 14, color: Colors.white70), // reduced
                                ),
                              );
                            }

                            final serviceData =
                            serviceSnap.data!.data() as Map<String, dynamic>;

                            final recentDurations =
                            (serviceData['recentDurations'] as List<dynamic>?)
                                ?.map((e) => e as int)
                                .toList();

                            final avgServiceTimeSec =
                            (recentDurations != null && recentDurations.isNotEmpty)
                                ? (recentDurations.reduce((a, b) => a + b ~/
                                recentDurations.length))
                                : 300;

                            int remainingCurrent = 0;
                            if (currentSnap.hasData &&
                                currentSnap.data!.docs.isNotEmpty) {
                              final currentStartTime = (currentSnap.data!.docs.first[
                              'bookingTime'] as Timestamp)
                                  .toDate();
                              final elapsed =
                                  DateTime.now().difference(currentStartTime).inSeconds;
                              remainingCurrent =
                                  math.max(0, avgServiceTimeSec - elapsed);
                            }

                            final estimatedSecondsNow =
                                remainingCurrent + tokensBeforeYou * avgServiceTimeSec;

                            if (_lastAppliedDuration != estimatedSecondsNow) {
                              _lastAppliedDuration = estimatedSecondsNow;
                              _remaining = Duration(seconds: estimatedSecondsNow);
                              _animController.duration =
                                  Duration(seconds: estimatedSecondsNow);
                              _animController.forward(from: 0.0);
                            }

                            // Check for notification when remaining queue time is less than or equal to route time
                            if (_routeTimeSeconds != null &&
                                estimatedSecondsNow <= _routeTimeSeconds! &&
                                !_notificationSent) {
                              print("🚨 TRAFFIC NOTIFICATION TRIGGERED: estimatedSecondsNow=$estimatedSecondsNow, routeTimeSeconds=$_routeTimeSeconds");
                              NotificationService.showTravelTimeNotification();
                              _notificationSent = true;
                            }

                            // Debug prints to understand timing
                            if (_routeTimeSeconds != null) {
                              print("⏰ Queue time: $estimatedSecondsNow seconds, Route time: $_routeTimeSeconds seconds");
                            }

                            return Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    tokenStatus == 'serving'
                                        ? "It's your turn!"
                                        : tokenStatus == 'served'
                                        ? "You haven't booked a token yet."
                                        : "You will be called shortly",
                                    style: GoogleFonts.poppins(
                                      fontSize: 18, // reduced
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  if (tokenStatus != 'served') ...[
                                    if (tokensBeforeYou > 0)
                                      SizedBox(
                                        width: 220, // slightly smaller
                                        height: 220,
                                        child: AnimatedBuilder(
                                          animation: _animController,
                                          builder: (context, _) {
                                            final remainingTime = Duration(
                                                seconds: remainingCurrent +
                                                    tokensBeforeYou * avgServiceTimeSec -
                                                    (_animController.value *
                                                        (remainingCurrent +
                                                            tokensBeforeYou *
                                                                avgServiceTimeSec))
                                                        .toInt());
                                            return Container(
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                BorderRadius.circular(16),
                                                boxShadow: const [
                                                  BoxShadow(
                                                    color: Colors.black26,
                                                    blurRadius: 8,
                                                    offset: Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                              padding: const EdgeInsets.all(16),
                                              child: CustomPaint(
                                                painter: CircularRingPainter(
                                                  progress: _animController.value,
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    _formatDuration(remainingTime),
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 28, // reduced
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    const SizedBox(height: 20),
                                    _tokenCard(
                                        "Current Token", "$currentTokenNumber"),
                                    _tokenCard("Your Token", "$yourToken",
                                        isHighlight: true),
                                    _tokenCard(
                                        "Tokens Before You", "$tokensBeforeYou"),
                                    const SizedBox(height: 16),
                                    StreamBuilder<DocumentSnapshot>(
                                      stream: FirebaseFirestore.instance
                                          .collection('categories')
                                          .doc(categoryId)
                                          .collection('branches')
                                          .doc(branchId)
                                          .snapshots(),
                                      builder: (context, branchSnap) {
                                        if (!branchSnap.hasData || !branchSnap.data!.exists) {
                                          return const SizedBox.shrink();
                                        }

                                        final branchData = branchSnap.data!.data() as Map<String, dynamic>;

                                        // Fetch route time automatically when branch data is available
                                        final geoPoint = branchData['location'];
                                        if (geoPoint != null && _routeTimeSeconds == null) {
                                          final double branchLat = geoPoint.latitude;
                                          final double branchLng = geoPoint.longitude;
                                          _fetchRouteTime(branchLat, branchLng);
                                        }

                                        return ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor: Colors.blueAccent,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 20, vertical: 10),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                BorderRadius.circular(12)),
                                          ),
                                          onPressed: () async {
                                            final geoPoint = branchData['location'];
                                            if (geoPoint != null) {
                                              final double branchLat = geoPoint.latitude;
                                              final double branchLng = geoPoint.longitude;

                                              // Get current location if not already fetched
                                              if (_currentPosition == null) {
                                                await _getCurrentLocation();
                                              }

                                              if (_currentPosition != null) {
                                                // Fetch route duration
                                                _routeTimeSeconds = await RouteService.getRouteDuration(
                                                  _currentPosition!.longitude,
                                                  _currentPosition!.latitude,
                                                  branchLng,
                                                  branchLat,
                                                );
                                              }

                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => BranchMapScreen(
                                                    latitude: branchLat,
                                                    longitude: branchLng,
                                                  ),
                                                ),
                                              );
                                            } else {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                    content: Text(
                                                        "Branch location not available")),
                                              );
                                            }
                                          },
                                          icon: const Icon(Icons.map, size: 20),
                                          label: const Text("View Map",
                                              style: TextStyle(fontSize: 14)),
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tokenCard(String label, String value, {bool isHighlight = false}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: isHighlight ? Colors.orangeAccent : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 14, color: isHighlight ? Colors.white : Colors.black87)), // reduced
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 16, // reduced
                  fontWeight: FontWeight.bold,
                  color: isHighlight ? Colors.white : Colors.black87)),
        ],
      ),
    );
  }
}

class CircularRingPainter extends CustomPainter {
  final double progress;
  CircularRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 10;

    final outerArcPaint = Paint()
      ..color = Colors.cyan.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius + 6),
      -math.pi / 2,
      math.pi * 2,
      false,
      outerArcPaint,
    );

    final gradient = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: -math.pi / 2 + math.pi * 2,
      colors: [const Color(0xFF00FFCC), const Color(0xFF0066FF)],
    );

    final ringPaint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * (1 - progress),
      false,
      ringPaint,
    );

    final tickPaint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final majorTickPaint = Paint()
      ..color = Colors.grey[400]!
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final tickRadius = radius - 4;

    for (int i = 0; i < 60; i++) {
      final angle = (i * 6) * math.pi / 180;
      final isMajor = i % 5 == 0;
      final length = isMajor ? 12.0 : 6.0;
      final paint = isMajor ? majorTickPaint : tickPaint;

      final startX =
          center.dx + (tickRadius - length) * math.cos(angle - math.pi / 2);
      final startY =
          center.dy + (tickRadius - length) * math.sin(angle - math.pi / 2);
      final endX = center.dx + tickRadius * math.cos(angle - math.pi / 2);
      final endY = center.dy + tickRadius * math.sin(angle - math.pi / 2);

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
    }

    final markerAngle = -math.pi / 2 + (math.pi * 2 * (1 - progress));
    const markerSize = 8.0;
    final markerCenter = Offset(
      center.dx + (radius + 4) * math.cos(markerAngle),
      center.dy + (radius + 4) * math.sin(markerAngle),
    );

    final path = Path()
      ..moveTo(markerCenter.dx, markerCenter.dy)
      ..lineTo(markerCenter.dx - markerSize, markerCenter.dy + markerSize / 2)
      ..lineTo(markerCenter.dx - markerSize, markerCenter.dy - markerSize / 2)
      ..close();

    final markerPaint = Paint()..color = Colors.red;
    canvas.drawPath(path, markerPaint);
  }

  @override
  bool shouldRepaint(covariant CircularRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
