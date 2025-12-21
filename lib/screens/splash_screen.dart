import 'dart:async';
import 'package:flutter/material.dart';
import 'login_screen.dart'; // Make sure the path is correct

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C30A3),
      body: Center(
        child: SizedBox(
          width: 150,
          height: 150,
          child: Image.asset('assets/logo.png'), // Replace with your splash image path
        ),
      ),
    );
  }
}
