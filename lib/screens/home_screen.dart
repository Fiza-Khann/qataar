import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_screen.dart';
import 'service_list_screen.dart';
import 'my_token_screen.dart';
import 'settings_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  User? currentUser = FirebaseAuth.instance.currentUser;
  String firestoreName = 'User';
  List<Map<String, dynamic>> branches = [];
  List<String> categoryIds = [];
  String selectedCategoryId = 'All';
  TextEditingController searchController = TextEditingController();

  final Color navyBlue = const Color(0xFF1C30A3);
  final Color purple = const Color(0xFF6C63FF);
  final Color yellow = const Color(0xFFFFB300);

  @override
  void initState() {
    super.initState();
    _loadUserName();
    loadBranches();

  }

  Future<void> _loadUserName() async {
    if (currentUser != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();

      if (userDoc.exists) {
        setState(() {
          firestoreName = userDoc['name'] ?? 'User';
        });
      }
    }
  }

  Future<void> loadBranches() async {
    try {
      print('Loading branches...');
      QuerySnapshot categoriesSnapshot =
      await FirebaseFirestore.instance.collection('categories').get();
      print('Categories fetched: ${categoriesSnapshot.docs.length}');

      if (categoriesSnapshot.docs.isEmpty) {
        print('No categories found in Firestore');
        setState(() {
          branches = [];
          categoryIds = ['All'];
        });
        return;
      }

      // Debug: Print category names
      for (var categoryDoc in categoriesSnapshot.docs) {
        print('Category found: ${categoryDoc.id}');
      }

      List<Map<String, dynamic>> allBranches = [];
      List<String> loadedCategoryIds = ['All'];

      for (var categoryDoc in categoriesSnapshot.docs) {
        String categoryId = categoryDoc.id;
        loadedCategoryIds.add(categoryId);
        print('Processing category: $categoryId');

        try {
          QuerySnapshot branchesSnapshot = await FirebaseFirestore.instance
              .collection('categories')
              .doc(categoryId)
              .collection('branches')
              .get();
          print('Branches in $categoryId: ${branchesSnapshot.docs.length}');

          for (var branchDoc in branchesSnapshot.docs) {
              try {
                // Use the bracket notation with null safety
                String name = 'Unknown Branch';
                String location = 'Unknown Location';
                String address = 'Unknown Address';

                try {
                  name = branchDoc['name'] ?? 'Unknown Branch';
                } catch (e) {
                  print('Error accessing name for branch ${branchDoc.id}: $e');
                }

                try {
                  location = branchDoc['city'] ?? 'Unknown Location';
                } catch (e) {
                  print('Error accessing city for branch ${branchDoc.id}: $e');
                }

                try {
                  address = branchDoc['address'] ?? 'Unknown Address';
                } catch (e) {
                  print('Error accessing address for branch ${branchDoc.id}: $e');
                }

                allBranches.add({
                  'id': branchDoc.id,
                  'name': name,
                  'location': location,
                  'address': address,
                  'categoryId': categoryId,
                });
            } catch (e) {
              print('Error processing branch ${branchDoc.id}: $e');
              allBranches.add({
                'id': branchDoc.id,
                'name': 'Unknown Branch',
                'location': 'Unknown Location',
                'address': 'Unknown Address',
                'categoryId': categoryId,
              });
            }
          }
        } catch (e) {
          print('Error fetching branches for category $categoryId: $e');
          // Continue with other categories
        }
      }

      print('Total branches loaded: ${allBranches.length}');
      setState(() {
        branches = allBranches;
        categoryIds = loadedCategoryIds;
      });
    } catch (e) {
      print('Error loading branches: $e');
      // Optionally show a snackbar or dialog to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load services. Please try again.')),
      );
    }
  }

  String toTitleCase(String text) {
    return text
        .split(' ')
        .map((str) =>
    str.isNotEmpty ? '${str[0].toUpperCase()}${str.substring(1).toLowerCase()}' : '')
        .join(' ');
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    String first = parts.isNotEmpty ? parts[0][0] : '';
    String second = parts.length > 1 ? parts[1][0] : '';
    return (first + second).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Blue Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1C30A3), Color(0xFF3A4ED1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Image.asset(
                        'assets/logo.png',
                        height: 45,
                      ),
                      PopupMenuButton(
                        offset: const Offset(0, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onSelected: (value) async {
                          if (value == 'settings') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SettingsScreen()),
                            );
                          } else if (value == 'logout') {
                            await FirebaseAuth.instance.signOut();
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (context) => const LoginScreen()),
                                  (Route<dynamic> route) => false,
                            );
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'settings',
                            child: Text('Settings'),
                          ),
                          const PopupMenuItem(
                            value: 'logout',
                            child: Text('Logout'),
                          ),
                        ],
                        child: CircleAvatar(
                          backgroundColor: Colors.white,
                          radius: 18,
                          child: Text(
                            _getInitials(firestoreName),
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Hi, ${toTitleCase(firestoreName)}',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your Time is Our First Priority',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Search Bar
                  Autocomplete<Map<String, dynamic>>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text == '') {
                        return const Iterable<Map<String, dynamic>>.empty();
                      }
                      return branches.where((branch) =>
                      (branch['name'] ?? '')
                          .toLowerCase()
                          .contains(textEditingValue.text.toLowerCase()) ||
                          (branch['location'] ?? '')
                              .toLowerCase()
                              .contains(textEditingValue.text.toLowerCase()));
                    },
                    displayStringForOption: (option) =>
                    '${option['name']} (${option['location']})',
                    onSelected: (Map<String, dynamic> selection) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ServiceListScreen(
                            branchId: selection['id'],
                            categoryId: selection['categoryId'],
                          ),
                        ),
                      ).then((_) => searchController.clear());
                    },
                    fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                      searchController = controller;
                      return StatefulBuilder(
                        builder: (context, setInnerState) {
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            onEditingComplete: onEditingComplete,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: controller.text.isNotEmpty ? Colors.black : Colors.grey,
                            ),
                            onChanged: (text) {
                              setInnerState(() {});
                            },
                            decoration: InputDecoration(
                              hintText: "what are you looking for?",
                              prefixIcon: const Icon(Icons.search, color: Colors.grey),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Text(
                      'Categories',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: navyBlue,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: categoryIds.map((id) {
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedCategoryId = id;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: id == selectedCategoryId
                                    ? yellow
                                    : yellow.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: yellow,
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                id == 'All' ? 'All' : toTitleCase(id),
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.2,
                                  color: Colors.deepPurple,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'All Services',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: navyBlue,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: branches.isEmpty
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.builder(
                        itemCount: branches.length,
                        itemBuilder: (context, index) {
                          final branch = branches[index];
                          if (selectedCategoryId != 'All' &&
                              branch['categoryId'] != selectedCategoryId) {
                            return const SizedBox.shrink();
                          }
                          return Card(
                            color: const Color(0xFF1C30A3),
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: const Icon(Icons.apartment, color: Colors.white),
                              title: Text(
                                branch['name'],
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    branch['address'],
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white60,
                                    ),
                                  ),
                                  Text(
                                    branch['location'],
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white70,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ServiceListScreen(
                                      branchId: branch['id'],
                                      categoryId: branch['categoryId'],
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),

                    // --- Existing "View My Token" Button ---
                    Center(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.confirmation_number),
                        label: const Text(
                          "View My Token",
                          style: TextStyle(fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1C30A3),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => MyTokenScreen()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
