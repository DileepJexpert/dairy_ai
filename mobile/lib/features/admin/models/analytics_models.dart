class AdminCartItem {
  final String productId;
  final String title;
  final String? primaryImage;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final int stockAvailable;

  const AdminCartItem({
    required this.productId,
    required this.title,
    this.primaryImage,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.stockAvailable = 0,
  });

  factory AdminCartItem.fromJson(Map<String, dynamic> json) {
    return AdminCartItem(
      productId: json['product_id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Product',
      primaryImage: json['primary_image']?.toString(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: double.tryParse(json['unit_price']?.toString() ?? '0') ?? 0.0,
      lineTotal: double.tryParse(json['line_total']?.toString() ?? '0') ?? 0.0,
      stockAvailable: (json['stock_available'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminCartSummary {
  final String cartId;
  final String userId;
  final String userPhone;
  final String userRole;
  final String status;
  final bool isAbandoned;
  final int itemCount;
  final double subtotal;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int inactiveDurationMinutes;
  final List<AdminCartItem> items;

  const AdminCartSummary({
    required this.cartId,
    required this.userId,
    required this.userPhone,
    required this.userRole,
    required this.status,
    required this.isAbandoned,
    required this.itemCount,
    required this.subtotal,
    required this.createdAt,
    required this.updatedAt,
    required this.inactiveDurationMinutes,
    required this.items,
  });

  factory AdminCartSummary.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? [];
    return AdminCartSummary(
      cartId: json['cart_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userPhone: json['user_phone']?.toString() ?? '',
      userRole: json['user_role']?.toString() ?? 'farmer',
      status: json['status']?.toString() ?? 'ACTIVE',
      isAbandoned: json['is_abandoned'] == true,
      itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0.0,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
      inactiveDurationMinutes: (json['inactive_duration_minutes'] as num?)?.toInt() ?? 0,
      items: rawItems.map((e) => AdminCartItem.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    );
  }
}

class GeoMetricItem {
  final String name;
  final int visitorsCount;
  final double percent;

  const GeoMetricItem({
    required this.name,
    required this.visitorsCount,
    required this.percent,
  });

  factory GeoMetricItem.fromJson(Map<String, dynamic> json) {
    return GeoMetricItem(
      name: json['name']?.toString() ?? '',
      visitorsCount: (json['visitors_count'] as num?)?.toInt() ?? 0,
      percent: (json['percent'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ReferrerMetricItem {
  final String source;
  final String type;
  final int visitorsCount;
  final double percent;

  const ReferrerMetricItem({
    required this.source,
    required this.type,
    required this.visitorsCount,
    required this.percent,
  });

  factory ReferrerMetricItem.fromJson(Map<String, dynamic> json) {
    return ReferrerMetricItem(
      source: json['source']?.toString() ?? '',
      type: json['type']?.toString() ?? 'direct',
      visitorsCount: (json['visitors_count'] as num?)?.toInt() ?? 0,
      percent: (json['percent'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class TrafficAnalyticsData {
  final int totalVisitors;
  final int todayVisitors;
  final int liveVisitors30m;
  final int totalPageViews;
  final double bounceRatePercent;
  final int avgSessionDurationSeconds;
  final List<GeoMetricItem> topCities;
  final List<GeoMetricItem> topStates;
  final List<ReferrerMetricItem> topReferrers;
  final Map<String, int> deviceBreakdown;

  const TrafficAnalyticsData({
    required this.totalVisitors,
    required this.todayVisitors,
    required this.liveVisitors30m,
    required this.totalPageViews,
    required this.bounceRatePercent,
    required this.avgSessionDurationSeconds,
    required this.topCities,
    required this.topStates,
    required this.topReferrers,
    required this.deviceBreakdown,
  });

  factory TrafficAnalyticsData.fromJson(Map<String, dynamic> json) {
    final rawCities = json['top_cities'] as List? ?? [];
    final rawStates = json['top_states'] as List? ?? [];
    final rawRefs = json['top_referrers'] as List? ?? [];
    final rawDevices = json['device_breakdown'] as Map? ?? {};

    return TrafficAnalyticsData(
      totalVisitors: (json['total_visitors'] as num?)?.toInt() ?? 0,
      todayVisitors: (json['today_visitors'] as num?)?.toInt() ?? 0,
      liveVisitors30m: (json['live_visitors_30m'] as num?)?.toInt() ?? 0,
      totalPageViews: (json['total_page_views'] as num?)?.toInt() ?? 0,
      bounceRatePercent: (json['bounce_rate_percent'] as num?)?.toDouble() ?? 0.0,
      avgSessionDurationSeconds: (json['avg_session_duration_seconds'] as num?)?.toInt() ?? 180,
      topCities: rawCities.map((e) => GeoMetricItem.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      topStates: rawStates.map((e) => GeoMetricItem.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      topReferrers: rawRefs.map((e) => ReferrerMetricItem.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      deviceBreakdown: rawDevices.map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
    );
  }
}

class ClickstreamEventItem {
  final String id;
  final String sessionId;
  final String? userId;
  final String? userPhone;
  final String eventType;
  final String pageUrl;
  final String? elementId;
  final String? elementText;
  final String? targetId;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  const ClickstreamEventItem({
    required this.id,
    required this.sessionId,
    this.userId,
    this.userPhone,
    required this.eventType,
    required this.pageUrl,
    this.elementId,
    this.elementText,
    this.targetId,
    this.metadata,
    required this.createdAt,
  });

  factory ClickstreamEventItem.fromJson(Map<String, dynamic> json) {
    return ClickstreamEventItem(
      id: json['id']?.toString() ?? '',
      sessionId: json['session_id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      userPhone: json['user_phone']?.toString(),
      eventType: json['event_type']?.toString() ?? 'PAGE_VIEW',
      pageUrl: json['page_url']?.toString() ?? '/',
      elementId: json['element_id']?.toString(),
      elementText: json['element_text']?.toString(),
      targetId: json['target_id']?.toString(),
      metadata: json['metadata'] is Map ? Map<String, dynamic>.from(json['metadata'] as Map) : null,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class SessionCartItem {
  final String productId;
  final String title;
  final String? primaryImage;
  final int quantity;
  final double unitPrice;
  final double lineTotal;

  const SessionCartItem({
    required this.productId,
    required this.title,
    this.primaryImage,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  factory SessionCartItem.fromJson(Map<String, dynamic> json) {
    return SessionCartItem(
      productId: json['product_id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Product',
      primaryImage: json['primary_image']?.toString(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: double.tryParse(json['unit_price']?.toString() ?? '0') ?? 0.0,
      lineTotal: double.tryParse(json['line_total']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class CustomerSessionJourney {
  final String sessionId;
  final String? userId;
  final String? customerName;
  final String? customerPhone;
  final String city;
  final String state;
  final String country;
  final String? ipAddress;
  final String deviceType;
  final String? browser;
  final String? os;
  final String? referrer;
  final String referrerType;
  final DateTime startedAt;
  final DateTime lastSeenAt;
  final int durationMinutes;
  final int inactiveMinutes;
  final bool isLive;
  final int pageViewsCount;
  final String farthestStage;
  final String farthestStageLabel;
  final String stuckStatus;
  final String stuckStatusLabel;
  final String stuckDiagnosis;
  final String lastPageUrl;
  final String lastActionText;
  final String? cartId;
  final int cartItemCount;
  final double cartSubtotal;
  final List<SessionCartItem> cartItems;
  final List<Map<String, dynamic>> journeySteps;

  const CustomerSessionJourney({
    required this.sessionId,
    this.userId,
    this.customerName,
    this.customerPhone,
    required this.city,
    required this.state,
    required this.country,
    this.ipAddress,
    required this.deviceType,
    this.browser,
    this.os,
    this.referrer,
    required this.referrerType,
    required this.startedAt,
    required this.lastSeenAt,
    required this.durationMinutes,
    required this.inactiveMinutes,
    required this.isLive,
    required this.pageViewsCount,
    required this.farthestStage,
    required this.farthestStageLabel,
    required this.stuckStatus,
    required this.stuckStatusLabel,
    required this.stuckDiagnosis,
    required this.lastPageUrl,
    required this.lastActionText,
    this.cartId,
    required this.cartItemCount,
    required this.cartSubtotal,
    required this.cartItems,
    required this.journeySteps,
  });

  factory CustomerSessionJourney.fromJson(Map<String, dynamic> json) {
    final rawItems = json['cart_items'] as List? ?? [];
    final rawSteps = json['journey_steps'] as List? ?? [];

    return CustomerSessionJourney(
      sessionId: json['session_id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      customerName: json['customer_name']?.toString(),
      customerPhone: json['customer_phone']?.toString(),
      city: json['city']?.toString() ?? 'Unknown',
      state: json['state']?.toString() ?? 'Unknown',
      country: json['country']?.toString() ?? 'India',
      ipAddress: json['ip_address']?.toString(),
      deviceType: json['device_type']?.toString() ?? 'mobile',
      browser: json['browser']?.toString(),
      os: json['os']?.toString(),
      referrer: json['referrer']?.toString(),
      referrerType: json['referrer_type']?.toString() ?? 'direct',
      startedAt: DateTime.tryParse(json['started_at']?.toString() ?? '') ?? DateTime.now(),
      lastSeenAt: DateTime.tryParse(json['last_seen_at']?.toString() ?? '') ?? DateTime.now(),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 1,
      inactiveMinutes: (json['inactive_minutes'] as num?)?.toInt() ?? 0,
      isLive: json['is_live'] == true,
      pageViewsCount: (json['page_views_count'] as num?)?.toInt() ?? 1,
      farthestStage: json['farthest_stage']?.toString() ?? 'LANDED',
      farthestStageLabel: json['farthest_stage_label']?.toString() ?? '1. Landed on Store',
      stuckStatus: json['stuck_status']?.toString() ?? 'ACTIVE_BROWSING',
      stuckStatusLabel: json['stuck_status_label']?.toString() ?? 'Active Browsing',
      stuckDiagnosis: json['stuck_diagnosis']?.toString() ?? 'Browsing store',
      lastPageUrl: json['last_page_url']?.toString() ?? '/shop',
      lastActionText: json['last_action_text']?.toString() ?? 'Browsing',
      cartId: json['cart_id']?.toString(),
      cartItemCount: (json['cart_item_count'] as num?)?.toInt() ?? 0,
      cartSubtotal: double.tryParse(json['cart_subtotal']?.toString() ?? '0') ?? 0.0,
      cartItems: rawItems.map((e) => SessionCartItem.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      journeySteps: rawSteps.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
    );
  }
}

class FunnelStepItem {
  final String stageKey;
  final String stageName;
  final int visitorCount;
  final double conversionPercent;
  final int dropOffCount;
  final double dropOffPercent;

  const FunnelStepItem({
    required this.stageKey,
    required this.stageName,
    required this.visitorCount,
    required this.conversionPercent,
    required this.dropOffCount,
    required this.dropOffPercent,
  });

  factory FunnelStepItem.fromJson(Map<String, dynamic> json) {
    return FunnelStepItem(
      stageKey: json['stage_key']?.toString() ?? '',
      stageName: json['stage_name']?.toString() ?? '',
      visitorCount: (json['visitor_count'] as num?)?.toInt() ?? 0,
      conversionPercent: (json['conversion_percent'] as num?)?.toDouble() ?? 0.0,
      dropOffCount: (json['drop_off_count'] as num?)?.toInt() ?? 0,
      dropOffPercent: (json['drop_off_percent'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class CustomerSessionsData {
  final int totalVisitors;
  final int liveVisitorsCount;
  final int stuckVisitorsCount;
  final int cartAbandonedCount;
  final int checkoutStuckCount;
  final int convertedCount;
  final List<FunnelStepItem> funnelSteps;
  final List<CustomerSessionJourney> sessions;

  const CustomerSessionsData({
    required this.totalVisitors,
    required this.liveVisitorsCount,
    required this.stuckVisitorsCount,
    required this.cartAbandonedCount,
    required this.checkoutStuckCount,
    required this.convertedCount,
    required this.funnelSteps,
    required this.sessions,
  });

  factory CustomerSessionsData.fromJson(Map<String, dynamic> json) {
    final rawFunnel = json['funnel_steps'] as List? ?? [];
    final rawSessions = json['sessions'] as List? ?? [];

    return CustomerSessionsData(
      totalVisitors: (json['total_visitors'] as num?)?.toInt() ?? 0,
      liveVisitorsCount: (json['live_visitors_count'] as num?)?.toInt() ?? 0,
      stuckVisitorsCount: (json['stuck_visitors_count'] as num?)?.toInt() ?? 0,
      cartAbandonedCount: (json['cart_abandoned_count'] as num?)?.toInt() ?? 0,
      checkoutStuckCount: (json['checkout_stuck_count'] as num?)?.toInt() ?? 0,
      convertedCount: (json['converted_count'] as num?)?.toInt() ?? 0,
      funnelSteps: rawFunnel.map((e) => FunnelStepItem.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      sessions: rawSessions.map((e) => CustomerSessionJourney.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    );
  }
}

