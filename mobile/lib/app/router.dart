import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dairy_ai/core/constants.dart';
import 'package:dairy_ai/features/auth/models/auth_state.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';

// Auth
import 'package:dairy_ai/features/auth/screens/login_screen.dart';
import 'package:dairy_ai/features/auth/screens/otp_screen.dart';

// Shells
import 'package:dairy_ai/features/home/screens/farmer_shell.dart';
import 'package:dairy_ai/features/home/screens/vet_shell.dart';
import 'package:dairy_ai/features/home/screens/admin_shell.dart';
import 'package:dairy_ai/features/vendor/screens/vendor_shell.dart';
import 'package:dairy_ai/features/cooperative/screens/cooperative_shell.dart';

// Farmer screens
import 'package:dairy_ai/features/home/screens/farmer_home_screen.dart';
import 'package:dairy_ai/features/herd/screens/herd_list_screen.dart';
import 'package:dairy_ai/features/herd/screens/cattle_detail_screen.dart';
import 'package:dairy_ai/features/herd/screens/add_cattle_screen.dart';
import 'package:dairy_ai/features/health/screens/health_dashboard_screen.dart';
import 'package:dairy_ai/features/health/screens/health_record_screen.dart';
import 'package:dairy_ai/features/health/screens/sensor_live_screen.dart';
import 'package:dairy_ai/features/health/screens/vaccination_screen.dart';
import 'package:dairy_ai/features/health/screens/triage_result_screen.dart';
import 'package:dairy_ai/features/finance/screens/finance_dashboard_screen.dart';
import 'package:dairy_ai/features/finance/screens/add_transaction_screen.dart';
import 'package:dairy_ai/features/milk/screens/milk_record_screen.dart';
import 'package:dairy_ai/features/milk/screens/milk_summary_screen.dart';
import 'package:dairy_ai/features/feed/screens/feed_plan_screen.dart';
import 'package:dairy_ai/features/breeding/screens/breeding_screen.dart';
import 'package:dairy_ai/features/chat/screens/chat_screen.dart';
import 'package:dairy_ai/features/profile/screens/profile_screen.dart';
import 'package:dairy_ai/features/notifications/screens/notifications_screen.dart';

// Vet screens
import 'package:dairy_ai/features/vet_doctor/screens/vet_dashboard_screen.dart';
import 'package:dairy_ai/features/vet_doctor/screens/vet_consultation_screen.dart';
import 'package:dairy_ai/features/vet_farmer/screens/vet_search_screen.dart';
import 'package:dairy_ai/features/vet_farmer/screens/consultation_request_screen.dart';

// Admin screens
import 'package:dairy_ai/features/admin/screens/admin_dashboard_screen.dart';
import 'package:dairy_ai/features/admin/screens/admin_farmers_screen.dart';
import 'package:dairy_ai/features/admin/screens/admin_vets_screen.dart';

// Vendor screens
import 'package:dairy_ai/features/vendor/screens/vendor_dashboard_screen.dart';
import 'package:dairy_ai/features/vendor/screens/vendor_registration_screen.dart';
import 'package:dairy_ai/features/vendor/screens/vendor_profile_screen.dart';

// Cooperative screens
import 'package:dairy_ai/features/cooperative/screens/cooperative_dashboard_screen.dart';
import 'package:dairy_ai/features/cooperative/screens/cooperative_registration_screen.dart';
import 'package:dairy_ai/features/cooperative/screens/cooperative_profile_screen.dart';

// Collection screens
import 'package:dairy_ai/features/collection/screens/collection_centers_screen.dart';
import 'package:dairy_ai/features/collection/screens/create_center_screen.dart';
import 'package:dairy_ai/features/collection/screens/center_dashboard_screen.dart';
import 'package:dairy_ai/features/collection/screens/record_milk_screen.dart';
import 'package:dairy_ai/features/collection/screens/cold_chain_screen.dart';

// ---------------------------------------------------------------------------
// Navigation keys
// ---------------------------------------------------------------------------

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _farmerShellKey = GlobalKey<NavigatorState>();
final _vetShellKey = GlobalKey<NavigatorState>();
final _adminShellKey = GlobalKey<NavigatorState>();
final _vendorShellKey = GlobalKey<NavigatorState>();
final _cooperativeShellKey = GlobalKey<NavigatorState>();

// ---------------------------------------------------------------------------
// Router provider
// ---------------------------------------------------------------------------

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isAuthenticated = authState.maybeWhen(
        authenticated: (_) => true,
        orElse: () => false,
      );

      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/otp-verify';

      if (!isAuthenticated && !isAuthRoute) return '/login';
      if (isAuthenticated && isAuthRoute) return _homeForRole(authState);
      return null;
    },
    routes: [
      // ---- Auth routes (no shell) ----
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/otp-verify',
        builder: (context, state) {
          final phone = state.uri.queryParameters['phone'] ?? '';
          return OtpScreen(phone: phone);
        },
      ),

      // ---- Farmer shell ----
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            FarmerShell(navigationShell: navigationShell),
        branches: [
          // Tab 0: Home
          StatefulShellBranch(
            navigatorKey: _farmerShellKey,
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const FarmerHomeScreen(),
                routes: [
                  GoRoute(
                    path: 'notifications',
                    builder: (context, state) => const NotificationsScreen(),
                  ),
                ],
              ),
            ],
          ),
          // Tab 1: Herd
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/herd',
                builder: (context, state) => const HerdListScreen(),
                routes: [
                  GoRoute(
                    path: 'add',
                    builder: (context, state) => const AddCattleScreen(),
                  ),
                  GoRoute(
                    path: ':cattleId',
                    builder: (context, state) {
                      final id = state.pathParameters['cattleId']!;
                      return CattleDetailScreen(cattleId: id);
                    },
                    routes: [
                      GoRoute(
                        path: 'sensors',
                        builder: (context, state) {
                          final id = state.pathParameters['cattleId']!;
                          final name = state.uri.queryParameters['name'];
                          return SensorLiveScreen(
                            cattleId: id,
                            cattleName: name,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // Tab 2: Health
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/health',
                builder: (context, state) => const HealthDashboardScreen(),
                routes: [
                  GoRoute(
                    path: 'add-record',
                    builder: (context, state) => const HealthRecordScreen(),
                  ),
                  GoRoute(
                    path: 'vaccinations',
                    builder: (context, state) => const VaccinationScreen(),
                  ),
                ],
              ),
            ],
          ),
          // Tab 3: Finance
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/finance',
                builder: (context, state) => const FinanceDashboardScreen(),
                routes: [
                  GoRoute(
                    path: 'add',
                    builder: (context, state) => const AddTransactionScreen(),
                  ),
                ],
              ),
            ],
          ),
          // Tab 4: More
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (context, state) => const _MoreMenuScreen(),
                routes: [
                  GoRoute(
                    path: 'milk',
                    builder: (context, state) => const MilkRecordScreen(),
                  ),
                  GoRoute(
                    path: 'milk-summary',
                    builder: (context, state) => const MilkSummaryScreen(),
                  ),
                  GoRoute(
                    path: 'feed',
                    builder: (context, state) => const FeedPlanScreen(),
                  ),
                  GoRoute(
                    path: 'breeding',
                    builder: (context, state) => const BreedingScreen(),
                  ),
                  GoRoute(
                    path: 'vet',
                    builder: (context, state) => const VetSearchScreen(),
                  ),
                  GoRoute(
                    path: 'chat',
                    builder: (context, state) => const ChatScreen(),
                  ),
                  GoRoute(
                    path: 'profile',
                    builder: (context, state) => const ProfileScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // ---- Vet shell ----
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            VetShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _vetShellKey,
            routes: [
              GoRoute(
                path: '/vet-dashboard',
                builder: (context, state) => const VetDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/vet-consultations',
                builder: (context, state) => const VetConsultationScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/vet-profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // ---- Admin shell ----
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AdminShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _adminShellKey,
            routes: [
              GoRoute(
                path: '/admin-dashboard',
                builder: (context, state) => const AdminDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin-farmers',
                builder: (context, state) => const AdminFarmersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin-vets',
                builder: (context, state) => const AdminVetsScreen(),
              ),
            ],
          ),
        ],
      ),

      // ---- Vendor shell ----
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            VendorShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _vendorShellKey,
            routes: [
              GoRoute(
                path: '/vendor-dashboard',
                builder: (context, state) => const VendorDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/vendor-orders',
                builder: (context, state) =>
                    const _PlaceholderScreen(title: 'Orders'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/vendor-profile',
                builder: (context, state) => const VendorProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      GoRoute(
        path: '/vendor-register',
        builder: (context, state) => const VendorRegistrationScreen(),
      ),

      // ---- Cooperative shell ----
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            CooperativeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _cooperativeShellKey,
            routes: [
              GoRoute(
                path: '/coop-dashboard',
                builder: (context, state) => const CooperativeDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/coop-collection',
                builder: (context, state) => const CollectionCentersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/coop-payments',
                builder: (context, state) =>
                    const _PlaceholderScreen(title: 'Payments'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/coop-profile',
                builder: (context, state) => const CooperativeProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      GoRoute(
        path: '/coop-register',
        builder: (context, state) => const CooperativeRegistrationScreen(),
      ),

      // ---- Collection Center routes ----
      GoRoute(
        path: '/collection/centers',
        builder: (context, state) => const CollectionCentersScreen(),
      ),
      GoRoute(
        path: '/collection/centers/create',
        builder: (context, state) => const CreateCenterScreen(),
      ),
      GoRoute(
        path: '/collection/centers/:centerId',
        builder: (context, state) {
          final centerId = state.pathParameters['centerId']!;
          return CenterDashboardScreen(centerId: centerId);
        },
        routes: [
          GoRoute(
            path: 'record-milk',
            builder: (context, state) {
              final centerId = state.pathParameters['centerId']!;
              return RecordMilkScreen(centerId: centerId);
            },
          ),
          GoRoute(
            path: 'cold-chain',
            builder: (context, state) {
              final centerId = state.pathParameters['centerId']!;
              return ColdChainScreen(centerId: centerId);
            },
          ),
        ],
      ),
    ],
  );
});

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _homeForRole(AuthState state) {
  return state.maybeWhen(
    authenticated: (user) {
      switch (user.role) {
        case AppConstants.roleVet:
          return '/vet-dashboard';
        case AppConstants.roleAdmin:
          return '/admin-dashboard';
        case AppConstants.roleVendor:
          return '/vendor-dashboard';
        case AppConstants.roleCooperative:
          return '/coop-dashboard';
        case AppConstants.roleFarmer:
        default:
          return '/home';
      }
    },
    orElse: () => '/login',
  );
}

// ---------------------------------------------------------------------------
// More menu — list of additional features
// ---------------------------------------------------------------------------

class _MoreMenuScreen extends StatelessWidget {
  const _MoreMenuScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        children: [
          _MoreTile(
            icon: Icons.water_drop,
            label: 'Milk Records',
            onTap: () => context.go('/more/milk'),
          ),
          _MoreTile(
            icon: Icons.bar_chart,
            label: 'Milk Summary',
            onTap: () => context.go('/more/milk-summary'),
          ),
          _MoreTile(
            icon: Icons.grass,
            label: 'Feed Plans',
            onTap: () => context.go('/more/feed'),
          ),
          _MoreTile(
            icon: Icons.favorite,
            label: 'Breeding',
            onTap: () => context.go('/more/breeding'),
          ),
          _MoreTile(
            icon: Icons.local_hospital,
            label: 'Find a Vet',
            onTap: () => context.go('/more/vet'),
          ),
          _MoreTile(
            icon: Icons.smart_toy,
            label: 'AI Chat',
            onTap: () => context.go('/more/chat'),
          ),
          _MoreTile(
            icon: Icons.person,
            label: 'Profile',
            onTap: () => context.go('/more/profile'),
          ),
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MoreTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

// ---------------------------------------------------------------------------
// Placeholder screen — used for features not yet built
// ---------------------------------------------------------------------------

class _PlaceholderScreen extends StatelessWidget {
  final String title;

  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Coming soon', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
