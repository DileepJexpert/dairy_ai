import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/core/constants.dart';
import 'package:dairy_ai/features/notifications/models/notification_models.dart';

// ---------------------------------------------------------------------------
// Dio provider for notifications feature.
// ---------------------------------------------------------------------------
final _dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: AppConstants.baseUrl,
    connectTimeout: AppConstants.connectTimeout,
    receiveTimeout: AppConstants.receiveTimeout,
    headers: {'Content-Type': 'application/json'},
  ));
  return dio;
});

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

  int get unreadCount =>
      notifications.where((n) => !n.isRead).length;
}

// ---------------------------------------------------------------------------
// Notification notifier.
// ---------------------------------------------------------------------------
class NotificationNotifier extends StateNotifier<NotificationState> {
  final Dio _dio;

  NotificationNotifier(this._dio) : super(const NotificationState());

  /// Fetch all notifications from the server.
  Future<void> loadNotifications() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dio.get('/notifications');
      final body = response.data as Map<String, dynamic>;
      if (body['success'] == true) {
        final items = (body['data'] as List<dynamic>)
            .map((e) =>
                NotificationItem.fromJson(e as Map<String, dynamic>))
            .toList();
        state = state.copyWith(notifications: items, isLoading: false);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: body['message'] as String? ?? 'Failed to load notifications',
        );
      }
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data?['message'] as String? ??
            'Network error loading notifications',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Mark a single notification as read.
  Future<void> markRead(String notificationId) async {
    // Optimistic update.
    state = state.copyWith(
      notifications: state.notifications.map((n) {
        if (n.id == notificationId) {
          return n.copyWith(isRead: true);
        }
        return n;
      }).toList(),
    );

    try {
      await _dio.patch('/notifications/$notificationId', data: {
        'is_read': true,
      });
    } on DioException {
      // Revert on failure — reload from server.
      await loadNotifications();
    }
  }

  /// Mark all notifications as read.
  Future<void> markAllRead() async {
    // Optimistic update.
    state = state.copyWith(
      notifications:
          state.notifications.map((n) => n.copyWith(isRead: true)).toList(),
    );

    try {
      await _dio.post('/notifications/mark-all-read');
    } on DioException {
      await loadNotifications();
    }
  }
}

// ---------------------------------------------------------------------------
// Providers.
// ---------------------------------------------------------------------------

/// Main notification state provider.
final notificationProvider =
    StateNotifierProvider.autoDispose<NotificationNotifier, NotificationState>(
        (ref) {
  return NotificationNotifier(ref.watch(_dioProvider));
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
