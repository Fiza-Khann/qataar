import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_screen.dart';
import 'user_profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  User? currentUser = FirebaseAuth.instance.currentUser;
  String firestoreName = 'User';

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    if (currentUser != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();

      if (userDoc.exists) {
        String name = userDoc['name'] ?? 'User';
        setState(() {
          firestoreName = _toTitleCase(name);
        });
      }
    }
  }

  String _toTitleCase(String text) {
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

  void _showChangePasswordDialog() {
    final TextEditingController currentPasswordController = TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Password', style: GoogleFonts.poppins()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current Password'),
            ),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password'),
            ),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm New Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newPasswordController.text == confirmPasswordController.text) {
                try {
                  // Reauthenticate user
                  AuthCredential credential = EmailAuthProvider.credential(
                    email: currentUser!.email!,
                    password: currentPasswordController.text,
                  );
                  await currentUser!.reauthenticateWithCredential(credential);
                  // Now update password
                  await currentUser!.updatePassword(newPasswordController.text);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password changed successfully')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match')),
                );
              }
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  void _showFAQs() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('FAQs', style: GoogleFonts.poppins()),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Q: How do I book a service?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              const Text('A: Select a branch and choose your service from the list.'),
              const SizedBox(height: 10),
              Text('Q: How can I view my token?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              const Text('A: Go to the home screen and click on "View My Token".'),
              const SizedBox(height: 10),
              Text('Q: How to change my profile?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              const Text('A: Go to Settings > User Profile.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header with name initial
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
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
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 30,
                    child: Text(
                      _getInitials(firestoreName),
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    firestoreName,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Options list
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ListTile(
                    leading: const Icon(Icons.person, color: Color(0xFF1C30A3)),
                    title: Text('User Profile', style: GoogleFonts.poppins()),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const UserProfileScreen()),
                      );
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.lock, color: Color(0xFF1C30A3)),
                    title: Text('Change Password', style: GoogleFonts.poppins()),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: _showChangePasswordDialog,
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.help, color: Color(0xFF1C30A3)),
                    title: Text('FAQs', style: GoogleFonts.poppins()),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: _showFAQs,
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Color(0xFF1C30A3)),
                    title: Text('Logout', style: GoogleFonts.poppins()),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: _logout,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }
}
