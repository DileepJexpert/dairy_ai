import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dairy_ai/app/theme.dart';
import 'package:dairy_ai/shared/widgets/farmer_responsive.dart';

/// Responsive navigation shell for farmer role.
/// - Mobile (< 640px): Standard bottom navigation bar with 48px+ thumb targets.
/// - Tablet & Desktop (>= 640px): Left navigation rail with dedicated branding and centered layout.
class FarmerShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const FarmerShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final isCompact = FarmerBreakpoints.isMobile(context);

    if (!isCompact) {
      // Tablet & Desktop view: Left Navigation Rail + Centered Content
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: (index) => navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              ),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: DairyTheme.primaryGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.agriculture_rounded,
                          color: DairyTheme.primaryGreen, size: 28),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Milterra\nFarmer',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: DairyTheme.primaryGreen,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              selectedIconTheme:
                  const IconThemeData(color: DairyTheme.primaryGreen),
              selectedLabelTextStyle: const TextStyle(
                color: DairyTheme.primaryGreen,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              unselectedLabelTextStyle: const TextStyle(
                color: DairyTheme.subtleGrey,
                fontSize: 11,
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: Text('Home'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.pets_outlined),
                  selectedIcon: Icon(Icons.pets),
                  label: Text('Herd'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.health_and_safety_outlined),
                  selectedIcon: Icon(Icons.health_and_safety),
                  label: Text('Health'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  selectedIcon: Icon(Icons.account_balance_wallet),
                  label: Text('Finance'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.more_horiz),
                  selectedIcon: Icon(Icons.more_horiz),
                  label: Text('More'),
                ),
              ],
            ),
            const VerticalDivider(
                thickness: 1, width: 1, color: Color(0xffe2e8f0)),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: navigationShell,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Mobile view: Standard Bottom Navigation Bar for easy thumb access
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
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pets_outlined),
            activeIcon: Icon(Icons.pets),
            label: 'Herd',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.health_and_safety_outlined),
            activeIcon: Icon(Icons.health_and_safety),
            label: 'Health',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: 'Finance',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz),
            activeIcon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      ),
    );
  }
}
