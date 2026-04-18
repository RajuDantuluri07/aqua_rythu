import 'package:flutter/material.dart';
import 'package:aqua_rythu/routes/app_routes.dart';

class AppBottomBar extends StatelessWidget {
  final int currentIndex;

  const AppBottomBar({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) {
        if (index == currentIndex) return;

        switch (index) {
          case 0:
            Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
            break;
          case 1:
            Navigator.pushReplacementNamed(context, AppRoutes.pondDashboard);
            break;
          case 2:
            Navigator.pushReplacementNamed(context, AppRoutes.profile);
            break;
        }
      },
      selectedItemColor: const Color(0xFF16A34A),
      unselectedItemColor: const Color(0xFF94A3B8),
      backgroundColor: Colors.white,
      elevation: 12,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: "HOME"),
        BottomNavigationBarItem(icon: Icon(Icons.water_drop_rounded), label: "TANKS"),
        BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: "PROFILE"),
      ],
    );
  }
}
