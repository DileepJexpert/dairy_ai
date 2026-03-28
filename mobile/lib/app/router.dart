import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dairy_ai/core/constants.dart';
import 'package:dairy_ai/features/auth/models/auth_state.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import 'package:dairy_ai/features/auth/screens/login_screen.dart';
import 'package:dairy_ai/features/auth/screens/otp_screen.dart';
import 'package:dairy_ai/features/home/screens/farmer_shell.dart';
import 'package:dairy_ai/features/home/screens/vet_shell.dart';
import 'package:dairy_ai/features/home/screens/admin_shell.dart';
import 'package:dairy_ai/features/collection/screens/collection_centers_screen.dart';
import 'package:dairy_ai/features/collection/screens/create_center_screen.dart';
import 'package:dairy_ai/features/collection/screens/center_dashboard_screen.dart';
import 'package:dairy_ai/features/collection/screens/record_milk_screen.dart';
import 'package:dairy_ai/features/collection/screens/cold_chain_screen.dart';
import 'package:dairy_ai/features/vendor/screens/vendor_shell.dart';
import 'package:dairy_ai/features/vendor/screens/vendor_dashboard_screen.dart';
import 'package:dairy_ai/features/vendor/screens/vendor_registration_screen.dart';
import 'package:dairy_ai/features/vendor/screens/vendor_profile_screen.dart';
import 'package:dairy_ai/features/cooperative/screens/cooperative_shell.dart';
import 'package:dairy_ai/features/cooperative/screens/cooperative_dashboard_screen.dart';
import 'package:dairy_ai/features/cooperative/screens/cooperative_registration_screen.dart';
import 'package:dairy_ai/features/cooperative/screens/cooperative_profile_screen.dart';

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

      // Not logged in and not on auth page → go to login.
      if (!isAuthenticated && !isAuthRoute) {
        return '/login';
      }

      // Logged in and still on auth page → redirect to role home.
      if (isAuthenticated && isAuthRoute) {
        return _homeForRole(authState);
      }

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
          StatefulShellBranch(
            navigatorKey: _farmerShellKey,
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) =>
                    const _PlaceholderScreen(title: 'Home'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/herd',
                builder: (context, state) =>
                    const _PlaceholderScreen(title: 'My Herd'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/health',
                builder: (context, state) =>
                    const _PlaceholderScreen(title: 'Health'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/finance',
                builder: (context, state) =>
                    const _PlaceholderScreen(title: 'Finance'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (context, state) =>
                    const _PlaceholderScreen(title: 'More'),
                routes: [
                  GoRoute(
                    path: 'milk',
                    builder: (context, state) =>
                        const _PlaceholderScreen(title: 'Milk Records'),
                  ),
                  GoRoute(
                    path: 'feed',
                    builder: (context, state) =>
                        const _PlaceholderScreen(title: 'Feed Plans'),
                  ),
                  GoRoute(
                    path: 'breeding',
                    builder: (context, state) =>
                        const _PlaceholderScreen(title: 'Breeding'),
                  ),
                  GoRoute(
                    path: 'vet',
                    builder: (context, state) =>
                        const _PlaceholderScreen(title: 'Vet Consult'),
                  ),
                  GoRoute(
                    path: 'chat',
                    builder: (context, state) =>
                        const _PlaceholderScreen(title: 'AI Chat'),
                  ),
                  GoRoute(
                    path: 'profile',
                    builder: (context, state) =>
                        const _PlaceholderScreen(title: 'Profile'),
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
                builder: (context, state) =>
                    const _PlaceholderScreen(title: 'Vet Dashboard'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/vet-consultations',
                builder: (context, state) =>
                    const _PlaceholderScreen(title: 'Consultations'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/vet-profile',
                builder: (context, state) =>
                    const _PlaceholderScreen(title: 'Vet Profile'),
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
                builder: (context, state) =>
                    const _PlaceholderScreen(title: 'Admin Dashboard'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin-farmers',
                builder: (context, state) =>
                    const _PlaceholderScreen(title: 'Manage Farmers'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin-vets',
                builder: (context, state) =>
                    const _PlaceholderScreen(title: 'Manage Vets'),
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
                builder: (context, state) =>
                    const VendorDashboardScreen(),
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
                builder: (context, state) =>
                    const VendorProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // Vendor registration (no shell)
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
                builder: (context, state) =>
                    const CooperativeDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/coop-collection',
                builder: (context, state) =>
                    const _PlaceholderScreen(title: 'Collection'),
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
                builder: (context, state) =>
                    const CooperativeProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // Cooperative registration (no shell)
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

/// Determine the landing route based on user role.
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
// Placeholder screen — used until feature screens are built
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
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Coming soon',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
