import 'dart:async';

import 'package:dairy_ai/app/store_route.dart';
import 'package:dairy_ai/features/cart/providers/delivery_address_provider.dart';
import 'package:dairy_ai/features/marketplace/widgets/store_loading_layout.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('addresses stay pending until the server answers, including retries',
      () async {
    var reply = Completer<Response<dynamic>>();
    final requested = Completer<void>();
    final dio = Dio();
    dio.interceptors
        .add(InterceptorsWrapper(onRequest: (options, handler) async {
      if (!requested.isCompleted) requested.complete();
      try {
        handler.resolve(await reply.future);
      } catch (_) {
        handler.reject(DioException(requestOptions: options));
      }
    }));
    final notifier = DeliveryAddressNotifier(dio);
    addTearDown(notifier.dispose);
    expect(notifier.state.isLoading, isTrue);
    expect(notifier.state.hasValue, isFalse);
    final failed = Completer<void>();
    notifier.addListener((state) {
      if (state.hasError && !failed.isCompleted) failed.complete();
    });
    await requested.future;
    reply.completeError(StateError('offline'));
    await failed.future;
    reply = Completer<Response<dynamic>>();
    final retry = notifier.refresh();
    expect(notifier.state.isLoading, isTrue);
    reply.complete(Response(
      requestOptions: RequestOptions(path: '/marketplace/addresses'),
      data: {'data': <dynamic>[]},
    ));
    await retry;
    expect(notifier.state.requireValue, isEmpty);
  });

  for (final reduceMotion in [false, true]) {
    testWidgets(
        'store navigation and back respect reduced motion=$reduceMotion',
        (tester) async {
      final router = GoRouter(routes: [
        StoreRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/checkout'),
              child: const Text('Proceed to checkout'),
            ),
          ),
        ),
        StoreRoute(
          path: '/checkout',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Checkout content')),
          ),
        ),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data:
              MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Proceed to checkout'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final fade = tester.widget<FadeTransition>(find
          .ancestor(
            of: find.text('Checkout content'),
            matching: find.byType(FadeTransition),
          )
          .first);
      if (reduceMotion) {
        expect(fade.opacity.value, 1);
      } else {
        expect(fade.opacity.value, inExclusiveRange(0, 1));
      }
      final position = tester.getCenter(find.text('Checkout content'));
      await tester.pumpAndSettle();
      expect(tester.getCenter(find.text('Checkout content')), position);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Proceed to checkout'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [360.0, 1440.0]) {
    testWidgets('checkout loading layout fits width $width', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: StoreLoadingLayout(checkout: true)),
      ));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
