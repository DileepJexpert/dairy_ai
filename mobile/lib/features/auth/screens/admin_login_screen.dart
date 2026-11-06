import 'package:flutter/material.dart';

import 'login_screen.dart';

class AdminLoginScreen extends StatelessWidget {
  const AdminLoginScreen({super.key, this.nextPath});

  final String? nextPath;

  @override
  Widget build(BuildContext context) => LoginScreen(
        nextPath: nextPath ?? '/admin/commerce/orders',
        heading: 'Milterra Administration',
        description:
            'Sign in to access order fulfillment, dispatch, and shipment management.',
        initialPhone: '9839769808',
        initialPassword: 'Password@123',
        showAdminQuickChip: true,
      );
}
