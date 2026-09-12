import 'package:flutter/material.dart';

import 'login_screen.dart';

class AdminLoginScreen extends StatelessWidget {
  const AdminLoginScreen({super.key, this.nextPath});

  final String? nextPath;

  @override
  Widget build(BuildContext context) => LoginScreen(
        nextPath: nextPath ?? '/admin/ecommerce',
        heading: 'Milterra administration',
        description:
            'Continue with the mobile number assigned to your admin account.',
      );
}
