import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          'DEBUG: HomeScreen loaded!',
          style: TextStyle(fontSize: 32, color: Colors.red, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
} 