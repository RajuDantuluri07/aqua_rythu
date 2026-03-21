import 'package:flutter/material.dart';
import 'package:aqua_rythu/widgets/app_bottom_bar.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      bottomNavigationBar: const AppBottomBar(currentIndex: 0),
      body: const Center(
        child: Text(
          "Dashboard Ready",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
