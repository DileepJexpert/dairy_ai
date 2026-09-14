import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:dairy_ai/features/notifications/models/notification_models.dart';

// ---------------------------------------------------------------------------
// Dio provider for notifications feature.
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// Notification state.
// ---------------------------------------------------------------------------
class NotificationState {
  final List<NotificationItem> notifications;
  final bool isLoading;
  final String? error;

  const NotificationState({
    this.notifications = const [],
    this.isLoading = false,
    this.error,
  });

  NotificationState copyWith({
    List<NotificationItem>? notifications,
    bool? isLoading,
    String? error,
  }) =>
      NotificationState(
        notifications: notifications ?? this.notifications,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );

  int get unreadCount => notifications.where((n) => !n.isRead).length;
}

// ---------------------------------------------------------------------------
// Notification notifier.
// ---------------------------------------------------------------------------
class NotificationNotifier extends StateNotifier<NotificationState> {
  final Dio _dio;

  NotificationNotifier(this._dio) : super(const NotificationState());

  /// Fetch all notifications from the server.
  Future<void> loadNotifications() async {
    if (mounted) state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dio.get('/notifications');
      final body = response.data as Map<String, dynamic>;
      if (body['success'] == true) {
        final items = (body['data'] as List<dynamic>)
            .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
            .toList();
        if (mounted)
          state = state.copyWith(notifications: items, isLoading: false);
      } else {
        if (mounted)
          state = state.copyWith(
            isLoading: false,
            error: body['message'] as String? ?? 'Failed to load notifications',
          );
      }
    } on DioException catch (e) {
      if (mounted)
        state = state.copyWith(
          isLoading: false,
          error: e.response?.data?['message'] as String? ??
              'Network error loading notifications',
        );
    } catch (e) {
      if (mounted)
        state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Mark a single notification as read.
  Future<void> markRead(String notificationId) async {
    // Optimistic update.
    if (mounted)
      state = state.copyWith(
        notifications: state.notifications.map((n) {
          if (n.id == notificationId) {
            return n.copyWith(isRead: true);
          }
          return n;
        }).toList(),
      );

    try {
      await _dio.put('/notifications/$notificationId/read');
    } on DioException {
      // Revert on failure — reload from server.
      await loadNotifications();
    }
  }

  /// Mark all notifications as read.
  Future<void> markAllRead() async {
    // Optimistic update.
    if (mounted)
      state = state.copyWith(
        notifications:
            state.notifications.map((n) => n.copyWith(isRead: true)).toList(),
      );

    try {
      await _dio.put('/notifications/read-all');
    } on DioException {
      await loadNotifications();
    }
  }

  /// Push an instant notification (e.g. order update, courier milestone).
  void pushNotification(NotificationItem item) {
    if (mounted)
      state = state.copyWith(
        notifications: [item, ...state.notifications],
      );
  }
}

// ---------------------------------------------------------------------------
// Providers.
// ---------------------------------------------------------------------------

/// Main notification state provider.
final notificationProvider =
    StateNotifierProvider.autoDispose<NotificationNotifier, NotificationState>(
        (ref) {
  ref.watch(currentUserProvider);
  return NotificationNotifier(ref.watch(dioProvider));
});

/// Convenience provider for the unread count.
final unreadCountProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(notificationProvider).unreadCount;
});

/// Provider that loads notifications — use to trigger initial fetch.
final notificationsLoaderProvider =
    FutureProvider.autoDispose<void>((ref) async {
  await ref.read(notificationProvider.notifier).loadNotifications();
});
