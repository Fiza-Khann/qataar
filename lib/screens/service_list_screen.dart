import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'my_token_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:qataar/services/fcm_service.dart';

class ServiceListScreen extends StatelessWidget {
  final String categoryId;
  final String branchId;

  const ServiceListScreen({
    Key? key,
    required this.categoryId,
    required this.branchId,
  }) : super(key: key);

  Future<void> _bookToken(
      BuildContext context,
      Map<String, dynamic> serviceData,
      String serviceId,
      ) async {
    final messenger = ScaffoldMessenger.of(context);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text("User not logged in")),
      );
      return;
    }

    try {
      final categoryDoc = await FirebaseFirestore.instance
          .collection('categories')
          .doc(categoryId)
          .get();
      final categoryName = categoryDoc.data()?['name'] ?? 'Unknown';

      final branchRef = FirebaseFirestore.instance
          .collection('categories')
          .doc(categoryId)
          .collection('branches')
          .doc(branchId);

      final serviceRef = FirebaseFirestore.instance
          .collection('categories')
          .doc(categoryId)
          .collection('branches')
          .doc(branchId)
          .collection('services')
          .doc(serviceId);

      final branchDoc = await branchRef.get();
      final branchName = branchDoc.data()?['name'] ?? 'Unknown';
      final city = branchDoc.data()?['city'] ?? 'Unknown';
      final dateStr = DateTime.now().toIso8601String().substring(0, 10);

      final tokenRef = FirebaseFirestore.instance
          .collection('tokens')
          .doc(dateStr)
          .collection('bookings');
      String? fcmToken = await FirebaseMessaging.instance.getToken();

      late int newTokenNumber;

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final serviceSnapshot = await transaction.get(serviceRef);
        int lastCounter = serviceSnapshot.data()?['dailyTokenCounter'] ?? 0;
        newTokenNumber = lastCounter + 1;

        final newTokenDoc = tokenRef.doc();
        transaction.set(newTokenDoc, {
          'userId': user.uid,
          'categoryId': categoryId,
          'branchId': branchId,
          'branchName': branchName,
          'serviceId': serviceId,
          'serviceName': serviceData['name'] ?? 'Unknown',
          'city': city,
          'bookingTime': FieldValue.serverTimestamp(),
          'status': 'booked',
          'tokenNumber': newTokenNumber,
          'Date': dateStr,
          'fcmToken': fcmToken,
          'notified': false,              // Booking Confirmed
          'notifiedApproaching': false,   // Turn Approaching
          'notifiedTurn': false           // Your Turn
        });

        transaction.update(serviceRef, {'dailyTokenCounter': newTokenNumber});
      });

      // 🔥 Call backend to send notification
      await sendBookingNotification(
        userId: user.uid,
        branchId: branchId,
        branchName: branchName,
        serviceId: serviceId,
        serviceName: serviceData['name'] ?? 'Unknown',
        categoryId: categoryId,
        categoryName: categoryName,
        city: city,
        fcmToken: fcmToken!,
        tokenNumber: newTokenNumber,
      );

      messenger.showSnackBar(
        const SnackBar(content: Text("Token booked successfully")),
      );

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MyTokenScreen()),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  void _showBookingConfirmation(
      BuildContext context,
      Map<String, dynamic> data,
      String serviceId,
      ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          "Confirm Booking",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 14, // smaller
          ),
        ),
        content: Text(
          "Do you want to book a token for '${data['name']}'?",
          style: GoogleFonts.poppins(fontSize: 12),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actionsPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min, // <-- shrink column vertically
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _bookToken(context, data, serviceId);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1C30A3),
                    minimumSize: const Size.fromHeight(36),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    "Yes, Book Token",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 4), // smaller gap
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    textStyle: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                  child: const Text("Cancel"),
                ),
              ],
            ),
          ),
        ],

      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final servicesRef = FirebaseFirestore.instance
        .collection('categories')
        .doc(categoryId)
        .collection('branches')
        .doc(branchId)
        .collection('services');

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C30A3),
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Image.asset(
          'assets/logo.png',
          height: 32, // slightly smaller
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "Explore the services below",
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: servicesRef.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text("Something went wrong"));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No services found."));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: snapshot.data!.docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final data = snapshot.data!.docs[index].data()
                    as Map<String, dynamic>;
                    final serviceId = snapshot.data!.docs[index].id;

                    return Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEEF1FF), Color(0xFFDDE3FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFF1C30A3),
                          radius: 18,
                          child: Icon(Icons.assignment, color: Colors.white, size: 16),
                        ),
                        title: Text(
                          data['name'] ?? 'Unnamed Service',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('tokens')
                              .doc(DateTime.now()
                              .toIso8601String()
                              .substring(0, 10))
                              .collection('bookings')
                              .where('categoryId', isEqualTo: categoryId)
                              .where('branchId', isEqualTo: branchId)
                              .where('serviceId', isEqualTo: serviceId)
                              .orderBy('bookingTime')
                              .snapshots(),
                          builder: (context, tokenSnapshot) {
                            if (!tokenSnapshot.hasData) return const Text("Loading...");

                            final tokens = tokenSnapshot.data!.docs;
                            final currentUser = FirebaseAuth.instance.currentUser;
                            QueryDocumentSnapshot? userTokenDoc;

                            try {
                              userTokenDoc = tokens.firstWhere(
                                      (doc) => doc['userId'] == currentUser?.uid);
                            } catch (e) {
                              userTokenDoc = null;
                            }

                            int usersAhead = tokens
                                .where((doc) => doc['status'] == 'booked')
                                .where((doc) => userTokenDoc != null
                                ? doc['tokenNumber'] < userTokenDoc['tokenNumber']
                                : true)
                                .length;

                            final serviceData = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                            final avgServiceTimeSec =
                            (serviceData['avgServiceTimeSec'] ?? 300) as int;

                            final estimatedSeconds = usersAhead * avgServiceTimeSec;

                            return Row(
                              children: [
                                const Icon(Icons.timer,
                                    size: 14, color: Colors.deepPurple),
                                const SizedBox(width: 4),
                                Text(
                                  "~${(estimatedSeconds / 60).ceil()} min",
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        trailing: ElevatedButton(
                          onPressed: () => _showBookingConfirmation(
                              context, data, serviceId),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1C30A3),
                            minimumSize: const Size(70, 32),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(
                            "Book",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
