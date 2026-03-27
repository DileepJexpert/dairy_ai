import 'package:flutter/material.dart';
import 'package:dairy_ai/app/theme.dart';
import 'package:dairy_ai/features/chat/models/chat_models.dart';

/// A horizontally scrollable bar of quick action chips for the chat.
class QuickActionChips extends StatelessWidget {
  final ValueChanged<QuickAction> onActionTap;

  const QuickActionChips({super.key, required this.onActionTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: QuickAction.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final action = QuickAction.values[index];
          return ActionChip(
            avatar: Icon(
              _iconForAction(action),
              size: 16,
              color: DairyTheme.primaryGreen,
            ),
            label: Text(
              action.label,
              style: const TextStyle(fontSize: 13),
            ),
            backgroundColor: DairyTheme.creamWhite,
            side: BorderSide(color: DairyTheme.lightGreen),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            onPressed: () => onActionTap(action),
          );
        },
      ),
    );
  }

  IconData _iconForAction(QuickAction action) {
    switch (action) {
      case QuickAction.checkMilkPrice:
        return Icons.currency_rupee;
      case QuickAction.healthAdvice:
        return Icons.medical_services_outlined;
      case QuickAction.feedPlan:
        return Icons.grass;
      case QuickAction.callVet:
        return Icons.video_call_outlined;
    }
  }
}
