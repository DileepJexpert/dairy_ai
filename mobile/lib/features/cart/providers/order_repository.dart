import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/features/cart/models/cart_models.dart';
import 'package:dairy_ai/features/finance/providers/wallet_provider.dart';
import 'package:dairy_ai/features/notifications/models/notification_models.dart';
import 'package:dairy_ai/features/notifications/providers/notification_provider.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';

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
    this.fulfillmentStatus = 'CONFIRMED',
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
      fulfillmentStatus: 'CONFIRMED',
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
      fulfillmentStatus: map['fulfillment_status']?.toString() ?? 'CONFIRMED',
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
  final String createdAt;
  final String status; // CONFIRMED, PACKED, DISPATCHED, OUT_FOR_DELIVERY, DELIVERED, CANCELLED
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
    required this.id,
    required this.createdAt,
    this.status = 'CONFIRMED',
    this.paymentStatus = 'PAID',
    this.paymentMethod = 'Milterra Wallet',
    this.carrier = 'DTDC Express Surface',
    this.trackingNumber = 'DTDC-7749210',
    this.estimatedDelivery = 'Expected in 1-2 Days',
    required this.address,
    required this.items,
    required this.subtotal,
    this.deliveryFee = 0.0,
    this.discount = 0.0,
    required this.total,
    this.timeline = const [],
  });

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

/// Helper function to format current date/time in Indian e-commerce style.
String _formatNow() {
  final now = DateTime.now();
  final months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
  final minute = now.minute.toString().padLeft(2, '0');
  final ampm = now.hour >= 12 ? 'PM' : 'AM';
  return '${now.day} ${months[now.month - 1]} ${now.year}, $hour:$minute $ampm';
}

/// State notifier managing real orders placed during the session.
class OrderNotifier extends StateNotifier<List<StoreOrder>> {
  final Ref _ref;

  OrderNotifier(this._ref) : super(_seedOrders);

  static final List<StoreOrder> _seedOrders = [
    const StoreOrder(
      id: 'ORD-2026-8801',
      createdAt: '11 Sep 2026, 05:40 PM',
      status: 'DISPATCHED',
      paymentStatus: 'PAID',
      paymentMethod: 'Milterra Wallet',
      carrier: 'DTDC Express Surface',
      trackingNumber: 'DTDC-7749210',
      estimatedDelivery: 'Tomorrow by 8 PM',
      address: {
        'recipient_name': 'Milterra Member',
        'street_address': 'Flat 402, Green Meadows, Dairy Farm Road',
        'city': 'Jaipur',
        'state': 'Rajasthan',
        'postal_code': '302001',
        'phone_number': '+91 98000 00000',
      },
      items: [
        StoreOrderItem(
          productId: 'mil-ghee-1000',
          title: 'Milterra Pure A2 Gir Cow Bilona Ghee (1L Glass Jar)',
          quantity: 1,
          unitPrice: 1450.0,
          lineTotal: 1450.0,
          image:
              'https://images.unsplash.com/photo-1628088062854-d1870b4553da?w=600&auto=format&fit=crop&q=80',
          fulfillmentStatus: 'DISPATCHED',
        ),
        StoreOrderItem(
          productId: 'mil-butter-250',
          title: 'Milterra Cultured Vedic White Makhan (500g)',
          quantity: 1,
          unitPrice: 400.0,
          lineTotal: 400.0,
          image:
              'https://images.unsplash.com/photo-1589985270826-4b7bb135bc9d?w=600&auto=format&fit=crop&q=80',
          fulfillmentStatus: 'DISPATCHED',
        ),
      ],
      subtotal: 1850.0,
      deliveryFee: 0.0,
      discount: 0.0,
      total: 1850.0,
      timeline: [
        OrderTimelineEvent(
          time: '11 Sep 2026, 06:15 PM',
          title: 'Dispatched via DTDC Express',
          location: 'DTDC Central Hub, Jaipur',
          remarks: 'Air Waybill DTDC-7749210 allocated. In transit to destination hub.',
          status: 'DISPATCHED',
        ),
        OrderTimelineEvent(
          time: '11 Sep 2026, 05:55 PM',
          title: 'Packed & Quality Sealed',
          location: 'Milterra Pure Hub, Karnal',
          remarks: 'Tested for 99.4% purity and securely packed in temperature-controlled crate.',
          status: 'PACKED',
        ),
        OrderTimelineEvent(
          time: '11 Sep 2026, 05:40 PM',
          title: 'Order Placed & Payment Verified',
          location: 'Milterra Web Store',
          remarks: 'Payment of ₹1,850 successfully debited from Milterra Wallet.',
          status: 'CONFIRMED',
        ),
      ],
    ),
    const StoreOrder(
      id: 'ORD-2026-7652',
      createdAt: '28 Aug 2026, 11:15 AM',
      status: 'DELIVERED',
      paymentStatus: 'PAID',
      paymentMethod: 'UPI / Razorpay',
      carrier: 'Delhivery Logistics',
      trackingNumber: 'DEL-8841920',
      estimatedDelivery: 'Delivered',
      address: {
        'recipient_name': 'Milterra Member',
        'street_address': 'Flat 402, Green Meadows',
        'city': 'Jaipur',
        'state': 'Rajasthan',
        'postal_code': '302001',
        'phone_number': '+91 98000 00000',
      },
      items: [
        StoreOrderItem(
          productId: 'mil-paneer-500',
          title: 'Milterra Fresh Farm Soft Malai Paneer (500g)',
          quantity: 2,
          unitPrice: 200.0,
          lineTotal: 400.0,
          image:
              'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?w=600&auto=format&fit=crop&q=80',
          fulfillmentStatus: 'DELIVERED',
        ),
      ],
      subtotal: 400.0,
      deliveryFee: 0.0,
      discount: 0.0,
      total: 400.0,
      timeline: [
        OrderTimelineEvent(
          time: '29 Aug 2026, 04:30 PM',
          title: 'Package Delivered',
          location: 'Jaipur Delivery Center',
          remarks: 'Handed over directly to recipient.',
          status: 'DELIVERED',
        ),
        OrderTimelineEvent(
          time: '28 Aug 2026, 11:15 AM',
          title: 'Order Confirmed',
          location: 'Milterra Web Store',
          remarks: 'Paid via UPI.',
          status: 'CONFIRMED',
        ),
      ],
    ),
  ];

  /// Places a new order into reactive state and sends an immediate notification.
  StoreOrder placeOrder({
    required String orderId,
    required List<CartItem> cartItems,
    required Map<String, dynamic> deliveryAddress,
    required String paymentMethod,
    required double subtotal,
    required double discount,
    required double total,
    String paymentStatus = 'PAID',
    String? carrier,
    String? trackingNumber,
  }) {
    final nowStr = _formatNow();
    final items = cartItems.map(StoreOrderItem.fromCartItem).toList();

    String methodLabel;
    switch (paymentMethod.toLowerCase()) {
      case 'wallet':
        methodLabel = 'Milterra Wallet';
        break;
      case 'cod':
        methodLabel = 'Cash on Delivery (COD)';
        break;
      case 'upi':
        methodLabel = 'UPI (Instant)';
        break;
      case 'card':
        methodLabel = 'Credit/Debit Card (Visa/MasterCard)';
        break;
      case 'netbanking':
        methodLabel = 'Net Banking';
        break;
      default:
        methodLabel = paymentMethod;
    }

    final order = StoreOrder(
      id: orderId,
      createdAt: nowStr,
      status: 'CONFIRMED',
      paymentStatus: paymentStatus,
      paymentMethod: methodLabel,
      carrier: carrier ?? 'Milterra Express / DTDC Partner',
      trackingNumber: trackingNumber ?? 'Awaiting AWB Generation',
      estimatedDelivery: 'Expected in 1-2 Days',
      address: deliveryAddress,
      items: items,
      subtotal: subtotal,
      deliveryFee: 0.0,
      discount: discount,
      total: total,
      timeline: [
        OrderTimelineEvent(
          time: nowStr,
          title: paymentStatus == 'PAID'
              ? 'Order Placed & Payment Verified'
              : 'Order Placed (Payment Pending / COD)',
          location: 'Milterra Online Store',
          remarks: paymentMethod == 'wallet'
              ? 'Order total ₹${total.toStringAsFixed(2)} deducted from Milterra Wallet.'
              : paymentStatus == 'PAID'
                  ? 'Payment confirmed via $methodLabel. Awaiting warehouse packaging.'
                  : 'Order registered. Payment collection pending upon delivery.',
          status: 'CONFIRMED',
        ),
      ],
    );

    state = [order, ...state];

    // Trigger in-app notification
    _ref.read(notificationProvider.notifier).pushNotification(
          NotificationItem(
            id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
            userId: 'current-user',
            type: NotificationType.orderUpdate,
            title: 'Order Confirmed: #$orderId',
            body:
                'Your order for ${items.length} item(s) worth ₹${total.toStringAsFixed(2)} has been placed successfully.',
            isRead: false,
            createdAt: DateTime.now(),
          ),
        );

    return order;
  }

  /// Cancels an order and automatically refunds the Milterra wallet if prepaid.
  void cancelOrder(String orderId, {String? reason}) {
    final order = state.firstWhere(
      (o) => o.id == orderId,
      orElse: () => _seedOrders.first,
    );

    if (order.status.toUpperCase() == 'CANCELLED') return;

    // Trigger wallet refund if paid
    if (order.paymentStatus.toUpperCase() == 'PAID' && order.total > 0) {
      _ref.read(milterraWalletProvider.notifier).refundOrder(order.total, order.id);
    }

    updateOrderStatus(
      orderId,
      'CANCELLED',
      remarks: reason ??
          'Order cancelled by customer. Refund credited to Milterra Wallet if prepaid.',
    );
  }

  /// Updates payment status of an order.
  void updatePaymentStatus(String orderId, String paymentStatus) {
    state = state.map((o) {
      if (o.id != orderId) return o;
      return o.copyWith(paymentStatus: paymentStatus);
    }).toList();
  }

  /// Updates an order status with realistic tracking checkpoints and alerts.
  void updateOrderStatus(
    String orderId,
    String newStatus, {
    String? carrier,
    String? trackingNumber,
    String? location,
    String? remarks,
  }) {
    final nowStr = _formatNow();
    final normalizedStatus = newStatus.toUpperCase();

    state = state.map((order) {
      if (order.id != orderId) return order;

      final effCarrier = carrier ?? order.carrier;
      final effTracking = trackingNumber ?? order.trackingNumber;

      String defaultTitle;
      String defaultLocation;
      String defaultRemarks;

      switch (normalizedStatus) {
        case 'PACKED':
          defaultTitle = 'Packed at Milterra Central Hub';
          defaultLocation = location ?? 'Milterra Pure Hub, Karnal';
          defaultRemarks = remarks ??
              'Package sealed with tamper-proof seal and certified for zero adulteration.';
          break;
        case 'DISPATCHED':
          defaultTitle = 'Picked up by $effCarrier';
          defaultLocation = location ?? 'DTDC Sorting Facility, Jaipur';
          defaultRemarks = remarks ??
              'Consignment assigned to surface cargo vehicle. AWB: $effTracking.';
          break;
        case 'OUT_FOR_DELIVERY':
          defaultTitle = 'Out for Delivery';
          defaultLocation = location ?? 'Local Area Distribution Center';
          defaultRemarks = remarks ??
              'Delivery executive is out for delivery. Estimated delivery today by 8 PM.';
          break;
        case 'DELIVERED':
          defaultTitle = 'Delivered to Recipient';
          defaultLocation = location ?? 'Customer Delivery Address';
          defaultRemarks = remarks ??
              'Handed over directly to ${order.address['recipient_name'] ?? 'recipient'}.';
          break;
        case 'CANCELLED':
          defaultTitle = 'Order Cancelled';
          defaultLocation = location ?? 'Milterra Customer Desk';
          defaultRemarks = remarks ?? 'Order cancelled by customer or admin.';
          break;
        default:
          defaultTitle = 'Order Confirmed';
          defaultLocation = location ?? 'Milterra Store';
          defaultRemarks = remarks ?? 'Order verified.';
      }

      final newEvent = OrderTimelineEvent(
        time: nowStr,
        title: defaultTitle,
        location: defaultLocation,
        remarks: defaultRemarks,
        status: normalizedStatus,
      );

      final updatedTimeline = [newEvent, ...order.timeline];

      return order.copyWith(
        status: normalizedStatus,
        carrier: effCarrier,
        trackingNumber: effTracking,
        timeline: updatedTimeline,
      );
    }).toList();

    // Trigger in-app notification based on status
    final currentOrder = state.firstWhere(
      (o) => o.id == orderId,
      orElse: () => _seedOrders.first,
    );

    String notifTitle;
    String notifBody;
    NotificationType notifType = NotificationType.orderUpdate;

    if (normalizedStatus == 'PACKED') {
      notifTitle = 'Order #$orderId Packed';
      notifBody = 'Your package is packed and awaiting courier partner pickup.';
    } else if (normalizedStatus == 'DISPATCHED') {
      notifType = NotificationType.courierTracking;
      notifTitle = '🚚 Dispatched via ${currentOrder.carrier}';
      notifBody =
          'Order #$orderId is on its way (AWB: ${currentOrder.trackingNumber}).';
    } else if (normalizedStatus == 'OUT_FOR_DELIVERY') {
      notifType = NotificationType.courierTracking;
      notifTitle = '🛵 Out for Delivery: #$orderId';
      notifBody =
          'Your ${currentOrder.carrier} delivery agent is arriving soon.';
    } else if (normalizedStatus == 'DELIVERED') {
      notifTitle = '✅ Order #$orderId Delivered';
      notifBody =
          'Your package has been delivered safely. Thank you for choosing Milterra!';
    } else {
      notifTitle = 'Order #$orderId Status Updated';
      notifBody = 'Current fulfillment status: $normalizedStatus.';
    }

    _ref.read(notificationProvider.notifier).pushNotification(
          NotificationItem(
            id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
            userId: 'current-user',
            type: notifType,
            title: notifTitle,
            body: notifBody,
            isRead: false,
            createdAt: DateTime.now(),
          ),
        );

    // Asynchronously dispatch telemetry to backend webhook if server is running
    try {
      final updatedOrder = state.firstWhere(
        (o) => o.id == orderId,
        orElse: () => _seedOrders.first,
      );
      _ref.read(dioProvider).post(
        '/marketplace/orders/webhooks/courier',
        data: {
          'order_id': orderId,
          'carrier': updatedOrder.carrier,
          'awb_number': updatedOrder.trackingNumber,
          'status': normalizedStatus,
          'location': location ?? 'Milterra Logistics Hub',
          'remarks': remarks ?? 'Status updated to $normalizedStatus',
        },
      ).ignore();
    } catch (_) {}
  }

  /// Advances to the next courier milestone for fast interactive testing.
  void simulateCourierStep(String orderId) {
    final match = state.firstWhere(
      (o) => o.id == orderId,
      orElse: () => _seedOrders.first,
    );

    final s = match.status.toUpperCase();
    if (s.contains('CONFIRMED') || s.contains('PLACED') || s.contains('PENDING')) {
      updateOrderStatus(orderId, 'PACKED');
    } else if (s.contains('PACK')) {
      final randomAwb = 'DTDC-${Random().nextInt(899999) + 100000}';
      updateOrderStatus(
        orderId,
        'DISPATCHED',
        carrier: 'DTDC Express Surface',
        trackingNumber: randomAwb,
        location: 'DTDC Central Hub, Jaipur',
        remarks: 'Parcel picked up by DTDC Courier van. AWB $randomAwb generated.',
      );
    } else if (s.contains('DISPATCH') || s.contains('SHIP')) {
      updateOrderStatus(
        orderId,
        'OUT_FOR_DELIVERY',
        location: 'City Sub-Hub #14',
        remarks: 'Out for delivery with DTDC agent Rajesh (Contact: +91 98210 44321).',
      );
    } else if (s.contains('OUT') || s.contains('TRANSIT')) {
      updateOrderStatus(
        orderId,
        'DELIVERED',
        location: match.address['city']?.toString() ?? 'Customer Address',
        remarks: 'Delivered to recipient with digital signature confirmation.',
      );
    } else {
      // If already delivered, reset to CONFIRMED for continuous loop testing
      updateOrderStatus(orderId, 'CONFIRMED', remarks: 'Reset to Confirmed for workflow testing.');
    }
  }
}

/// Provider for the list of all orders.
final ordersNotifierProvider =
    StateNotifierProvider<OrderNotifier, List<StoreOrder>>((ref) {
  return OrderNotifier(ref);
});

/// Provider for retrieving a single order by its ID.
final singleOrderProvider =
    Provider.family<StoreOrder?, String>((ref, orderId) {
  final orders = ref.watch(ordersNotifierProvider);
  try {
    return orders.firstWhere(
      (o) => o.id == orderId || o.id.toUpperCase() == orderId.toUpperCase(),
    );
  } catch (_) {
    return null;
  }
});
