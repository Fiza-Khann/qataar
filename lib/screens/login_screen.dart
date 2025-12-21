import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'signup_screen.dart';
import 'home_screen.dart';
import 'admin_home_page.dart';
import 'daily_counter.dart'; // <-- import daily counter helper

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  Future<void> loginUser() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      await _navigateBasedOnRole(userCredential.user!.uid);
    } on FirebaseAuthException catch (e) {
      Navigator.of(context).pop();
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Login Failed"),
          content: Text("Invalid email or password. Please try again."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        Navigator.of(context).pop();
        return; // user canceled
      }

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (!userDoc.exists) {
        String displayName = userCredential.user!.displayName ?? '';
        List<String> nameParts = displayName.split(' ');
        String firstName = nameParts.isNotEmpty ? nameParts[0] : '';
        String lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
          'email': userCredential.user!.email,
          'name': userCredential.user!.displayName,
          'firstname': firstName,
          'lastname': lastName,
          'role': 'user',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await _navigateBasedOnRole(userCredential.user!.uid);
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Google Sign-In failed: $e")),
      );
    }
  }

  Future<void> _navigateBasedOnRole(String uid) async {
    DocumentSnapshot userDoc =
    await FirebaseFirestore.instance.collection('users').doc(uid).get();

    final userData = userDoc.data() as Map<String, dynamic>?;

    // --- Reset daily counter on login ---
    await DailyCounter.getCounter();

    Navigator.of(context).pop();
    if (userData == null || !userData.containsKey('role')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User role not defined. Contact admin.")),
      );
      return;
    }

    String role = userData['role'];
    if (role == 'admin') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AdminHomePage()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Image.asset("assets/logo_blue.png", height: 65),
                  const SizedBox(height: 40),
                  Text(
                    "Login to your Account",
                    style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 30),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.black,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Email',
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade400),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.black,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Password',
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade400),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: loginUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1C30A3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text("Login",
                          style: GoogleFonts.poppins(
                              fontSize: 15,
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "- or sign in with Google -",
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      icon: Image.asset("assets/google.png", height: 20),
                      label: Text(
                        "Sign in with Google",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: signInWithGoogle,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Don't have an account?",
                          style: GoogleFonts.poppins(fontSize: 13)),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const SignUpScreen()),
                          );
                        },
                        child: Text(
                          "Sign Up",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
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
        ),
      ),
    );
  }
}
