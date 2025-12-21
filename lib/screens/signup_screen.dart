import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final passController = TextEditingController();
  final confirmPassController = TextEditingController();

  void registerUser() async {
    if (passController.text != confirmPassController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Passwords don't match")),
      );
      return;
    }

    try {
      UserCredential userCredential =
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passController.text.trim(),
      );

      String fullName =
          "${firstNameController.text.trim()} ${lastNameController.text.trim()}";

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'name': fullName,
        'email': emailController.text.trim(),
        'role': 'user', // Default role
      });

      await userCredential.user?.updateDisplayName(fullName);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Signup Error: $e")),
      );
    }
  }

  InputDecoration buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              Image.asset("assets/logo_blue.png", height: 75),
              const SizedBox(height: 30),
              Text("Create your Account",
                  style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: firstNameController,
                      decoration: buildInputDecoration("First Name"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: lastNameController,
                      decoration: buildInputDecoration("Last Name"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: buildInputDecoration("Email"),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: passController,
                obscureText: true,
                decoration: buildInputDecoration("Password"),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: confirmPassController,
                obscureText: true,
                decoration: buildInputDecoration("Confirm Password"),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: registerUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1C30A3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    "Sign Up",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Already have an account?",
                      style: GoogleFonts.poppins(fontSize: 14)),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const LoginScreen()),
                      );
                    },
                    child: Text(
                      "Sign In",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: const Color(0xFF1C30A3),
                      ),
                    ),
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
