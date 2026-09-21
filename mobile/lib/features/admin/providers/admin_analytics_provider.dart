import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/analytics_models.dart';

final adminAnalyticsProvider =
    StateNotifierProvider<AdminAnalyticsNotifier, AdminAnalyticsState>((ref) {
  return AdminAnalyticsNotifier(ref.watch(dioProvider));
});

class AdminAnalyticsState {
  const AdminAnalyticsState({
    this.isLoadingCarts = false,
    this.isLoadingTraffic = false,
    this.isLoadingClickstream = false,
    this.isLoadingSessions = false,
    this.cartFilter = 'all',
    this.cartSearch = '',
    this.sessionFilter = 'all',
    this.sessionSearch = '',
    this.carts = const [],
    this.traffic,
    this.clickstreamEvents = const [],
    this.sessionsData,
    this.selectedUserPhone,
    this.selectedEventType,
    this.cartsError,
    this.trafficError,
    this.clickstreamError,
    this.sessionsError,
  });

  final bool isLoadingCarts;
  final bool isLoadingTraffic;
  final bool isLoadingClickstream;
  final bool isLoadingSessions;
  final String cartFilter;
  final String cartSearch;
  final String sessionFilter;
  final String sessionSearch;
  final List<AdminCartSummary> carts;
  final TrafficAnalyticsData? traffic;
  final List<ClickstreamEventItem> clickstreamEvents;
  final CustomerSessionsData? sessionsData;
  final String? selectedUserPhone;
  final String? selectedEventType;
  final String? cartsError;
  final String? trafficError;
  final String? clickstreamError;
  final String? sessionsError;

  AdminAnalyticsState copyWith({
    bool? isLoadingCarts,
    bool? isLoadingTraffic,
    bool? isLoadingClickstream,
    bool? isLoadingSessions,
    String? cartFilter,
    String? cartSearch,
    String? sessionFilter,
    String? sessionSearch,
    List<AdminCartSummary>? carts,
    TrafficAnalyticsData? traffic,
    List<ClickstreamEventItem>? clickstreamEvents,
    CustomerSessionsData? sessionsData,
    String? selectedUserPhone,
    String? selectedEventType,
    String? cartsError,
    String? trafficError,
    String? clickstreamError,
    String? sessionsError,
    bool clearTraffic = false,
    bool clearSessionsData = false,
    bool clearSelectedUserPhone = false,
    bool clearSelectedEventType = false,
    bool clearCartsError = false,
    bool clearTrafficError = false,
    bool clearClickstreamError = false,
    bool clearSessionsError = false,
  }) {
    return AdminAnalyticsState(
      isLoadingCarts: isLoadingCarts ?? this.isLoadingCarts,
      isLoadingTraffic: isLoadingTraffic ?? this.isLoadingTraffic,
      isLoadingClickstream: isLoadingClickstream ?? this.isLoadingClickstream,
      isLoadingSessions: isLoadingSessions ?? this.isLoadingSessions,
      cartFilter: cartFilter ?? this.cartFilter,
      cartSearch: cartSearch ?? this.cartSearch,
      sessionFilter: sessionFilter ?? this.sessionFilter,
      sessionSearch: sessionSearch ?? this.sessionSearch,
      carts: carts ?? this.carts,
      traffic: clearTraffic ? null : traffic ?? this.traffic,
      clickstreamEvents: clickstreamEvents ?? this.clickstreamEvents,
      sessionsData: clearSessionsData ? null : sessionsData ?? this.sessionsData,
      selectedUserPhone: clearSelectedUserPhone
          ? null
          : selectedUserPhone ?? this.selectedUserPhone,
      selectedEventType: clearSelectedEventType
          ? null
          : selectedEventType ?? this.selectedEventType,
      cartsError: clearCartsError ? null : cartsError ?? this.cartsError,
      trafficError:
          clearTrafficError ? null : trafficError ?? this.trafficError,
      clickstreamError: clearClickstreamError
          ? null
          : clickstreamError ?? this.clickstreamError,
      sessionsError:
          clearSessionsError ? null : sessionsError ?? this.sessionsError,
    );
  }
}

class AdminAnalyticsNotifier extends StateNotifier<AdminAnalyticsState> {
  AdminAnalyticsNotifier(this._dio) : super(const AdminAnalyticsState()) {
    refreshAll();
  }

  final Dio _dio;

  Future<void> refreshAll() async {
    await Future.wait(
        [fetchCarts(), fetchTraffic(), fetchClickstream(), fetchSessions()]);
  }

  void setSessionFilter(String filter) {
    state = state.copyWith(sessionFilter: filter);
    fetchSessions();
  }

  void setSessionSearch(String search) {
    state = state.copyWith(sessionSearch: search);
    fetchSessions();
  }

  Future<void> fetchSessions() async {
    state = state.copyWith(isLoadingSessions: true, clearSessionsError: true);
    try {
      final query = <String, dynamic>{
        'status': state.sessionFilter,
      };
      if (state.sessionSearch.trim().isNotEmpty) {
        query['search'] = state.sessionSearch.trim();
      }
      final response = await _dio.get(
        '/admin/ecommerce/analytics/sessions',
        queryParameters: query,
      );
      final data = CustomerSessionsData.fromJson(
        Map<String, dynamic>.from(response.data['data'] as Map),
      );
      state = state.copyWith(
        sessionsData: data,
        isLoadingSessions: false,
        clearSessionsError: true,
      );
    } catch (error) {
      debugPrint('[AdminAnalytics] Fetch sessions error: $error');
      state = state.copyWith(
        isLoadingSessions: false,
        sessionsError:
            'Customer sessions radar could not be loaded from server.',
      );
    }
  }

  void setCartFilter(String filter) {
    state = state.copyWith(cartFilter: filter);
    fetchCarts();
  }

  void setCartSearch(String search) {
    state = state.copyWith(cartSearch: search);
    fetchCarts();
  }

  void setClickstreamUserPhone(String? phone) {
    state = state.copyWith(
      selectedUserPhone: phone,
      clearSelectedUserPhone: phone == null,
    );
    fetchClickstream();
  }

  void setClickstreamEventType(String? type) {
    state = state.copyWith(
      selectedEventType: type,
      clearSelectedEventType: type == null,
    );
    fetchClickstream();
  }

  Future<void> fetchCarts() async {
    state = state.copyWith(isLoadingCarts: true, clearCartsError: true);
    try {
      final query = <String, dynamic>{
        'status': state.cartFilter == 'high_value' ? 'all' : state.cartFilter,
      };
      if (state.cartSearch.trim().isNotEmpty) {
        query['search'] = state.cartSearch.trim();
      }
      final response =
          await _dio.get('/admin/ecommerce/carts', queryParameters: query);
      final raw = response.data['data'] as List? ?? const [];
      var carts = raw
          .map((item) =>
              AdminCartSummary.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
      if (state.cartFilter == 'high_value') {
        carts = carts.where((cart) => cart.subtotal >= 1000).toList();
      }
      state = state.copyWith(
        carts: carts,
        isLoadingCarts: false,
        clearCartsError: true,
      );
    } catch (error) {
      debugPrint('[AdminAnalytics] Fetch carts error: $error');
      state = state.copyWith(
        carts: const [],
        isLoadingCarts: false,
        cartsError:
            'Live carts could not be loaded from the server. Check the API connection and admin session.',
      );
    }
  }

  Future<void> fetchTraffic() async {
    state = state.copyWith(
      isLoadingTraffic: true,
      clearTrafficError: true,
    );
    try {
      final response = await _dio.get('/admin/ecommerce/analytics/traffic');
      final traffic = TrafficAnalyticsData.fromJson(
        Map<String, dynamic>.from(response.data['data'] as Map),
      );
      state = state.copyWith(
        traffic: traffic,
        isLoadingTraffic: false,
        clearTrafficError: true,
      );
    } catch (error) {
      debugPrint('[AdminAnalytics] Fetch traffic error: $error');
      state = state.copyWith(
        clearTraffic: true,
        isLoadingTraffic: false,
        trafficError: 'Traffic analytics could not be loaded from the server.',
      );
    }
  }

  Future<void> fetchClickstream() async {
    state = state.copyWith(
      isLoadingClickstream: true,
      clearClickstreamError: true,
    );
    try {
      final query = <String, dynamic>{};
      if (state.selectedUserPhone?.isNotEmpty == true) {
        query['user_phone'] = state.selectedUserPhone;
      }
      if (state.selectedEventType?.isNotEmpty == true &&
          state.selectedEventType != 'ALL') {
        query['event_type'] = state.selectedEventType;
      }
      final response = await _dio.get(
        '/admin/ecommerce/analytics/clickstream',
        queryParameters: query,
      );
      final raw = response.data['data'] as List? ?? const [];
      final events = raw
          .map((item) => ClickstreamEventItem.fromJson(
              Map<String, dynamic>.from(item as Map)))
          .toList();
      state = state.copyWith(
        clickstreamEvents: events,
        isLoadingClickstream: false,
        clearClickstreamError: true,
      );
    } catch (error) {
      debugPrint('[AdminAnalytics] Fetch clickstream error: $error');
      state = state.copyWith(
        clickstreamEvents: const [],
        isLoadingClickstream: false,
        clickstreamError:
            'Clickstream events could not be loaded from the server.',
      );
    }
  }

  Future<Map<String, dynamic>?> getNudgeLink(String cartId) async {
    try {
      final response = await _dio.post('/admin/ecommerce/carts/$cartId/nudge');
      final data = response.data['data'] as Map<String, dynamic>;
      return data;
    } catch (error) {
      debugPrint('[AdminAnalytics] Nudge error: $error');
      return null;
    }
  }
}
