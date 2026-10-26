import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import 'package:dairy_ai/features/home/providers/home_provider.dart';
import 'package:dairy_ai/shared/widgets/farmer_responsive.dart';

/// Responsive navigation shell for farmer role.
/// - Mobile (< 640px): Standard bottom navigation bar with 48px+ thumb targets.
/// - Tablet (640px - 1024px): Compact left navigation rail (72px).
/// - Desktop / Big Monitor (>= 1024px): Extended full sidebar (220px) with icons & labels.
class FarmerShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const FarmerShell({super.key, required this.navigationShell});

  String _currentBranchPath(int branchIndex) {
    switch (branchIndex) {
      case 1:
        return '/herd';
      case 2:
        return '/health';
      case 3:
        return '/finance';
      case 4:
        return '/more';
      default:
        return '/home';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < FarmerBreakpoints.mobileMax;
    final isDesktop = width >= 1024;

    final authState = ref.watch(authProvider);
    final user = ref.watch(currentUserProvider);
    final isAuthenticated = authState.maybeWhen(
      authenticated: (_) => true,
      orElse: () => false,
    );

    final currentPath = _currentBranchPath(navigationShell.currentIndex);

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
              onDestinationSelected: (index) {
                if (index == 0) {
                  ref.read(dashboardStatsProvider.notifier).refresh();
                }
                navigationShell.goBranch(
                  index,
                  initialLocation: index == navigationShell.currentIndex,
                );
              },
              labelType: isDesktop
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              leading: InkWell(
                onTap: () {
                  ref.read(dashboardStatsProvider.notifier).refresh();
                  navigationShell.goBranch(0);
                },
                borderRadius: BorderRadius.circular(10),
                child: Padding(
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
              ),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _SidebarAccountWidget(
                      isDesktop: isDesktop,
                      isAuthenticated: isAuthenticated,
                      user: user,
                      currentPath: currentPath,
                    ),
                  ),
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
            // Main content area
            Expanded(
              child: Column(
                children: [
                  if (!isAuthenticated)
                    _GuestNoticeBanner(
                      isMobile: false,
                      currentPath: currentPath,
                    ),
                  Expanded(child: navigationShell),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Mobile view: Standard Bottom Navigation Bar for easy thumb access
    return Scaffold(
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (!isAuthenticated)
              _GuestNoticeBanner(
                isMobile: true,
                currentPath: currentPath,
              ),
            Expanded(child: navigationShell),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) {
          if (index == 0) {
            ref.read(dashboardStatsProvider.notifier).refresh();
          }
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
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

/// Global guest notice banner reminding unauthenticated users to sign in.
class _GuestNoticeBanner extends StatelessWidget {
  final bool isMobile;
  final String currentPath;

  const _GuestNoticeBanner({
    required this.isMobile,
    required this.currentPath,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xfffef3c7),
        border: Border(
          bottom: BorderSide(color: Color(0xfffde68a), width: 1),
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 20,
        vertical: 7,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: Color(0xff92400e),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isMobile
                  ? 'अतिथि मोड — पशु, दूध व खाता सुरक्षित करने के लिए लॉगिन करें'
                  : '👋 आप अतिथि मोड (Guest Mode) में हैं — अपने पशु, दूध व खाता सुरक्षित करने के लिए लॉगिन करें।',
              style: const TextStyle(
                color: Color(0xff92400e),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => context.push('/login?next=$currentPath'),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xff92400e),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'लॉगिन / Sign In',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  SizedBox(width: 3),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 9,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Desktop / Tablet NavigationRail bottom account widget.
class _SidebarAccountWidget extends ConsumerWidget {
  final bool isDesktop;
  final bool isAuthenticated;
  final dynamic user;
  final String currentPath;

  const _SidebarAccountWidget({
    required this.isDesktop,
    required this.isAuthenticated,
    required this.user,
    required this.currentPath,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isAuthenticated) {
      if (!isDesktop) {
        return IconButton(
          tooltip: 'लॉगिन / Sign In',
          icon: const Icon(Icons.login, color: Color(0xff064e3b)),
          onPressed: () => context.push('/login?next=$currentPath'),
        );
      }
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xfff1f5f9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: Color(0xff64748b)),
                SizedBox(width: 6),
                Text(
                  'Guest Mode',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff475569),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xff064e3b),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 6),
                minimumSize: const Size(0, 32),
              ),
              onPressed: () => context.push('/login?next=$currentPath'),
              child: const Text(
                'लॉगिन / Sign In',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    final displayName = user?.name?.toString().trim().isNotEmpty == true
        ? user.name.toString().trim()
        : (user?.phone?.toString().isNotEmpty == true
            ? user.phone.toString()
            : 'Farmer');
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'F';

    if (!isDesktop) {
      return IconButton(
        tooltip: '$displayName (Sign Out)',
        icon: CircleAvatar(
          radius: 14,
          backgroundColor: const Color(0xff064e3b),
          child: Text(
            initial,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        onPressed: () => _confirmSignOut(context, ref),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xfff1f5f9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xff064e3b),
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff1e293b),
                  ),
                ),
                if (user?.phone != null)
                  Text(
                    user.phone.toString(),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xff64748b),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout, size: 16, color: Color(0xffdc2626)),
            onPressed: () => _confirmSignOut(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('साइन आउट करें? / Sign Out?'),
        content: const Text(
          'क्या आप वाकई इस डिवाइस से लॉग आउट करना चाहते हैं?\n(Are you sure you want to sign out?)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('रद्द करें / Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xffdc2626),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('लॉग आउट / Sign Out'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(authProvider.notifier).logout();
      if (context.mounted) {
        context.go('/home');
      }
    }
  }
}
