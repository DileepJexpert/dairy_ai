import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dairy_ai/app/theme.dart';

/// Bottom navigation shell for vet role.
class VetShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const VetShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: DairyTheme.primaryGreen,
        unselectedItemColor: DairyTheme.subtleGrey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.video_call_outlined),
            activeIcon: Icon(Icons.video_call),
            label: 'Consults',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
