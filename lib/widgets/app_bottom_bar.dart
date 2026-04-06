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
            Navigator.pushReplacementNamed(context, AppRoutes.pondDashboard);
            break;
          case 1:
            Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
            break;
          case 2:
            Navigator.pushReplacementNamed(context, AppRoutes.profile);
            break;
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.layers), label: "Ponds"),
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "Overview"),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
      ],
    );
  }
}
