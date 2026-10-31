import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/features/auth/screens/login_screen.dart';

void main() {
  testWidgets('LoginScreen shows Demo Farmer Account card when navigating to /herd and Auto Fill works', (tester) async {
    // Set surface size to avoid narrow-card debug wrapping
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LoginScreen(
            nextPath: '/herd',
            heading: 'Sign in or create an account',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Demo Farmer Card is rendered
    expect(find.text('Demo Farmer Account'), findsOneWidget);
    expect(find.textContaining('Pass: Farmer@123'), findsOneWidget);

    // Verify Auto Fill button is present
    final autoFillBtn = find.text('Auto Fill');
    expect(autoFillBtn, findsOneWidget);

    // Tap Auto Fill
    await tester.tap(autoFillBtn);
    await tester.pumpAndSettle();

    // Verify fields populated
    expect(find.text('9876543210'), findsWidgets);
    expect(find.text('Farmer@123'), findsWidgets);
  });
}
