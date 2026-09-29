import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:dairy_ai/core/constants.dart';
import 'package:dairy_ai/core/analytics_service.dart';
import 'package:dairy_ai/app/store_theme.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import 'package:dairy_ai/features/auth/screens/admin_login_screen.dart';
import 'package:dairy_ai/features/auth/screens/login_screen.dart';
import 'package:dairy_ai/features/commerce/models/taxonomy.dart';
import 'package:dairy_ai/features/commerce/providers/commerce_provider.dart';
import 'package:dairy_ai/features/marketplace/providers/merchandising_provider.dart';
import 'package:dairy_ai/features/marketplace/providers/product_provider.dart';
import 'package:dairy_ai/features/cart/services/local_basket_storage.dart';

class _QuietAnalytics extends AnalyticsService {
  _QuietAnalytics() : super(Dio()) {
    super.dispose();
  }
  @override
  Future<void> flush() async {}
  @override
  Future<void> initSession(
      {String landingPage = '/shop', bool force = false}) async {}
}

void main() {
  testWidgets('Customer password can be edited and cleared', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(initialLocation: '/login', routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(Dio()),
        analyticsServiceProvider.overrideWith((ref) => _QuietAnalytics()),
        currentUserProvider.overrideWith((ref) => null),
        taxonomyProvider.overrideWith(
            (ref) async => const TaxonomyCatalogue(enabled: false, nodes: [])),
        commerceAccessProvider
            .overrideWith((ref) async => {'can_manage_taxonomy': false}),
        storefrontPlacementsProvider.overrideWith((ref) async => []),
        productsProvider(null).overrideWith((ref) async => []),
        staticCatalogueProvider.overrideWith((ref) async => null),
        localBasketStorageProvider
            .overrideWithValue(LocalBasketStorage(storage: null)),
      ],
      child: MaterialApp.router(theme: StoreTheme.light, routerConfig: router),
    ));
    await tester.pumpAndSettle();

    final passwordField = find.byType(TextFormField).last;
    await tester.enterText(passwordField, 'example123');
    await tester.pump();
    expect(find.byTooltip('Clear password'), findsOneWidget);
    await tester.enterText(passwordField, 'example12');
    await tester.pump();
    expect(tester.widget<TextFormField>(passwordField).controller!.text,
        'example12');
    await tester.tap(find.byTooltip('Clear password'));
    await tester.pump();
    expect(
        tester.widget<TextFormField>(passwordField).controller!.text, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cloudflare admin sign-in requests a password, not an OTP',
      (tester) async {
    expect(AppConstants.separateCustomerAuth, isTrue,
        reason: 'Run this test with AUTH_API_BASE_URL defined.');
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(initialLocation: '/admin/login', routes: [
      GoRoute(
          path: '/admin/login', builder: (_, __) => const AdminLoginScreen()),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(Dio()),
        analyticsServiceProvider.overrideWith((ref) => _QuietAnalytics()),
        currentUserProvider.overrideWith((ref) => null),
        taxonomyProvider.overrideWith(
            (ref) async => const TaxonomyCatalogue(enabled: false, nodes: [])),
        commerceAccessProvider
            .overrideWith((ref) async => {'can_manage_taxonomy': false}),
        storefrontPlacementsProvider.overrideWith((ref) async => []),
        productsProvider(null).overrideWith((ref) async => []),
        staticCatalogueProvider.overrideWith((ref) async => null),
        localBasketStorageProvider
            .overrideWithValue(LocalBasketStorage(storage: null)),
      ],
      child: MaterialApp.router(theme: StoreTheme.light, routerConfig: router),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Password'), findsWidgets);
    expect(find.text('Continue with OTP'), findsNothing);
    expect(find.text('New to Milterra? Create an account'), findsNothing);
  });
}
