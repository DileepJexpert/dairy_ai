import 'package:flutter/material.dart';
import 'shopping_navigation.dart';
import '../features/commerce/screens/commerce_categories_screen.dart';
import '../features/commerce/screens/commerce_products_screen.dart';
import '../features/commerce/screens/commerce_orders_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import 'package:dairy_ai/features/finance/screens/finance_dashboard_screen.dart';
import 'package:dairy_ai/features/finance/screens/add_transaction_screen.dart';
import 'package:dairy_ai/features/finance/screens/milterra_wallet_screen.dart';
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

// Admin screens
import 'package:dairy_ai/features/admin/screens/admin_dashboard_screen.dart';
import 'package:dairy_ai/features/admin/screens/admin_farmers_screen.dart';
import 'package:dairy_ai/features/admin/screens/admin_vets_screen.dart';
import 'package:dairy_ai/features/admin/screens/ecommerce_admin_panel_screen.dart';
import 'package:dairy_ai/features/auth/screens/admin_login_screen.dart';
import 'package:dairy_ai/features/auth/screens/seller_login_screen.dart';

// Vendor / Seller screens
import 'package:dairy_ai/features/vendor/screens/vendor_dashboard_screen.dart';
import 'package:dairy_ai/features/vendor/screens/vendor_registration_screen.dart';
import 'package:dairy_ai/features/vendor/screens/vendor_profile_screen.dart';
import 'package:dairy_ai/features/vendor/screens/vendor_orders_screen.dart';
import 'package:dairy_ai/features/vendor/screens/vendor_products_screen.dart';
import 'package:dairy_ai/features/vendor/screens/seller_onboarding_screen.dart';
import 'package:dairy_ai/features/vendor/screens/seller_portal_screen.dart';

// Cooperative screens
import 'package:dairy_ai/features/cooperative/screens/cooperative_dashboard_screen.dart';
import 'package:dairy_ai/features/cooperative/screens/cooperative_registration_screen.dart';
import 'package:dairy_ai/features/cooperative/screens/cooperative_profile_screen.dart';
import 'package:dairy_ai/features/cooperative/screens/milk_intake_screen.dart';

// Collection screens
import 'package:dairy_ai/features/collection/screens/collection_centers_screen.dart';
import 'package:dairy_ai/features/collection/screens/create_center_screen.dart';
import 'package:dairy_ai/features/collection/screens/center_dashboard_screen.dart';
import 'package:dairy_ai/features/collection/screens/record_milk_screen.dart';
import 'package:dairy_ai/features/collection/screens/cold_chain_screen.dart';

// Milk Purity Checker (public, no auth required)
import 'package:dairy_ai/features/milk_purity/screens/purity_home_screen.dart';
import 'package:dairy_ai/features/milk_purity/screens/brand_detail_screen.dart';
import 'package:dairy_ai/features/milk_purity/screens/compare_screen.dart';
import 'package:dairy_ai/features/milk_purity/screens/purity_scanner_screen.dart';
import 'package:dairy_ai/features/milk_purity/screens/batch_certificate_screen.dart';
import 'package:dairy_ai/features/herd/screens/cattle_lifecycle_screen.dart';
import 'package:dairy_ai/features/vet_farmer/screens/tele_vet_booking_screen.dart';
import 'package:dairy_ai/features/marketplace/screens/marketplace_screen.dart';
import 'package:dairy_ai/features/marketplace/screens/marketplace_detail_screen.dart';
import 'package:dairy_ai/features/marketplace/screens/sell_on_milterra_screen.dart';
import 'package:dairy_ai/features/marketplace/screens/product_list_screen.dart';
import 'package:dairy_ai/features/marketplace/screens/product_detail_screen.dart';
import 'package:dairy_ai/features/marketplace/screens/deals_screen.dart';
import 'package:dairy_ai/features/marketplace/models/product_models.dart';
import 'package:dairy_ai/features/cart/screens/cart_screen.dart';
import 'package:dairy_ai/features/cart/screens/delivery_addresses_screen.dart';
import 'package:dairy_ai/features/cart/screens/checkout_screen.dart';
import 'package:dairy_ai/features/cart/screens/orders_screen.dart';
import 'package:dairy_ai/features/cart/screens/order_tracking_screen.dart';
import 'package:dairy_ai/features/cart/screens/wishlist_screen.dart';
import 'package:dairy_ai/features/marketplace/screens/about_milterra_screen.dart';
import 'package:dairy_ai/features/marketplace/screens/help_support_screen.dart';
import 'package:dairy_ai/features/marketplace/screens/milterra_earth_screen.dart';

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
  final currentUser = ref.watch(currentUserProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    // Customers should be able to browse the catalogue before creating an account.
    initialLocation: '/shop',
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final isAuthenticated = authState.maybeWhen(
        authenticated: (_) => true,
        orElse: () => false,
      );

      final location = state.uri.path;
      final userRole = currentUser?.role.toLowerCase();
      final isAdmin = userRole == 'admin' || userRole == 'super_admin';
      final isSeller = isAdmin || userRole == 'vendor' || userRole == 'seller';

      final isAdminArea = location == '/admin/ecommerce' ||
          location == '/admin-dashboard' ||
          location == '/admin-farmers' ||
          location == '/admin-vets' ||
          location.startsWith('/admin/commerce');

      final isSellerArea = location == '/seller/dashboard' ||
          location == '/vendor-dashboard' ||
          location == '/vendor-orders' ||
          location == '/vendor-profile' ||
          location == '/vendor/products';

      // 1. Role-based protection for Admin routes
      if (isAdminArea) {
        if (!isAuthenticated) {
          return Uri(path: '/admin/login', queryParameters: {
            'next': location,
          }).toString();
        }
        if (!isAdmin) {
          return '/shop';
        }
      }

      // 2. Role-based protection for Seller/Vendor routes
      if (isSellerArea) {
        if (!isAuthenticated) {
          return Uri(path: '/seller/login', queryParameters: {
            'next': location,
          }).toString();
        }
        if (!isSeller) {
          return '/shop';
        }
      }

      // 3. Login redirects if already authenticated with matching role
      if (isAuthenticated && isAdmin && location == '/admin/login') {
        return '/admin/ecommerce';
      }
      if (isAuthenticated && isSeller && location == '/seller/login') {
        return '/seller/dashboard';
      }

      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/otp-verify' ||
          location == '/admin/login' ||
          location == '/seller/login' ||
          location == '/seller/onboarding' ||
          location == '/vendor-register';

      final isPublicRoute = location == '/shop' ||
          location.startsWith('/shop/') ||
          location.startsWith('/product/') ||
          location == '/' ||
          location == '/wishlist' ||
          location == '/shop/wishlist' ||
          location == '/marketplace/wishlist' ||
          location == '/about' ||
          location == '/shop/about' ||
          location == '/earth' ||
          location == '/shop/earth' ||
          location == '/marketplace/earth' ||
          location == '/help' ||
          location == '/shop/help' ||
          location == '/register' ||
          location == '/profile' ||
          location == '/account' ||
          location == '/shop/profile' ||
          location == '/shop/account' ||
          location.startsWith('/purity') ||
          location == '/marketplace' ||
          location == '/marketplace/sell' ||
          location == '/sell' ||
          location == '/shop/sell' ||
          location.startsWith('/marketplace/listing/') ||
          location == '/marketplace/feed' ||
          location == '/marketplace/equipment' ||
          location == '/marketplace/deals' ||
          location.startsWith('/marketplace/product/') ||
          location == '/cart' ||
          location == '/shop/cart' ||
          location == '/marketplace/cart' ||
          location == '/addresses' ||
          location == '/shop/addresses' ||
          location == '/marketplace/addresses' ||
          location == '/balance' ||
          location == '/wallet' ||
          location == '/shop/balance' ||
          location == '/shop/wallet' ||
          location == '/marketplace/balance' ||
          location == '/marketplace/wallet' ||
          location.startsWith('/cooperative') ||
          location.startsWith('/herd/lifecycle') ||
          location.startsWith('/vet/booking');

      if (!isAuthenticated && !isAuthRoute && !isPublicRoute) {
        return Uri(path: '/login', queryParameters: {
          'next': shoppingReturnPath(state.uri.toString())
        }).toString();
      }
      if (isAuthenticated && (state.matchedLocation == '/login' || state.matchedLocation == '/register')) {
        final next = state.uri.queryParameters['next'];
        return shoppingReturnPath(next);
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', redirect: (_, __) => '/shop'),
      GoRoute(
        path: '/shop/product/:productId',
        builder: (context, state) => ProductDetailScreen(
          productId: state.pathParameters['productId']!,
        ),
      ),
      GoRoute(
        path: '/product/:productId',
        redirect: (context, state) =>
            '/shop/product/${state.pathParameters['productId']}',
      ),
      GoRoute(
        path: '/cart',
        redirect: (_, __) => '/marketplace/cart',
      ),
      GoRoute(
        path: '/shop/cart',
        redirect: (_, __) => '/marketplace/cart',
      ),
      GoRoute(
        path: '/checkout',
        redirect: (_, __) => '/marketplace/checkout',
      ),
      GoRoute(
        path: '/addresses',
        redirect: (_, __) => '/marketplace/addresses',
      ),
      GoRoute(
        path: '/shop/addresses',
        redirect: (_, __) => '/marketplace/addresses',
      ),
      GoRoute(
        path: '/orders',
        redirect: (_, __) => '/marketplace/orders',
      ),
      GoRoute(
        path: '/shop/orders',
        redirect: (_, __) => '/marketplace/orders',
      ),
      GoRoute(
        path: '/shop/order/:orderId',
        redirect: (context, state) =>
            '/marketplace/orders/${state.pathParameters['orderId']}',
      ),
      GoRoute(
        path: '/balance',
        builder: (context, state) => const MilterraWalletScreen(),
      ),
      GoRoute(
        path: '/wallet',
        redirect: (_, __) => '/balance',
      ),
      GoRoute(
        path: '/shop/balance',
        redirect: (_, __) => '/balance',
      ),
      GoRoute(
        path: '/shop/wallet',
        redirect: (_, __) => '/balance',
      ),
      GoRoute(
        path: '/marketplace/balance',
        redirect: (_, __) => '/balance',
      ),
      GoRoute(
        path: '/marketplace/wallet',
        redirect: (_, __) => '/balance',
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/account',
        redirect: (_, __) => '/profile',
      ),
      GoRoute(
        path: '/shop/profile',
        redirect: (_, __) => '/profile',
      ),
      GoRoute(
        path: '/shop/account',
        redirect: (_, __) => '/profile',
      ),
      GoRoute(
        path: '/shop/deals',
        builder: (_, __) => const DealsScreen(),
      ),
      GoRoute(
        path: '/marketplace/deals',
        redirect: (_, __) => '/shop/deals',
      ),
      GoRoute(
          path: '/shop',
          builder: (_, state) => ProductListScreen(
              initialQuery: state.uri.queryParameters['query'] ?? '',
              initialCategory:
                  state.uri.queryParameters['category'] ?? 'All products')),
      GoRoute(
          path: '/admin/commerce',
          builder: (_, __) => const CommerceCategoriesScreen()),
      GoRoute(
          path: '/admin/commerce/products',
          builder: (_, __) => const CommerceProductsScreen()),
      GoRoute(
          path: '/admin/commerce/orders',
          builder: (_, __) => const CommerceOrdersScreen()),
      GoRoute(
        path: '/wishlist',
        builder: (context, state) => const WishlistScreen(),
      ),
      GoRoute(
        path: '/shop/wishlist',
        redirect: (_, __) => '/wishlist',
      ),
      GoRoute(
        path: '/marketplace/wishlist',
        redirect: (_, __) => '/wishlist',
      ),
      GoRoute(
        path: '/about',
        builder: (context, state) => const AboutMilterraScreen(),
      ),
      GoRoute(
        path: '/shop/about',
        redirect: (_, __) => '/about',
      ),
      GoRoute(
        path: '/earth',
        builder: (context, state) => const MilterraEarthScreen(),
      ),
      GoRoute(
        path: '/shop/earth',
        redirect: (_, __) => '/earth',
      ),
      GoRoute(
        path: '/marketplace/earth',
        redirect: (_, __) => '/earth',
      ),
      GoRoute(
        path: '/help',
        builder: (context, state) => const HelpSupportScreen(),
      ),
      GoRoute(
        path: '/shop/help',
        redirect: (_, __) => '/help',
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const LoginScreen(initialTab: 1),
      ),
      // ---- Auth routes (no shell) ----
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/otp-verify',
        builder: (context, state) {
          final phone = state.uri.queryParameters['phone'] ?? '';
          return OtpScreen(
            phone: phone,
            nextPath: state.uri.queryParameters['next'],
          );
        },
      ),

      // ---- Milk Purity Checker (public, no auth) ----
      GoRoute(
        path: '/purity',
        builder: (context, state) => const PurityHomeScreen(),
        routes: [
          GoRoute(
            path: 'scan',
            builder: (context, state) => const PurityScannerScreen(),
          ),
          GoRoute(
            path: 'certificate/:batchId',
            builder: (context, state) {
              final batchId = state.pathParameters['batchId']!;
              return BatchCertificateScreen(batchId: batchId);
            },
          ),
          GoRoute(
            path: 'brand/:brandSlug',
            builder: (context, state) {
              final slug = state.pathParameters['brandSlug']!;
              return BrandDetailScreen(brandSlug: slug);
            },
          ),
          GoRoute(
            path: 'compare',
            builder: (context, state) => const CompareScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/cooperative/intake',
        builder: (context, state) => const MilkIntakeScreen(),
      ),
      GoRoute(
        path: '/herd/lifecycle/:cattleId',
        builder: (context, state) {
          final cattleId = state.pathParameters['cattleId'] ?? 'MIL-2024-0842';
          return CattleLifecycleScreen(cattleId: cattleId);
        },
      ),
      GoRoute(
        path: '/vet/booking',
        builder: (context, state) {
          final cattleId = state.uri.queryParameters['cattleId'];
          return TeleVetBookingScreen(initialCattleId: cattleId);
        },
      ),
      GoRoute(
        path: '/marketplace',
        builder: (context, state) => const MarketplaceScreen(),
      ),
      GoRoute(
        path: '/sell',
        redirect: (_, __) => '/marketplace/sell',
      ),
      GoRoute(
        path: '/shop/sell',
        redirect: (_, __) => '/marketplace/sell',
      ),
      GoRoute(
        path: '/marketplace/sell',
        builder: (context, state) {
          final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
          return SellOnMilterraScreen(initialTab: tab);
        },
      ),
      GoRoute(
        path: '/marketplace/listing/:listingId',
        builder: (context, state) => MarketplaceDetailScreen(
          listingId: state.pathParameters['listingId']!,
        ),
      ),
      GoRoute(
        path: '/marketplace/feed',
        builder: (context, state) =>
            const ProductListScreen(category: ProductCategory.feedNutrition),
      ),
      GoRoute(
        path: '/marketplace/equipment',
        builder: (context, state) =>
            const ProductListScreen(category: ProductCategory.equipment),
      ),
      GoRoute(
        path: '/marketplace/product/:productId',
        builder: (context, state) => ProductDetailScreen(
          productId: state.pathParameters['productId']!,
        ),
      ),
      GoRoute(
        path: '/marketplace/cart',
        builder: (context, state) => const CartScreen(),
      ),
      GoRoute(
        path: '/marketplace/addresses',
        builder: (context, state) => const DeliveryAddressesScreen(),
      ),
      GoRoute(
          path: '/marketplace/checkout',
          builder: (context, state) => const CheckoutScreen()),
      GoRoute(
          path: '/marketplace/orders',
          builder: (context, state) => const OrdersScreen()),
      GoRoute(
          path: '/marketplace/orders/:orderId',
          builder: (context, state) => OrderTrackingScreen(
                orderId: state.pathParameters['orderId']!,
              )),

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
                builder: (context, state) => HerdListScreen(
                  farmerId: currentUser?.id ?? '',
                ),
                routes: [
                  GoRoute(
                    path: 'add',
                    builder: (context, state) => AddCattleScreen(
                      farmerId: currentUser?.id ?? '',
                    ),
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
                builder: (context, state) {
                  final consultationId = int.tryParse(
                    state.uri.queryParameters['consultationId'] ?? '',
                  );
                  if (consultationId == null) {
                    return const Scaffold(
                      body: Center(
                          child: Text(
                              'Select a consultation from the dashboard.')),
                    );
                  }
                  return VetConsultationScreen(consultationId: consultationId);
                },
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
                builder: (context, state) => const VendorOrdersScreen(),
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
      GoRoute(
          path: '/vendor/products',
          builder: (context, state) => const VendorProductsScreen()),

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

      // ---- Ecommerce Admin Panel & Multi-Seller Portal Routes ----
      GoRoute(
        path: '/admin/login',
        builder: (context, state) => const AdminLoginScreen(),
      ),
      GoRoute(
        path: '/admin/ecommerce',
        builder: (context, state) => const EcommerceAdminPanelScreen(),
      ),
      GoRoute(
        path: '/seller/login',
        builder: (context, state) => const SellerLoginScreen(),
      ),
      GoRoute(
        path: '/seller/onboarding',
        builder: (context, state) => const SellerOnboardingScreen(),
      ),
      GoRoute(
        path: '/seller/dashboard',
        builder: (context, state) => const SellerPortalScreen(),
      ),
    ],
  );
});

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

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
            icon: Icons.verified,
            label: 'Milk Purity Checker',
            onTap: () => context.push('/purity'),
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
