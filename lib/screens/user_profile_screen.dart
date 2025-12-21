import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({Key? key}) : super(key: key);

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoadingData = true;
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        String firstName = '';
        String lastName = '';
        String email = user.email ?? '';

        if (userDoc.exists) {
          email = userDoc['email'] ?? user.email ?? '';

          // Always split the 'name' field into first and last name
          String fullName = userDoc['name'] ?? user.displayName ?? '';
          if (fullName.isNotEmpty) {
            List<String> nameParts = fullName.split(' ');
            firstName = nameParts.isNotEmpty ? nameParts[0] : '';
            lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
          }
        } else {
          // If no document, use displayName if available
          String fullName = user.displayName ?? '';
          if (fullName.isNotEmpty) {
            List<String> nameParts = fullName.split(' ');
            firstName = nameParts.isNotEmpty ? nameParts[0] : '';
            lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
          }
        }

        setState(() {
          _firstNameController.text = firstName;
          _lastNameController.text = lastName;
          _emailController.text = email;
          _isLoadingData = false;
        });
      } else {
        setState(() {
          _isLoadingData = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoadingData = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile data: $e')),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String fullName = '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'.trim();
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'firstname': _firstNameController.text.trim(),
          'lastname': _lastNameController.text.trim(),
          'name': fullName,
          'email': _emailController.text.trim(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'User Profile',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1C30A3),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _firstNameController,
                      style: GoogleFonts.poppins(color: Colors.black),
                      decoration: InputDecoration(
                        labelText: 'First Name',
                        labelStyle: GoogleFonts.poppins(color: Colors.grey),
                        border: const OutlineInputBorder(),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF1C30A3)),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your first name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _lastNameController,
                      style: GoogleFonts.poppins(color: Colors.black),
                      decoration: InputDecoration(
                        labelText: 'Last Name',
                        labelStyle: GoogleFonts.poppins(color: Colors.grey),
                        border: const OutlineInputBorder(),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF1C30A3)),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your last name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      style: GoogleFonts.poppins(color: Colors.black),
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: GoogleFonts.poppins(color: Colors.grey),
                        border: const OutlineInputBorder(),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF1C30A3)),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1C30A3),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text('Save', style: GoogleFonts.poppins()),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
