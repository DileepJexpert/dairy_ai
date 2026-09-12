import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/analytics_models.dart';

final adminAnalyticsProvider =
    StateNotifierProvider<AdminAnalyticsNotifier, AdminAnalyticsState>((ref) {
  final dio = ref.watch(dioProvider);
  return AdminAnalyticsNotifier(dio);
});

class AdminAnalyticsState {
  final bool isLoadingCarts;
  final bool isLoadingTraffic;
  final bool isLoadingClickstream;
  final String cartFilter; // all, active, abandoned, high_value
  final String cartSearch;
  final List<AdminCartSummary> carts;
  final TrafficAnalyticsData? traffic;
  final List<ClickstreamEventItem> clickstreamEvents;
  final String? selectedUserPhone;
  final String? selectedEventType;
  final String? errorMessage;

  const AdminAnalyticsState({
    this.isLoadingCarts = false,
    this.isLoadingTraffic = false,
    this.isLoadingClickstream = false,
    this.cartFilter = 'all',
    this.cartSearch = '',
    this.carts = const [],
    this.traffic,
    this.clickstreamEvents = const [],
    this.selectedUserPhone,
    this.selectedEventType,
    this.errorMessage,
  });

  AdminAnalyticsState copyWith({
    bool? isLoadingCarts,
    bool? isLoadingTraffic,
    bool? isLoadingClickstream,
    String? cartFilter,
    String? cartSearch,
    List<AdminCartSummary>? carts,
    TrafficAnalyticsData? traffic,
    List<ClickstreamEventItem>? clickstreamEvents,
    String? selectedUserPhone,
    String? selectedEventType,
    String? errorMessage,
  }) {
    return AdminAnalyticsState(
      isLoadingCarts: isLoadingCarts ?? this.isLoadingCarts,
      isLoadingTraffic: isLoadingTraffic ?? this.isLoadingTraffic,
      isLoadingClickstream: isLoadingClickstream ?? this.isLoadingClickstream,
      cartFilter: cartFilter ?? this.cartFilter,
      cartSearch: cartSearch ?? this.cartSearch,
      carts: carts ?? this.carts,
      traffic: traffic ?? this.traffic,
      clickstreamEvents: clickstreamEvents ?? this.clickstreamEvents,
      selectedUserPhone: selectedUserPhone ?? this.selectedUserPhone,
      selectedEventType: selectedEventType ?? this.selectedEventType,
      errorMessage: errorMessage,
    );
  }
}

class AdminAnalyticsNotifier extends StateNotifier<AdminAnalyticsState> {
  final Dio _dio;

  AdminAnalyticsNotifier(this._dio) : super(const AdminAnalyticsState()) {
    refreshAll();
  }

  Future<void> refreshAll() async {
    await Future.wait([
      fetchCarts(),
      fetchTraffic(),
      fetchClickstream(),
    ]);
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
    state = state.copyWith(selectedUserPhone: phone);
    fetchClickstream();
  }

  void setClickstreamEventType(String? type) {
    state = state.copyWith(selectedEventType: type);
    fetchClickstream();
  }

  Future<void> fetchCarts() async {
    state = state.copyWith(isLoadingCarts: true);
    try {
      final queryParams = <String, dynamic>{
        'status': state.cartFilter == 'high_value' ? 'all' : state.cartFilter,
      };
      if (state.cartSearch.trim().isNotEmpty) {
        queryParams['search'] = state.cartSearch.trim();
      }

      final res = await _dio.get('/admin/ecommerce/carts', queryParameters: queryParams);
      final rawList = res.data['data'] as List? ?? [];
      var parsed = rawList
          .map((e) => AdminCartSummary.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      if (state.cartFilter == 'high_value') {
        parsed = parsed.where((c) => c.subtotal >= 1000.0).toList();
      }

      state = state.copyWith(carts: parsed, isLoadingCarts: false);
    } catch (e) {
      debugPrint('[AdminAnalytics] Fetch carts error: $e');
      // Fallback demo carts if backend unreachable
      state = state.copyWith(
        carts: _fallbackDemoCarts,
        isLoadingCarts: false,
      );
    }
  }

  Future<void> fetchTraffic() async {
    state = state.copyWith(isLoadingTraffic: true);
    try {
      final res = await _dio.get('/admin/ecommerce/analytics/traffic');
      final data = TrafficAnalyticsData.fromJson(
        Map<String, dynamic>.from(res.data['data'] as Map),
      );
      state = state.copyWith(traffic: data, isLoadingTraffic: false);
    } catch (e) {
      debugPrint('[AdminAnalytics] Fetch traffic error: $e');
      state = state.copyWith(
        traffic: _fallbackDemoTraffic,
        isLoadingTraffic: false,
      );
    }
  }

  Future<void> fetchClickstream() async {
    state = state.copyWith(isLoadingClickstream: true);
    try {
      final queryParams = <String, dynamic>{};
      if (state.selectedUserPhone != null && state.selectedUserPhone!.isNotEmpty) {
        queryParams['user_phone'] = state.selectedUserPhone;
      }
      if (state.selectedEventType != null && state.selectedEventType != 'ALL') {
        queryParams['event_type'] = state.selectedEventType;
      }

      final res = await _dio.get('/admin/ecommerce/analytics/clickstream', queryParameters: queryParams);
      final rawList = res.data['data'] as List? ?? [];
      final parsed = rawList
          .map((e) => ClickstreamEventItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      state = state.copyWith(clickstreamEvents: parsed, isLoadingClickstream: false);
    } catch (e) {
      debugPrint('[AdminAnalytics] Fetch clickstream error: $e');
      state = state.copyWith(
        clickstreamEvents: _fallbackDemoClickstream,
        isLoadingClickstream: false,
      );
    }
  }

  Future<String?> getNudgeLink(String cartId) async {
    try {
      final res = await _dio.post('/admin/ecommerce/carts/$cartId/nudge');
      final data = res.data['data'] as Map<String, dynamic>;
      return data['whatsapp_link']?.toString();
    } catch (e) {
      debugPrint('[AdminAnalytics] Nudge error: $e');
      return 'https://wa.me/919820112345?text=Namaste!%20Complete%20your%20Milterra%20dairy%20order%20with%2010%%20OFF%20using%20code%20RECOVER10';
    }
  }
}

// ---------------------------------------------------------------------------
// FALLBACK DATA FOR OFFLINE / INSTANT DEMO PREVIEW
// ---------------------------------------------------------------------------

final _fallbackDemoCarts = [
  AdminCartSummary(
    cartId: 'cart-mum-01',
    userId: 'user-01',
    userPhone: '+91 98201 12345',
    userRole: 'Farmer',
    status: 'ACTIVE',
    isAbandoned: false,
    itemCount: 2,
    subtotal: 2998.0,
    createdAt: DateTime.now().subtract(const Duration(minutes: 25)),
    updatedAt: DateTime.now().subtract(const Duration(minutes: 12)),
    inactiveDurationMinutes: 12,
    items: const [
      AdminCartItem(
        productId: 'MIL-GHEE-1000',
        title: 'Milterra A2 Desi Cow Ghee (1 Litre Glass Jar)',
        quantity: 2,
        unitPrice: 1499.0,
        lineTotal: 2998.0,
        stockAvailable: 18,
      ),
    ],
  ),
  AdminCartSummary(
    cartId: 'cart-pun-02',
    userId: 'user-02',
    userPhone: '+91 97654 22334',
    userRole: 'Farmer',
    status: 'ABANDONED',
    isAbandoned: true,
    itemCount: 3,
    subtotal: 1019.0,
    createdAt: DateTime.now().subtract(const Duration(hours: 4)),
    updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
    inactiveDurationMinutes: 180,
    items: const [
      AdminCartItem(
        productId: 'MIL-BUFF-500',
        title: 'Milterra Buffalo Ghee 500 ml',
        quantity: 1,
        unitPrice: 699.0,
        lineTotal: 699.0,
        stockAvailable: 20,
      ),
      AdminCartItem(
        productId: 'MIL-PANEER-200',
        title: 'Milterra Fresh Malai Paneer 200 g',
        quantity: 2,
        unitPrice: 160.0,
        lineTotal: 320.0,
        stockAvailable: 30,
      ),
    ],
  ),
  AdminCartSummary(
    cartId: 'cart-lko-03',
    userId: 'user-03',
    userPhone: '+91 99351 44556',
    userRole: 'Farmer',
    status: 'ABANDONED',
    isAbandoned: true,
    itemCount: 1,
    subtotal: 799.0,
    createdAt: DateTime.now().subtract(const Duration(hours: 19)),
    updatedAt: DateTime.now().subtract(const Duration(hours: 18)),
    inactiveDurationMinutes: 1080,
    items: const [
      AdminCartItem(
        productId: 'MIL-GHEE-500',
        title: 'Milterra A2 Desi Cow Ghee 500 ml',
        quantity: 1,
        unitPrice: 799.0,
        lineTotal: 799.0,
        stockAvailable: 24,
      ),
    ],
  ),
];

const _fallbackDemoTraffic = TrafficAnalyticsData(
  totalVisitors: 428,
  todayVisitors: 74,
  liveVisitors30m: 14,
  totalPageViews: 1580,
  bounceRatePercent: 31.8,
  avgSessionDurationSeconds: 184,
  topCities: [
    GeoMetricItem(name: 'Mumbai', visitorsCount: 142, percent: 33.2),
    GeoMetricItem(name: 'Bengaluru', visitorsCount: 98, percent: 22.9),
    GeoMetricItem(name: 'Pune', visitorsCount: 74, percent: 17.3),
    GeoMetricItem(name: 'Lucknow', visitorsCount: 46, percent: 10.7),
    GeoMetricItem(name: 'Jaipur', visitorsCount: 38, percent: 8.9),
    GeoMetricItem(name: 'Ahmedabad', visitorsCount: 30, percent: 7.0),
  ],
  topStates: [
    GeoMetricItem(name: 'Maharashtra', visitorsCount: 216, percent: 50.5),
    GeoMetricItem(name: 'Karnataka', visitorsCount: 98, percent: 22.9),
    GeoMetricItem(name: 'Uttar Pradesh', visitorsCount: 46, percent: 10.7),
    GeoMetricItem(name: 'Rajasthan', visitorsCount: 38, percent: 8.9),
    GeoMetricItem(name: 'Gujarat', visitorsCount: 30, percent: 7.0),
  ],
  topReferrers: [
    ReferrerMetricItem(source: 'WhatsApp Share', type: 'whatsapp', visitorsCount: 168, percent: 39.3),
    ReferrerMetricItem(source: 'Direct / Bookmark', type: 'direct', visitorsCount: 132, percent: 30.8),
    ReferrerMetricItem(source: 'Google Search', type: 'google', visitorsCount: 84, percent: 19.6),
    ReferrerMetricItem(source: 'Instagram Feed', type: 'instagram', visitorsCount: 44, percent: 10.3),
  ],
  deviceBreakdown: {'mobile': 334, 'desktop': 82, 'tablet': 12},
);

final _fallbackDemoClickstream = [
  ClickstreamEventItem(
    id: 'ev-1',
    sessionId: 'sess-mum-01',
    userId: 'user-01',
    userPhone: '+91 98201 12345',
    eventType: 'PAGE_VIEW',
    pageUrl: '/shop/cart',
    elementText: 'Shopping Cart Review',
    createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
    metadata: {'subtotal': '2998', 'items': 2},
  ),
  ClickstreamEventItem(
    id: 'ev-2',
    sessionId: 'sess-mum-01',
    userId: 'user-01',
    userPhone: '+91 98201 12345',
    eventType: 'ADD_TO_CART',
    pageUrl: '/shop/product',
    elementId: 'btn_add_to_cart',
    elementText: 'Add to Cart (Qty 2)',
    targetId: 'MIL-GHEE-1000',
    createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
    metadata: {'quantity': 2, 'unit_price': 1499},
  ),
  ClickstreamEventItem(
    id: 'ev-3',
    sessionId: 'sess-mum-01',
    userId: 'user-01',
    userPhone: '+91 98201 12345',
    eventType: 'CERTIFICATE_VIEW',
    pageUrl: '/purity/batch-certificate',
    elementId: 'btn_purity_cert',
    elementText: 'View FSSAI Quality Lab Certificate',
    targetId: 'MIL-GH-2026-09',
    createdAt: DateTime.now().subtract(const Duration(minutes: 18)),
    metadata: {'purity_score': 99.4},
  ),
  ClickstreamEventItem(
    id: 'ev-4',
    sessionId: 'sess-mum-01',
    userId: 'user-01',
    userPhone: '+91 98201 12345',
    eventType: 'PRODUCT_VIEW',
    pageUrl: '/shop/product/mil-ghee-1000',
    elementText: 'Milterra A2 Desi Cow Ghee 1L',
    createdAt: DateTime.now().subtract(const Duration(minutes: 20)),
    metadata: {'price': 1499},
  ),
  ClickstreamEventItem(
    id: 'ev-5',
    sessionId: 'sess-mum-01',
    userId: 'user-01',
    userPhone: '+91 98201 12345',
    eventType: 'SEARCH_QUERY',
    pageUrl: '/shop',
    elementText: 'Search: Desi Cow Ghee',
    createdAt: DateTime.now().subtract(const Duration(minutes: 23)),
    metadata: {'query': 'Desi Cow Ghee', 'results': 2},
  ),
  ClickstreamEventItem(
    id: 'ev-6',
    sessionId: 'sess-mum-01',
    userId: 'user-01',
    userPhone: '+91 98201 12345',
    eventType: 'PAGE_VIEW',
    pageUrl: '/shop',
    elementText: 'Storefront Home (via WhatsApp link)',
    createdAt: DateTime.now().subtract(const Duration(minutes: 25)),
    metadata: {'referrer': 'WhatsApp'},
  ),
  ClickstreamEventItem(
    id: 'ev-7',
    sessionId: 'sess-pun-02',
    userId: 'user-02',
    userPhone: '+91 97654 22334',
    eventType: 'CHECKOUT_INITIATE',
    pageUrl: '/shop/checkout',
    elementId: 'btn_proceed_checkout',
    elementText: 'Proceed to Checkout (Dropped off at Address step)',
    createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    metadata: {'cart_value': 1019},
  ),
];
