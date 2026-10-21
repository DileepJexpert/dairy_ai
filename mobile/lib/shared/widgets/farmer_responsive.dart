import 'package:flutter/material.dart';

/// Standard responsive breakpoints for the Milterra Farmer Portal.
class FarmerBreakpoints {
  const FarmerBreakpoints._();

  /// Mobile breakpoint: screen width < 640px.
  /// Ideal for portrait smartphones held with one hand.
  static const double mobileMax = 640.0;

  /// Tablet breakpoint: screen width between 640px and 1024px.
  /// Ideal for iPads, Galaxy Tabs, foldables, and landscape phones.
  static const double tabletMax = 1024.0;

  /// Form optimal width: 620px ensures comfortable reading and thumb typing.
  static const double formMaxWidth = 620.0;

  /// Content/list optimal width: 760px ensures balanced list and grid cards.
  static const double contentMaxWidth = 760.0;

  /// Dashboard optimal width: 840px provides spacious multi-stat metrics.
  static const double dashboardMaxWidth = 840.0;

  /// Helper to test if device is currently mobile width.
  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobileMax;

  /// Helper to test if device is currently tablet width.
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= mobileMax && width < tabletMax;
  }

  /// Helper to test if device is currently desktop width.
  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletMax;
}

/// A responsive wrapper widget that ensures pages follow:
/// - Mobile First: 100% full width, thumb-friendly padding.
/// - Tablet Second: Centered layout with balanced maximum width (e.g. 760px).
/// - Desktop Graceful: Never awkwardly stretched to 1920px.
class FarmerResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const FarmerResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = FarmerBreakpoints.contentMaxWidth,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    Widget body = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );

    if (padding != null) {
      body = Padding(padding: padding!, child: body);
    }

    return body;
  }
}
