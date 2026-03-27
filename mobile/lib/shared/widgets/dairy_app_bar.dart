import 'package:flutter/material.dart';

/// Reusable branded app bar for DairyAI screens.
class DairyAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBack;
  final VoidCallback? onBack;

  const DairyAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBack = true,
    this.onBack,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      automaticallyImplyLeading: showBack,
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            )
          : null,
      actions: actions,
    );
  }
}
