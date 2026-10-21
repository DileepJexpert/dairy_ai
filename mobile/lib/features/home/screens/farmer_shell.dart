import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dairy_ai/shared/widgets/farmer_responsive.dart';

/// Responsive navigation shell for farmer role.
/// - Mobile (< 640px): Standard bottom navigation bar with 48px+ thumb targets.
/// - Tablet (640px - 1024px): Compact left navigation rail (72px).
/// - Desktop / Big Monitor (>= 1024px): Extended full sidebar (220px) with icons & labels.
class FarmerShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const FarmerShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < FarmerBreakpoints.mobileMax;
    final isDesktop = width >= 1024;

    if (!isMobile) {
      // Tablet & Desktop view: Left Navigation Rail / Extended Sidebar
      return Scaffold(
        backgroundColor: const Color(0xfff8fafc),
        body: Row(
          children: [
            NavigationRail(
              extended: isDesktop,
              minExtendedWidth: 220,
              backgroundColor: Colors.white,
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: (index) => navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              ),
              labelType: isDesktop
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              leading: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: 18,
                  horizontal: isDesktop ? 16 : 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xff064e3b),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x22064e3b),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.pets,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    if (isDesktop) ...[
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Milterra Dairy',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xff064e3b),
                            ),
                          ),
                          Text(
                            'Farmer Portal',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xff64748b),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              selectedIconTheme:
                  const IconThemeData(color: Color(0xff064e3b)),
              unselectedIconTheme:
                  const IconThemeData(color: Color(0xff64748b)),
              selectedLabelTextStyle: const TextStyle(
                color: Color(0xff064e3b),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              unselectedLabelTextStyle: const TextStyle(
                color: Color(0xff64748b),
                fontSize: 12,
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
                  label: Text('More Features'),
                ),
              ],
            ),
            const VerticalDivider(
                thickness: 1, width: 1, color: Color(0xffe2e8f0)),
            // Main content area fills remaining screen without narrow box restriction
            Expanded(
              child: navigationShell,
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
        selectedItemColor: const Color(0xff064e3b),
        unselectedItemColor: const Color(0xff64748b),
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
