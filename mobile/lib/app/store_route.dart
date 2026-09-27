import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A short, stationary transition for the customer storefront. Unlike a mobile
/// slide, this does not move the entire desktop header and page sideways.
class StoreRoute extends GoRoute {
  StoreRoute({
    required super.path,
    super.redirect,
    required GoRouterWidgetBuilder builder,
  }) : super(
          pageBuilder: (context, state) {
            final duration = MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180);
            return CustomTransitionPage<void>(
              key: state.pageKey,
              name: state.name,
              transitionDuration: duration,
              reverseTransitionDuration: duration,
              child: builder(context, state),
              transitionsBuilder: (context, animation, secondary, child) {
                return FadeTransition(
                  opacity: animation.drive(CurveTween(curve: Curves.easeOut)),
                  child: child,
                );
              },
            );
          },
        );
}
