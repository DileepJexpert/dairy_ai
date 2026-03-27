import 'package:flutter/material.dart';

import 'package:dairy_ai/features/herd/models/cattle_model.dart';

/// A reusable list tile for displaying a cattle entry.
///
/// Shows the photo (or placeholder), name, tag ID, breed, and status chip.
class CattleListTile extends StatelessWidget {
  const CattleListTile({
    super.key,
    required this.cattle,
    this.onTap,
  });

  final Cattle cattle;
  final VoidCallback? onTap;

  Color _statusColor(CattleStatus status) {
    switch (status) {
      case CattleStatus.active:
        return Colors.green;
      case CattleStatus.dry:
        return Colors.orange;
      case CattleStatus.sold:
        return Colors.blueGrey;
      case CattleStatus.deceased:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _buildAvatar(theme),
        title: Text(
          cattle.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              '${cattle.tagId}  ·  ${cattle.breed}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _StatusChip(
                  label: cattle.statusLabel,
                  color: _statusColor(cattle.status),
                ),
                const SizedBox(width: 8),
                Text(
                  cattle.age,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  Widget _buildAvatar(ThemeData theme) {
    if (cattle.photoUrl != null && cattle.photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 28,
        backgroundImage: NetworkImage(cattle.photoUrl!),
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
      );
    }
    return CircleAvatar(
      radius: 28,
      backgroundColor: theme.colorScheme.primaryContainer,
      child: Icon(
        cattle.sex == CattleSex.male ? Icons.male : Icons.female,
        color: theme.colorScheme.onPrimaryContainer,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
