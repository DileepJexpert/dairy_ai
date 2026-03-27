import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/app/theme.dart';
import 'package:dairy_ai/features/notifications/models/notification_models.dart';
import 'package:dairy_ai/features/notifications/providers/notification_provider.dart';

/// Notification filter options.
enum _NotificationFilter { all, unread }

/// Notifications list screen grouped by date with filter and mark-all-read.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  _NotificationFilter _filter = _NotificationFilter.all;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(notificationProvider.notifier).loadNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(notificationProvider);
    final notifications = _filter == _NotificationFilter.unread
        ? state.notifications.where((n) => !n.isRead).toList()
        : state.notifications;
    final grouped = _groupByDate(notifications);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              onPressed: () {
                ref.read(notificationProvider.notifier).markAllRead();
              },
              child: const Text(
                'Mark all read',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter tabs.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  isSelected: _filter == _NotificationFilter.all,
                  onTap: () =>
                      setState(() => _filter = _NotificationFilter.all),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Unread (${state.unreadCount})',
                  isSelected: _filter == _NotificationFilter.unread,
                  onTap: () =>
                      setState(() => _filter = _NotificationFilter.unread),
                ),
              ],
            ),
          ),

          // Content.
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                    ? _ErrorView(
                        message: state.error!,
                        onRetry: () {
                          ref
                              .read(notificationProvider.notifier)
                              .loadNotifications();
                        },
                      )
                    : notifications.isEmpty
                        ? _EmptyView(filter: _filter)
                        : RefreshIndicator(
                            onRefresh: () => ref
                                .read(notificationProvider.notifier)
                                .loadNotifications(),
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _buildItemCount(grouped),
                              itemBuilder: (context, index) {
                                return _buildListItem(
                                  context,
                                  theme,
                                  grouped,
                                  index,
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  /// Group notifications by date label ("Today", "Yesterday", or date string).
  Map<String, List<NotificationItem>> _groupByDate(
      List<NotificationItem> items) {
    final grouped = <String, List<NotificationItem>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final item in items) {
      final date = DateTime(
          item.createdAt.year, item.createdAt.month, item.createdAt.day);
      String label;
      if (date == today) {
        label = 'Today';
      } else if (date == yesterday) {
        label = 'Yesterday';
      } else {
        final d = item.createdAt;
        label =
            '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
      }
      grouped.putIfAbsent(label, () => []).add(item);
    }
    return grouped;
  }

  int _buildItemCount(Map<String, List<NotificationItem>> grouped) {
    var count = 0;
    for (final entry in grouped.entries) {
      count += 1; // header
      count += entry.value.length;
    }
    return count;
  }

  Widget _buildListItem(
    BuildContext context,
    ThemeData theme,
    Map<String, List<NotificationItem>> grouped,
    int index,
  ) {
    var currentIndex = 0;
    for (final entry in grouped.entries) {
      if (currentIndex == index) {
        // Date header.
        return Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            entry.key,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: DairyTheme.subtleGrey,
            ),
          ),
        );
      }
      currentIndex++;
      for (final item in entry.value) {
        if (currentIndex == index) {
          return _NotificationTile(
            item: item,
            onTap: () {
              ref.read(notificationProvider.notifier).markRead(item.id);
              _handleNotificationTap(item);
            },
          );
        }
        currentIndex++;
      }
    }
    return const SizedBox.shrink();
  }

  void _handleNotificationTap(NotificationItem item) {
    // TODO: Navigate to relevant screen based on notification type and data.
    // For now, show a snackbar with details.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(item.body),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter chip widget.
// ---------------------------------------------------------------------------
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? DairyTheme.primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? DairyTheme.primaryGreen
                : const Color(0xFFE0E0E0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : DairyTheme.darkText,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Notification list tile.
// ---------------------------------------------------------------------------
class _NotificationTile extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;

  const _NotificationTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = item.createdAt;
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: item.isRead ? 0 : 2,
      color: item.isRead ? Colors.white : DairyTheme.creamWhite,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type icon.
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.type.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  item.type.icon,
                  color: item.type.color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // Content.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 14,
                              fontWeight:
                                  item.isRead ? FontWeight.w400 : FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          timeStr,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: DairyTheme.subtleGrey,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: item.type.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.type.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: item.type.color,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (!item.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: DairyTheme.primaryGreen,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty view.
// ---------------------------------------------------------------------------
class _EmptyView extends StatelessWidget {
  final _NotificationFilter filter;

  const _EmptyView({required this.filter});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 64,
            color: DairyTheme.subtleGrey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            filter == _NotificationFilter.unread
                ? 'No unread notifications'
                : 'No notifications yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: DairyTheme.subtleGrey,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error view.
// ---------------------------------------------------------------------------
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: DairyTheme.errorRed),
          const SizedBox(height: 12),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: DairyTheme.subtleGrey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
