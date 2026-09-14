import 'package:dio/dio.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/features/cart/models/cart_models.dart';

/// Single item within a placed order.
class StoreOrderItem {
  final String productId;
  final String title;
  final String? packSize;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final String? image;
  final String fulfillmentStatus;

  const StoreOrderItem({
    required this.productId,
    required this.title,
    this.packSize,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.image,
    this.fulfillmentStatus = 'PENDING_PAYMENT',
  });

  factory StoreOrderItem.fromCartItem(CartItem item) {
    return StoreOrderItem(
      productId: item.productId,
      title: item.title,
      packSize: null,
      quantity: item.quantity,
      unitPrice: item.currentPrice,
      lineTotal: item.lineTotal,
      image: item.primaryImage,
      fulfillmentStatus: 'PENDING_PAYMENT',
    );
  }

  factory StoreOrderItem.fromMap(Map<String, dynamic> map) {
    return StoreOrderItem(
      productId: map['product_id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Dairy Item',
      packSize: map['pack_size']?.toString(),
      quantity: int.tryParse(map['quantity']?.toString() ?? '1') ?? 1,
      unitPrice: double.tryParse(map['unit_price']?.toString() ?? '0') ?? 0.0,
      lineTotal: double.tryParse(map['line_total']?.toString() ?? '0') ?? 0.0,
      image: map['image']?.toString(),
      fulfillmentStatus:
          map['fulfillment_status']?.toString() ?? 'PENDING_PAYMENT',
    );
  }

  Map<String, dynamic> toMap() => {
        'product_id': productId,
        'title': title,
        'pack_size': packSize,
        'quantity': quantity,
        'unit_price': unitPrice.toStringAsFixed(2),
        'line_total': lineTotal.toStringAsFixed(2),
        'image': image,
        'fulfillment_status': fulfillmentStatus,
      };
}

/// Chronological checkpoint event on the courier tracking timeline.
class OrderTimelineEvent {
  final String time;
  final String title;
  final String location;
  final String remarks;
  final String status;

  const OrderTimelineEvent({
    required this.time,
    required this.title,
    required this.location,
    required this.remarks,
    required this.status,
  });

  factory OrderTimelineEvent.fromMap(Map<String, dynamic> map) {
    return OrderTimelineEvent(
      time: map['time']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      location: map['location']?.toString() ?? '',
      remarks: map['remarks']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'time': time,
        'title': title,
        'location': location,
        'remarks': remarks,
        'status': status,
      };
}

/// Complete representation of an e-commerce order.
class StoreOrder {
  final String id;
  final bool isPrelaunchInterest;
  final String createdAt;
  final String
      status; // CONFIRMED, PACKED, DISPATCHED, OUT_FOR_DELIVERY, DELIVERED, CANCELLED
  final String paymentStatus; // PAID, PENDING, FAILED
  final String paymentMethod; // Milterra Wallet, COD, UPI, Card
  final String carrier; // DTDC Express, Delhivery, Blue Dart, Milterra Direct
  final String trackingNumber; // e.g. DTDC-7749210
  final String estimatedDelivery;
  final Map<String, dynamic> address;
  final List<StoreOrderItem> items;
  final double subtotal;
  final double deliveryFee;
  final double discount;
  final double total;
  final List<OrderTimelineEvent> timeline;

  const StoreOrder({
    this.isPrelaunchInterest = false,
    required this.id,
    required this.createdAt,
    this.status = 'PENDING_PAYMENT',
    this.paymentStatus = 'PENDING',
    this.paymentMethod = 'Not specified',
    this.carrier = 'Not assigned',
    this.trackingNumber = '',
    this.estimatedDelivery = 'Not scheduled',
    required this.address,
    required this.items,
    required this.subtotal,
    this.deliveryFee = 0.0,
    this.discount = 0.0,
    required this.total,
    this.timeline = const [],
  });

  factory StoreOrder.fromMap(Map<String, dynamic> j) => StoreOrder(
        isPrelaunchInterest: j['is_prelaunch_interest'] == true,
        id: j['id'].toString(),
        createdAt: j['created_at'].toString(),
        status: j['status'].toString(),
        paymentStatus: j['payment_status'].toString(),
        paymentMethod: j['payment_method']?.toString() ?? 'Not specified',
        carrier: j['carrier']?.toString().isNotEmpty == true
            ? j['carrier'].toString()
            : 'Not assigned',
        trackingNumber: j['tracking_number']?.toString() ?? '',
        estimatedDelivery: j['is_prelaunch_interest'] == true
            ? 'Pre-launch interest · No delivery scheduled'
            : 'Not scheduled',
        address: Map<String, dynamic>.from(j['address'] as Map),
        items: (j['items'] as List)
            .map((i) => StoreOrderItem.fromMap(Map<String, dynamic>.from(i)))
            .toList(),
        subtotal: double.parse(j['subtotal'].toString()),
        total: double.parse(j['total'].toString()),
        deliveryFee: double.tryParse(j['delivery_fee'].toString()) ?? 0,
        discount: double.tryParse(j['discount'].toString()) ?? 0,
        timeline: (j['timeline'] as List? ?? [])
            .map(
                (e) => OrderTimelineEvent.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
      );

  int get currentStep {
    final s = status.toUpperCase();
    if (s.contains('DELIVERED')) return 4;
    if (s.contains('OUT') || s.contains('TRANSIT')) return 3;
    if (s.contains('DISPATCH') || s.contains('SHIP')) return 2;
    if (s.contains('PACK')) return 1;
    return 0; // CONFIRMED or PLACED
  }

  StoreOrder copyWith({
    String? id,
    String? createdAt,
    String? status,
    String? paymentStatus,
    String? paymentMethod,
    String? carrier,
    String? trackingNumber,
    String? estimatedDelivery,
    Map<String, dynamic>? address,
    List<StoreOrderItem>? items,
    double? subtotal,
    double? deliveryFee,
    double? discount,
    double? total,
    List<OrderTimelineEvent>? timeline,
  }) {
    return StoreOrder(
      isPrelaunchInterest: isPrelaunchInterest,
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      carrier: carrier ?? this.carrier,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      estimatedDelivery: estimatedDelivery ?? this.estimatedDelivery,
      address: address ?? this.address,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      discount: discount ?? this.discount,
      total: total ?? this.total,
      timeline: timeline ?? this.timeline,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'created_at': createdAt,
        'status': status,
        'payment_status': paymentStatus,
        'payment_method': paymentMethod,
        'carrier': carrier,
        'tracking_number': trackingNumber,
        'estimated_delivery': estimatedDelivery,
        'address': address,
        'items': items.map((e) => e.toMap()).toList(),
        'subtotal': subtotal.toStringAsFixed(2),
        'delivery_fee': deliveryFee.toStringAsFixed(2),
        'discount': discount.toStringAsFixed(2),
        'total': total.toStringAsFixed(2),
        'timeline': timeline.map((e) => e.toMap()).toList(),
      };
}

final orderLoadStateProvider =
    StateProvider<AsyncValue<void>>((ref) => const AsyncData(null));

class OrderNotifier extends StateNotifier<List<StoreOrder>> {
  OrderNotifier(this.ref, {bool enabled = true}) : super([]) {
    if (enabled) Future.microtask(refresh);
  }
  final Ref ref;
  Dio get dio => ref.read(dioProvider);

  Future<void> refresh() async {
    if (!mounted) return;
    ref.read(orderLoadStateProvider.notifier).state = const AsyncLoading();
    try {
      final response = await dio.get('/marketplace/orders');
      if (!mounted) return;
      state = (response.data['data'] as List)
          .map((j) => StoreOrder.fromMap(Map<String, dynamic>.from(j)))
          .toList();
      ref.read(orderLoadStateProvider.notifier).state = const AsyncData(null);
    } catch (e, st) {
      if (mounted)
        ref.read(orderLoadStateProvider.notifier).state = AsyncError(e, st);
    }
  }

  void acceptServerOrder(Map<String, dynamic> data) {
    if (!mounted) return;
    final order = StoreOrder.fromMap(data);
    if (mounted) state = [order, ...state.where((o) => o.id != order.id)];
  }

  Future<void> cancelOrder(String id, {String? reason}) async {
    final response = await dio
        .post('/marketplace/orders/$id/cancel', data: {'reason': reason ?? ''});
    acceptServerOrder(Map<String, dynamic>.from(response.data['data']));
  }
}

final ordersNotifierProvider =
    StateNotifierProvider<OrderNotifier, List<StoreOrder>>((ref) =>
        OrderNotifier(ref, enabled: ref.watch(currentUserProvider) != null));

final singleOrderProvider = Provider.family<StoreOrder?, String>((ref, id) =>
    ref.watch(ordersNotifierProvider).where((o) => o.id == id).firstOrNull);
