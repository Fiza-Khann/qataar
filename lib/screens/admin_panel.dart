import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminPanel extends StatelessWidget {
  final String categoryId;
  final String branchId;
  final String serviceId;

  const AdminPanel({
    super.key,
    required this.categoryId,
    required this.branchId,
    required this.serviceId,
  });

  String _toggleCase(String s) {
    String result = '';
    for (int i = 0; i < s.length; i++) {
      result += i % 2 == 0 ? s[i].toUpperCase() : s[i].toLowerCase();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final bookingsRef = FirebaseFirestore.instance
        .collection("tokens")
        .doc(today)
        .collection("bookings");

    final serviceRef = FirebaseFirestore.instance
        .collection("categories")
        .doc(categoryId)
        .collection("branches")
        .doc(branchId)
        .collection("services")
        .doc(serviceId);

    final categoryRef = FirebaseFirestore.instance
        .collection("categories")
        .doc(categoryId);

    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<List<DocumentSnapshot>>(
        future: Future.wait([serviceRef.get(), categoryRef.get()]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: Colors.deepPurple,
                strokeWidth: 2,
              ),
            );
          }

          final serviceSnap = snapshot.data![0];
          final categorySnap = snapshot.data![1];

          String serviceName = "Service";
          if (serviceSnap.exists) {
            final data = serviceSnap.data() as Map<String, dynamic>;
            serviceName = data['name'] ?? "Service";
          }

          String categoryName = "Category";
          if (categorySnap.exists) {
            final data = categorySnap.data() as Map<String, dynamic>;
            categoryName = data['name'] ?? "Category";
          }

          final displayName = serviceName.isNotEmpty ? serviceName[0].toUpperCase() + serviceName.substring(1).toLowerCase() : serviceName;

          return Column(
            children: [
              // Gradient Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1C30A3), Color(0xFF3A4ED1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: SafeArea(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Icon(Icons.admin_panel_settings,
                          color: Colors.white, size: 28),
                      Expanded(
                        child: Text(
                          displayName,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.white, size: 20),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: bookingsRef
                      .where("categoryId", isEqualTo: categoryId)
                      .where("branchId", isEqualTo: branchId)
                      .where("serviceId", isEqualTo: serviceId)
                      .orderBy("tokenNumber")
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: Colors.deepPurple, strokeWidth: 2));
                    }

                    final tokens = snapshot.data!.docs;

                    if (tokens.isEmpty) {
                      return const Center(
                        child: Text(
                          "No bookings yet",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      );
                    }

                    final serving =
                    tokens.where((doc) => doc['status'] == 'serving').toList();
                    final waiting =
                    tokens.where((doc) => doc['status'] == 'booked').toList();
                    final served =
                    tokens.where((doc) => doc['status'] == 'served').toList();

                    return Column(
                      children: [
                        // Current Serving
                        Container(
                          margin: const EdgeInsets.all(12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C30A3),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              Text(
                                serving.isNotEmpty
                                    ? "Now Serving"
                                    : "No one is being served",
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                serving.isNotEmpty
                                    ? "${serving.first['tokenNumber']}"
                                    : "-",
                                style: GoogleFonts.poppins(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: () async {
                                  final serviceSnap = await serviceRef.get();
                                  final serviceData = serviceSnap.data() ?? {};
                                  final recentDurations =
                                      (serviceData['recentDurations'] as List<dynamic>?)
                                          ?.map((e) => e as int)
                                          .toList() ??
                                          [];

                                  if (serving.isNotEmpty) {
                                    final currentDoc = serving.first;
                                    final currentStart =
                                    currentDoc['startTime'] != null
                                        ? (currentDoc['startTime'] as Timestamp)
                                        .toDate()
                                        : DateTime.now();
                                    final endTime = DateTime.now();
                                    final duration =
                                        endTime.difference(currentStart).inSeconds;

                                    await bookingsRef.doc(currentDoc.id).update({
                                      'status': 'served',
                                      'endTime': FieldValue.serverTimestamp(),
                                    });

                                    await serviceRef.update({
                                      'recentDurations': FieldValue.arrayUnion([duration]),
                                    });

                                    // Calculate avgServiceTimeSec
                                    final updatedServiceSnap = await serviceRef.get();
                                    final updatedServiceData = updatedServiceSnap.data() ?? {};
                                    final updatedRecentDurations = (updatedServiceData['recentDurations'] as List<dynamic>?)?.map((e) => e as int).toList() ?? [];
                                    if (updatedRecentDurations.isNotEmpty) {
                                      final avg = updatedRecentDurations.reduce((a, b) => a + b) / updatedRecentDurations.length;
                                      await serviceRef.update({
                                        'avgServiceTimeSec': avg.round(),
                                      });
                                    }
                                  }

                                  if (waiting.isNotEmpty) {
                                    final nextDoc = waiting.first;
                                    await bookingsRef.doc(nextDoc.id).update({
                                      'status': 'serving',
                                      'startTime': FieldValue.serverTimestamp(),
                                    });

                                    await serviceRef.update({
                                      'currentToken': nextDoc['tokenNumber'],
                                      'currentTokenStartTime':
                                      FieldValue.serverTimestamp(),
                                    });
                                  } else {
                                    await serviceRef.update({
                                      'currentToken': 0,
                                      'currentTokenStartTime': null,
                                    });
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurpleAccent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                ),
                                child: Text(
                                  serving.isNotEmpty
                                      ? "Next Token"
                                      : "Start First Token",
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),

                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.all(8),
                            children: [
                              Text(
                                "Waiting List",
                                style: GoogleFonts.poppins(
                                    fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              ...waiting.map((doc) {
                                final token = doc.data() as Map<String, dynamic>;
                                return Card(
                                  color: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  margin: const EdgeInsets.only(bottom: 6),
                                  child: ListTile(
                                    leading:
                                    const Icon(Icons.timer, color: Colors.black, size: 16),
                                    title: Text(
                                      "Token ${token['tokenNumber']}",
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                        color: Colors.black,
                                      ),
                                    ),
                                    subtitle: Text(
                                      "Status: ${token['status']}",
                                      style: const TextStyle(
                                          color: Colors.black87, fontSize: 10),
                                    ),
                                  ),
                                );
                              }),

                              const SizedBox(height: 12),

                              ExpansionTile(
                                backgroundColor: Colors.grey.shade200,
                                title: Text(
                                  "Served History",
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                                children: served.isEmpty
                                    ? [
                                  const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: Text(
                                      "No served tokens yet",
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  )
                                ]
                                    : served.map((doc) {
                                  final token = doc.data() as Map<String, dynamic>;
                                  return ListTile(
                                    leading: const Icon(Icons.check_circle,
                                        color: Colors.green, size: 16),
                                    title: Text(
                                      "Token ${token['tokenNumber']}",
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    subtitle: const Text(
                                      "Status: served",
                                      style: TextStyle(fontSize: 10),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
