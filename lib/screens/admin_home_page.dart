import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_panel.dart';
import 'login_screen.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final CollectionReference categoriesRef =
  FirebaseFirestore.instance.collection("categories");

  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> allItems = [];
  String firestoreName = "Admin";

  String _toggleCase(String s) {
    String result = '';
    for (int i = 0; i < s.length; i++) {
      result += i % 2 == 0 ? s[i].toUpperCase() : s[i].toLowerCase();
    }
    return result;
  }

  @override
  void initState() {
    super.initState();
    _loadAllItems();
    _loadAdminNameIfAny();
  }

  // Load admin name
  Future<void> _loadAdminNameIfAny() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null && data['name'] != null) {
            setState(() {
              firestoreName = data['name'];
            });
          }
        }
      }
    } catch (_) {}
  }

  // Load all branches, services for autocomplete
  Future<void> _loadAllItems() async {
    try {
      final branchSnapshot = await FirebaseFirestore.instance.collectionGroup('branches').get();
      final List<Map<String, dynamic>> items = [];

      for (var branchDoc in branchSnapshot.docs) {
        final branchData = branchDoc.data() as Map<String, dynamic>;
        final categoryId = branchDoc.reference.parent.parent!.id;
        final serviceSnapshot = await branchDoc.reference.collection('services').get();

        for (var serviceDoc in serviceSnapshot.docs) {
          final serviceData = serviceDoc.data() as Map<String, dynamic>;

          items.add({
            'id': serviceDoc.id,
            'name': serviceData['name'] ?? "Unnamed Service",
            'categoryId': categoryId,
            'branchId': branchDoc.id,
            'branchName': branchData['name'] ?? "Branch",
          });
        }
      }

      setState(() => allItems = items);
    } catch (e) {
      print("Error loading items: $e");
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    String first = parts.isNotEmpty && parts[0].isNotEmpty ? parts[0][0] : '';
    String second = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
    return (first + second).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    // Use UTC to match backend token docs
    final now = DateTime.now().toUtc();
    final today = "${now.year.toString().padLeft(4,'0')}-"
        "${now.month.toString().padLeft(2,'0')}-"
        "${now.day.toString().padLeft(2,'0')}";

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const SizedBox(height: 30),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1C30A3),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Image.asset('assets/logo.png', height: 40),
                    PopupMenuButton(
                      offset: const Offset(0, 40),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      onSelected: (value) async {
                        if (value == 'logout') {
                          await FirebaseAuth.instance.signOut();
                          if (context.mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                  builder: (context) => const LoginScreen()),
                                  (Route<dynamic> route) => false,
                            );
                          }
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'logout',
                          child: Text('Logout'),
                        ),
                      ],
                      child: CircleAvatar(
                        backgroundColor: Colors.white,
                        radius: 16,
                        child: Text(
                          _getInitials(firestoreName),
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                // Autocomplete search
                Autocomplete<Map<String, dynamic>>(
                  optionsBuilder: (textEditingValue) {
                    final text = textEditingValue.text.trim();
                    if (text.isEmpty) return const Iterable.empty();
                    final lower = text.toLowerCase();
                    return allItems.where((item) {
                      final name = (item['name'] ?? '').toString().toLowerCase();
                      final branch = (item['branchName'] ?? '').toString().toLowerCase();
                      return name.contains(lower) ||
                          branch.contains(lower);
                    }).take(10);
                  },
                  displayStringForOption: (option) =>
                  '${option['branchName']} > ${option['name']}',
                  onSelected: (selection) {
                    if (selection == null) return;
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminPanel(
                            categoryId: selection['categoryId'],
                            branchId: selection['branchId'],
                            serviceId: selection['id'],
                          ),
                        ),
                      );
                    }
                  },
                  fieldViewBuilder:
                      (context, controller, focusNode, onEditingComplete) {
                    _searchController.text = controller.text;
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onEditingComplete: onEditingComplete,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: controller.text.isNotEmpty ? Colors.black : Colors.grey,
                      ),
                      decoration: InputDecoration(
                        hintText: "What are you looking for?",
                        prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 18),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          // Categories and services list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: categoriesRef.snapshots(),
              builder: (context, catSnapshot) {
                if (!catSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final categories = catSnapshot.data!.docs;
                if (categories.isEmpty) {
                  return const Center(child: Text("No categories found"));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: categories.length,
                  itemBuilder: (context, catIndex) {
                    final category = categories[catIndex].data() as Map<String, dynamic>;
                    final categoryId = categories[catIndex].id;

                    return Card(
                      color: const Color(0xFF1C30A3),
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                      child: Theme(
                        data: Theme.of(context)
                            .copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          iconColor: Colors.white,
                          collapsedIconColor: Colors.white,
                          leading: const Icon(Icons.miscellaneous_services,
                              color: Colors.white, size: 18),
                          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          childrenPadding: const EdgeInsets.only(left: 12, right: 12, bottom: 4),
                          title: Text(
                            categoryId.isNotEmpty ? categoryId[0].toUpperCase() + categoryId.substring(1).toLowerCase() : categoryId,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                          children: [
                            StreamBuilder<QuerySnapshot>(
                              stream: categoriesRef
                                  .doc(categoryId)
                                  .collection("branches")
                                  .snapshots(),
                              builder: (context, branchSnapshot) {
                                if (!branchSnapshot.hasData) {
                                  return const Padding(
                                    padding: EdgeInsets.all(4.0),
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  );
                                }

                                final branches = branchSnapshot.data!.docs;
                                if (branches.isEmpty) {
                                  return const Padding(
                                    padding: EdgeInsets.all(4.0),
                                    child: Text("No branches found",
                                        style: TextStyle(color: Colors.white, fontSize: 12)),
                                  );
                                }

                                return Column(
                                  children: branches.map((branchDoc) {
                                    final branch =
                                    branchDoc.data() as Map<String, dynamic>;
                                    final branchId = branchDoc.id;

                                    return Card(
                                      color: const Color.fromARGB(255, 46, 72, 219),
                                      margin: const EdgeInsets.only(bottom: 6),
                                      shape: RoundedRectangleBorder(
                                      
                                          borderRadius: BorderRadius.circular(10)),
                                      elevation: 1,
                                      
                                      child: Theme(
                                        data: Theme.of(context)
                                            .copyWith(dividerColor: Colors.transparent),
                                        child: ExpansionTile(
                                          iconColor: Colors.black,
                                          collapsedIconColor: Colors.black,
                                          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                          childrenPadding: const EdgeInsets.only(left: 12, right: 12, bottom: 4),
                                          title: Text(
                                            branch['name'] ?? "Unnamed Branch",
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w400,
                                              fontSize: 12,
                                              color: Colors.white,
                                            ),
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                branch['address'] ?? "",
                                                style: GoogleFonts.poppins(
                                                    fontSize: 10, color: const Color.fromARGB(255, 211, 210, 210)),
                                              ),
                                              Text(
                                                branch['city'] ?? "",
                                                style: GoogleFonts.poppins(
                                                    fontSize: 10, color: const Color.fromARGB(255, 211, 210, 210).withOpacity(0.7)),
                                              ),
                                            ],
                                          ),
                                          children: [
                                            StreamBuilder<QuerySnapshot>(
                                              stream: categoriesRef
                                                  .doc(categoryId)
                                                  .collection("branches")
                                                  .doc(branchId)
                                                  .collection("services")
                                                  .snapshots(),
                                              builder: (context, serviceSnapshot) {
                                                if (!serviceSnapshot.hasData) {
                                                  return const Padding(
                                                    padding: EdgeInsets.all(4.0),
                                                    child: CircularProgressIndicator(
                                                        color: Colors.white, strokeWidth: 2),
                                                  );
                                                }

                                                final services = serviceSnapshot.data!.docs;
                                                if (services.isEmpty) {
                                                  return const Padding(
                                                    padding: EdgeInsets.all(4.0),
                                                    child: Text("No services found",
                                                        style: TextStyle(color: Colors.white, fontSize: 12)),
                                                  );
                                                }

                                                return Column(
                                                  children: services.map((serviceDoc) {
                                                    final service =
                                                    serviceDoc.data() as Map<String, dynamic>;
                                                    final serviceId = serviceDoc.id;

                                                    // ✅ Correct token stream
                                                    final tokensStream = FirebaseFirestore
                                                        .instance
                                                        .collection('tokens')
                                                        .doc(today)
                                                        .collection('bookings')
                                                        .where('categoryId', isEqualTo: categoryId)
                                                        .where('branchId', isEqualTo: branchId)
                                                        .where('serviceId', isEqualTo: serviceId)
                                                        .snapshots();

                                                    return Card(
                                                      color: const Color(0xFF1C30A3),
                                                      margin: const EdgeInsets.only(bottom: 4),
                                                      shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(8)),
                                                      elevation: 1,
                                                      child: ListTile(
                                                        title: Text(
                                                          service['name'] ?? "Unnamed Service",
                                                          style: GoogleFonts.poppins(
                                                              fontSize: 12,
                                                              color: Colors.white),
                                                        ),
                                                        trailing: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            StreamBuilder<QuerySnapshot>(
                                                              stream: tokensStream,
                                                              builder: (c, tSnap) {
                                                                if (!tSnap.hasData) {
                                                                  return const SizedBox(
                                                                    width: 24,
                                                                    height: 24,
                                                                    child: CircularProgressIndicator(
                                                                        strokeWidth: 2,
                                                                        color: Colors.white),
                                                                  );
                                                                }

                                                                final docs = tSnap.data!.docs;
                                                                final activeCount = docs.where((d) {
                                                                  final s = (d['status'] ?? '');
                                                                  return s == 'booked' || s == 'serving';
                                                                }).length;

                                                                // 🔹 Debug print
                                                                print("Service $serviceId: $activeCount active tokens");

                                                                return Container(
                                                                  padding: const EdgeInsets.symmetric(
                                                                      horizontal: 8, vertical: 4),
                                                                  decoration: BoxDecoration(
                                                                    color: activeCount > 0
                                                                        ? Colors.redAccent
                                                                        : Colors.white24,
                                                                    borderRadius: BorderRadius.circular(10),
                                                                  ),
                                                                  child: Text(
                                                                    activeCount.toString(),
                                                                    style: const TextStyle(
                                                                      color: Colors.white,
                                                                      fontWeight: FontWeight.bold,
                                                                      fontSize: 10,
                                                                    ),
                                                                  ),
                                                                );
                                                              },
                                                            ),
                                                            const SizedBox(width: 6),
                                                            ElevatedButton(
                                                              onPressed: () {
                                                                Navigator.push(
                                                                  context,
                                                                  MaterialPageRoute(
                                                                    builder: (_) => AdminPanel(
                                                                      categoryId: categoryId,
                                                                      branchId: branchId,
                                                                      serviceId: serviceId,
                                                                    ),
                                                                  ),
                                                                );
                                                              },
                                                              style: ElevatedButton.styleFrom(
                                                                backgroundColor: Colors.white,
                                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                                shape: RoundedRectangleBorder(
                                                                  borderRadius: BorderRadius.circular(6),
                                                                ),
                                                              ),
                                                              child: const Text(
                                                                "Manage",
                                                                style: TextStyle(
                                                                    fontSize: 10,
                                                                    color: Colors.black),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    );
                                                  }).toList(),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                          ],
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
