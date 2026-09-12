import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/providers/auth_provider.dart';

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  final dio = ref.watch(dioProvider);
  final service = AnalyticsService(dio);
  service.initSession();
  return service;
});

class AnalyticsService {
  final Dio _dio;
  late final String sessionId;
  final List<Map<String, dynamic>> _eventBuffer = [];
  Timer? _flushTimer;
  bool _sessionRegistered = false;

  AnalyticsService(this._dio) {
    sessionId = 'sess-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(999999)}';
    _startFlushTimer();
  }

  void _startFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(const Duration(seconds: 4), (_) => flush());
  }

  void dispose() {
    _flushTimer?.cancel();
    flush();
  }

  /// Register or heartbeat session with the backend.
  Future<void> initSession({String landingPage = '/shop'}) async {
    if (_sessionRegistered) return;
    try {
      String? utmSource;
      String? utmMedium;
      String? utmCampaign;
      String? referrer;

      if (kIsWeb) {
        final currentUri = Uri.base;
        utmSource = currentUri.queryParameters['utm_source'];
        utmMedium = currentUri.queryParameters['utm_medium'];
        utmCampaign = currentUri.queryParameters['utm_campaign'];
        referrer = currentUri.queryParameters['ref'] ?? 'direct';
      }

      await _dio.post(
        '/analytics/visit',
        data: {
          'session_id': sessionId,
          'landing_page': landingPage,
          'device_type': kIsWeb ? 'desktop' : 'mobile',
          'browser': kIsWeb ? 'Web Browser' : 'Flutter App',
          'os': defaultTargetPlatform.name,
          'referrer': referrer,
          'utm_source': utmSource,
          'utm_medium': utmMedium,
          'utm_campaign': utmCampaign,
          'country': 'India',
        },
      );
      _sessionRegistered = true;
    } catch (e) {
      debugPrint('[Analytics] Visit registration failed: $e');
    }
  }

  /// Track a screen or page view.
  void trackPageView(String route, {String? title, Map<String, dynamic>? metadata}) {
    _enqueueEvent({
      'event_type': 'PAGE_VIEW',
      'page_url': route,
      'element_text': title ?? route,
      'metadata': metadata,
    });
  }

  /// Track product detail clicks.
  void trackProductView(String productId, String title, {double? price}) {
    _enqueueEvent({
      'event_type': 'PRODUCT_VIEW',
      'page_url': '/shop/product/$productId',
      'target_id': productId,
      'element_id': 'product_card_$productId',
      'element_text': title,
      'metadata': price != null ? {'price': price} : null,
    });
  }

  /// Track adding items to shopping cart.
  void trackAddToCart(String productId, String title, int quantity, double price) {
    _enqueueEvent({
      'event_type': 'ADD_TO_CART',
      'page_url': '/shop/cart',
      'target_id': productId,
      'element_id': 'btn_add_to_cart',
      'element_text': 'Add to Cart: $title',
      'metadata': {
        'quantity': quantity,
        'unit_price': price,
        'line_total': price * quantity,
      },
    });
  }

  /// Track removing items from shopping cart.
  void trackRemoveFromCart(String productId, String title) {
    _enqueueEvent({
      'event_type': 'REMOVE_FROM_CART',
      'page_url': '/shop/cart',
      'target_id': productId,
      'element_id': 'btn_remove_cart_item',
      'element_text': 'Remove: $title',
    });
  }

  /// Track search queries entered by the user.
  void trackSearch(String query, int resultsCount) {
    _enqueueEvent({
      'event_type': 'SEARCH_QUERY',
      'page_url': '/shop',
      'element_id': 'store_search_input',
      'element_text': 'Search: $query',
      'metadata': {
        'query': query,
        'results_count': resultsCount,
      },
    });
  }

  /// Track generic button or interactive action clicks.
  void trackButtonClick(String elementId, String label, {String pageUrl = '/shop', Map<String, dynamic>? metadata}) {
    _enqueueEvent({
      'event_type': 'BUTTON_CLICK',
      'page_url': pageUrl,
      'element_id': elementId,
      'element_text': label,
      'metadata': metadata,
    });
  }

  /// Track lab test certificate views.
  void trackCertificateView(String batchNumber, String productTitle) {
    _enqueueEvent({
      'event_type': 'CERTIFICATE_VIEW',
      'page_url': '/purity/batch-certificate',
      'target_id': batchNumber,
      'element_id': 'btn_view_certificate',
      'element_text': 'View Quality Certificate: $batchNumber',
      'metadata': {'product_title': productTitle},
    });
  }

  /// Track checkout milestones.
  void trackCheckoutStep(String step, {Map<String, dynamic>? metadata}) {
    _enqueueEvent({
      'event_type': 'CHECKOUT_INITIATE',
      'page_url': '/shop/checkout',
      'element_id': 'checkout_step_$step',
      'element_text': 'Checkout Step: $step',
      'metadata': metadata,
    });
  }

  void _enqueueEvent(Map<String, dynamic> event) {
    event['session_id'] = sessionId;
    _eventBuffer.add(event);
    if (_eventBuffer.length >= 10) {
      flush();
    }
  }

  /// Flush queued events to backend non-blockingly.
  Future<void> flush() async {
    if (_eventBuffer.isEmpty) return;

    final batch = List<Map<String, dynamic>>.from(_eventBuffer);
    _eventBuffer.clear();

    try {
      await _dio.post(
        '/analytics/events',
        data: {'events': batch},
      );
    } catch (e) {
      debugPrint('[Analytics] Flush error: $e');
      // If error occurs, re-add batch if buffer isn't too large (up to 50 items)
      if (_eventBuffer.length < 50) {
        _eventBuffer.insertAll(0, batch);
      }
    }
  }
}

/// Route observer that automatically logs page views to the analytics service.
class AnalyticsRouteObserver extends NavigatorObserver {
  final AnalyticsService _analytics;

  AnalyticsRouteObserver(this._analytics);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    final routeName = route.settings.name ?? route.settings.arguments?.toString();
    if (routeName != null && routeName.isNotEmpty) {
      _analytics.trackPageView(routeName);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      final routeName = newRoute.settings.name ?? newRoute.settings.arguments?.toString();
      if (routeName != null && routeName.isNotEmpty) {
        _analytics.trackPageView(routeName);
      }
    }
  }
}
