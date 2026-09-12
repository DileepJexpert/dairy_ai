import 'package:flutter/material.dart';

import 'login_screen.dart';

class SellerLoginScreen extends StatelessWidget {
  const SellerLoginScreen({super.key, this.nextPath});

  final String? nextPath;

  @override
  Widget build(BuildContext context) => LoginScreen(
        nextPath: nextPath ?? '/vendor-dashboard',
        heading: 'Seller and vendor sign in',
        description:
            'Continue with the mobile number linked to your approved vendor profile.',
      );
}
