import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dairy_ai/core/api_client.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import '../../finance/providers/wallet_provider.dart';
import '../models/delivery_address.dart';
import '../providers/cart_provider.dart';
import '../providers/delivery_address_provider.dart';
import '../providers/coupon_provider.dart';
import '../providers/order_repository.dart';
import '../widgets/address_location_fields.dart';
import '../../marketplace/widgets/store_design.dart';
import '../../../core/analytics_service.dart';

typedef CheckoutQuoteKey = ({
  String addressId,
  String paymentMethod,
  String couponCode,
  String cartFingerprint,
});

class CheckoutQuote {
  const CheckoutQuote({
    required this.subtotal,
    required this.deliveryFee,
    required this.discount,
    required this.total,
    required this.totalRaw,
    required this.isPrelaunch,
  });

  final double subtotal, deliveryFee, discount, total;
  final String totalRaw;
  final bool isPrelaunch;

  factory CheckoutQuote.fromJson(Map<String, dynamic> data) => CheckoutQuote(
        subtotal: double.parse(data['subtotal'].toString()),
        deliveryFee: double.parse(data['delivery_fee'].toString()),
        discount: double.parse(data['discount'].toString()),
        total: double.parse(data['total'].toString()),
        totalRaw: data['total'].toString(),
        isPrelaunch: data['is_prelaunch_interest'] == true,
      );
}

final checkoutQuoteProvider = FutureProvider.autoDispose
    .family<CheckoutQuote, CheckoutQuoteKey>((ref, key) async {
  ref.watch(currentUserProvider);
  final response = await ref.read(dioProvider).post(
    '/marketplace/orders/checkout/quote',
    data: {
      'delivery_address_id': key.addressId,
      'payment_method': key.paymentMethod,
      if (key.couponCode.isNotEmpty) 'coupon_code': key.couponCode,
    },
  );
  return CheckoutQuote.fromJson(
      Map<String, dynamic>.from(response.data['data'] as Map));
});

final paymentCapabilitiesProvider = FutureProvider.autoDispose<
    ({
      bool isPrelaunch,
      bool onlineAvailable,
    })>((ref) async {
  ref.watch(currentUserProvider);
  final response = await ref.read(dioProvider).get(
        '/marketplace/orders/payment-capabilities',
      );
  final data = Map<String, dynamic>.from(response.data['data'] as Map);
  return (
    isPrelaunch: data['is_prelaunch_interest'] == true,
    onlineAvailable: data['online_payment_available'] == true,
  );
});

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String? _addressId;
  String _paymentMethod = 'cod';
  bool _submitting = false;
  String? _checkoutKey;
  bool _summaryItemsExpanded = true;

  CheckoutQuoteKey _quoteKey(dynamic cart, StoreCoupon? coupon) => (
        addressId: _addressId ?? '',
        paymentMethod: _paymentMethod,
        couponCode: coupon?.code ?? '',
        cartFingerprint: cart?.items
                .map((item) =>
                    '${item.productId}:${item.quantity}:${item.currentPrice}')
                .join('|') ??
            '',
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref
          .read(analyticsServiceProvider)
          .trackCheckoutStep('checkout_screen_opened');
      try {
        await ref.read(cartProvider.notifier).reconcileWithBackend();
      } catch (_) {
        // Outage presented cleanly via quoteState retry UI
      }
    });
  }

  String _getPaymentButtonLabel(double totalAmount, bool isPrelaunch) {
    if (_submitting) {
      return isPrelaunch ? 'Saving your interest…' : 'Placing order…';
    }
    if (!isPrelaunch) {
      return _paymentMethod == 'cod'
          ? 'Place COD order (${storeMoney(totalAmount)})'
          : 'Place order and pay (${storeMoney(totalAmount)})';
    }
    switch (_paymentMethod) {
      case 'wallet':
        return 'Continue with Wallet preview (${storeMoney(totalAmount)})';
      case 'upi':
        return 'Continue with UPI preview (${storeMoney(totalAmount)})';
      case 'card':
        return 'Continue with Card preview (${storeMoney(totalAmount)})';
      case 'netbanking':
        return 'Continue with Net Banking preview (${storeMoney(totalAmount)})';
      case 'cod':
        return 'Register COD interest (${storeMoney(totalAmount)})';
      default:
        return 'Continue (${storeMoney(totalAmount)})';
    }
  }

  Future<void> _checkout() async {
    if (_addressId == null) return;

    final cart = ref.read(cartProvider).valueOrNull;
    if (cart == null || cart.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: storeError,
          content: Text('Your cart is empty or could not be verified.'),
        ),
      );
      return;
    }
    final appliedCoupon = ref.read(appliedCouponProvider);
    final quote = ref
        .read(checkoutQuoteProvider(_quoteKey(cart, appliedCoupon)))
        .valueOrNull;
    if (quote == null) return;
    final subtotal = quote.subtotal;
    final discount = quote.discount;
    final totalAmount = quote.total;
    // Extract selected address details
    final addresses = ref.read(deliveryAddressesProvider).valueOrNull ?? [];
    final DeliveryAddress? selectedAddress =
        addresses.where((a) => a.id == _addressId).firstOrNull;
    if (selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: storeError,
          content: Text('Please reload and select a valid delivery address.'),
        ),
      );
      return;
    }

    final addressMap = {
      'recipient_name': selectedAddress.recipientName,
      'street_address': selectedAddress.addressLine1,
      'city': selectedAddress.villageOrCity,
      'state': selectedAddress.state,
      'postal_code': selectedAddress.postalCode,
      'phone_number': selectedAddress.phone,
    };

    ref.read(analyticsServiceProvider).trackPaymentStep(
      _paymentMethod,
      amount: totalAmount,
      metadata: {
        'address_id': _addressId,
        'city': selectedAddress.villageOrCity,
        'coupon_code': appliedCoupon?.code,
      },
    );

    // Always route order placement through server-verified APIs.
    // Dynamic payment requests, hosted checkout links, and provider-issued QR codes
    // are generated on the server with real provider IDs (e.g. Razorpay plink_...)
    // rather than relying on untrusted client-side static QRs or simulated UTR timers.
    setState(() => _submitting = true);
    await _finalizeOrderPlacement(
      totalAmount: totalAmount,
      subtotal: subtotal,
      discount: discount,
      addressMap: addressMap,
    );
  }

  Future<void> _finalizeOrderPlacement({
    required double totalAmount,
    required double subtotal,
    required double discount,
    required Map<String, dynamic> addressMap,
  }) async {
    setState(() => _submitting = true);
    try {
      final key = _checkoutKey ??=
          'flutter-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(9999)}';
      final cart = ref.read(cartProvider).valueOrNull;
      final quotedTotal = ref
          .read(checkoutQuoteProvider(
              _quoteKey(cart, ref.read(appliedCouponProvider))))
          .valueOrNull
          ?.totalRaw;
      if (quotedTotal == null) {
        throw const FormatException('Checkout quote is no longer available');
      }
      final res = await ref
          .read(dioProvider)
          .post('/marketplace/orders/checkout', data: {
        'delivery_address_id': _addressId,
        'payment_method': _paymentMethod,
        if (ref.read(appliedCouponProvider) != null)
          'coupon_code': ref.read(appliedCouponProvider)!.code,
        'expected_total': quotedTotal,
        'idempotency_key': key,
      });

      final body = res.data as Map?;
      final data = body?['data'] as Map?;
      if (data == null || data['id'] == null) {
        throw const FormatException(
          'The server did not return a valid order confirmation.',
        );
      }
      final realOrderId = data['id'].toString();
      final isPrelaunch = data['is_prelaunch_interest'] == true;
      var paymentMessage = '';
      if (!isPrelaunch && _paymentMethod != 'cod') {
        try {
          final paymentResponse = await ref
              .read(dioProvider)
              .post('/marketplace/orders/$realOrderId/payment-link');
          final paymentUrl =
              paymentResponse.data['data']['url']?.toString() ?? '';
          final uri = Uri.tryParse(paymentUrl);
          if (uri == null ||
              uri.scheme != 'https' ||
              !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
            paymentMessage = 'Open this order to complete payment.';
          }
        } catch (_) {
          paymentMessage = 'Order saved. Open it to retry payment.';
        }
      }
      ref.read(analyticsServiceProvider).trackCheckoutStep(
        'order_completed',
        metadata: {
          'order_id': realOrderId,
          'total_amount': totalAmount,
          'payment_method': _paymentMethod,
        },
      );
      ref
          .read(ordersNotifierProvider.notifier)
          .acceptServerOrder(Map<String, dynamic>.from(data));
      _checkoutKey = null;

      ref.read(appliedCouponProvider.notifier).removeCoupon();
      await ref.read(cartProvider.notifier).clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: storeGreen,
            content: Text(isPrelaunch
                ? 'Interest saved. No payment was taken. Milterra can contact you before launch.'
                : paymentMessage.isNotEmpty
                    ? paymentMessage
                    : _paymentMethod == 'cod'
                        ? 'COD order confirmed. Pay on delivery.'
                        : 'Order saved. Complete payment in the secure checkout.'),
          ),
        );
        context.go('/marketplace/orders/$realOrderId');
      }
    } on DioException catch (e) {
      final cart = ref.read(cartProvider).valueOrNull;
      if (cart != null && _addressId != null) {
        ref.invalidate(checkoutQuoteProvider(
            _quoteKey(cart, ref.read(appliedCouponProvider))));
      }
      final isPersisted = ref.read(localBasketStorageProvider).isPersisted;
      final savedMessage = isPersisted
          ? 'Your basket has been saved.'
          : 'Your basket is stored in memory for this session only; storage could not be saved.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: storeError,
            duration: const Duration(seconds: 5),
            content: Text(
              'Checkout is temporarily unavailable. $savedMessage (${dioErrorMessage(e)})',
            ),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _checkout(),
            ),
          ),
        );
      }
    } catch (e) {
      final isPersisted = ref.read(localBasketStorageProvider).isPersisted;
      final savedMessage = isPersisted
          ? 'Your basket has been saved.'
          : 'Your basket is stored in memory for this session only; storage could not be saved.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: storeError,
            duration: const Duration(seconds: 5),
            content: Text(
                'Checkout is temporarily unavailable. $savedMessage'),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _checkout(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider).valueOrNull;
    final addresses = ref.watch(deliveryAddressesProvider);

    return Scaffold(
      backgroundColor: storeCream,
      body: Column(
        children: [
          // Amazon Secure Checkout Header
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: const BoxDecoration(
              color: storeWhite,
              border: Border(bottom: BorderSide(color: storeBorder)),
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: () => context.go('/shop'),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: storeGreen,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child:
                            const Icon(Icons.eco, color: storeAmber, size: 20),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'MILTERRA',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: storeGreen,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const Text(
                  'Checkout',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: storeGreen,
                  ),
                ),
                const Spacer(),
                const Row(
                  children: [
                    Icon(Icons.lock_outline, size: 18, color: storeMuted),
                    SizedBox(width: 6),
                    Text(
                      'Pre-launch checkout',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: storeMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: addresses.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$e', style: StoreType.body),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => ref
                          .read(deliveryAddressesProvider.notifier)
                          .refresh(),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_off_outlined,
                              size: 64, color: storeMuted),
                          const SizedBox(height: 16),
                          const Text(
                            'Add a delivery address before checkout',
                            style: StoreType.heading,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: storeAmber,
                              foregroundColor: storeGreen,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                            ),
                            onPressed: () =>
                                context.push('/marketplace/addresses'),
                            child: const Text('Manage Addresses'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                _addressId ??= items
                    .firstWhere((item) => item.isDefault,
                        orElse: () => items.first)
                    .id;

                return LayoutBuilder(builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth >= 960;
                  final isMobile = constraints.maxWidth < StoreLayout.tablet;

                  return SingleChildScrollView(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                            maxWidth: StoreLayout.maxWidth),
                        child: Padding(
                          padding: EdgeInsets.all(isMobile ? 12 : 24),
                          child: isDesktop
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Steps Column (Left)
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildStepAddress(items),
                                          const SizedBox(height: 20),
                                          _buildStepPayment(),
                                          const SizedBox(height: 20),
                                          _buildStepReviewItems(cart),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 28),

                                    // Buy Box Sidebar (Right)
                                    SizedBox(
                                      width: 320,
                                      child: _buildOrderSummaryBox(cart),
                                    ),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildOrderSummaryBox(cart),
                                    const SizedBox(height: 16),
                                    _buildStepAddress(items),
                                    const SizedBox(height: 16),
                                    _buildStepPayment(),
                                    const SizedBox(height: 16),
                                    _buildStepReviewItems(cart),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  );
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAddress(DeliveryAddress address) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Address'),
        content: Text(
            'Are you sure you want to delete the delivery address for "${address.recipientName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: storeError),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              await ref
                  .read(deliveryAddressesProvider.notifier)
                  .delete(address.id);
              final remaining =
                  ref.read(deliveryAddressesProvider).valueOrNull ?? [];
              if (_addressId == address.id) {
                setState(() {
                  _addressId = remaining.isNotEmpty ? remaining.first.id : null;
                });
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Address deleted successfully')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditAddressDialog(DeliveryAddress address) {
    final nameCtrl = TextEditingController(text: address.recipientName);
    final phoneCtrl = TextEditingController(text: address.phone);
    final line1Ctrl = TextEditingController(text: address.addressLine1);
    final cityCtrl = TextEditingController(text: address.villageOrCity);
    final stateCtrl = TextEditingController(text: address.state);
    final districtCtrl = TextEditingController(text: address.district);
    final pinCtrl = TextEditingController(text: address.postalCode);
    final landmarkCtrl = TextEditingController(text: address.landmark ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: storeWhite,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Edit Delivery Address',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: storeGreen,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      TextFormField(
                        controller: nameCtrl,
                        validator: (value) => (value ?? '').trim().length < 2
                            ? 'Enter the recipient name'
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Full Name / Recipient',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneCtrl,
                        validator: (value) =>
                            RegExp(r'^\d{10}$').hasMatch((value ?? '').trim())
                                ? null
                                : 'Enter a 10-digit phone number',
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: line1Ctrl,
                        validator: (value) => (value ?? '').trim().length < 3
                            ? 'Enter the street address'
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Flat, House no., Building, Street',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 12),
                      AddressLocationFields(
                        pin: pinCtrl,
                        city: cityCtrl,
                        stateName: stateCtrl,
                        district: districtCtrl,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: landmarkCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Landmark (Optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: storeAmber,
                            foregroundColor: storeGreen,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22)),
                          ),
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            final updated = {
                              'recipient_name': nameCtrl.text.trim(),
                              'phone': phoneCtrl.text.trim(),
                              'address_line1': line1Ctrl.text.trim(),
                              'village_or_city': cityCtrl.text.trim(),
                              'state': stateCtrl.text.trim(),
                              'postal_code': pinCtrl.text.trim(),
                              'landmark': landmarkCtrl.text.trim(),
                              'district': districtCtrl.text.trim(),
                              'is_default': address.isDefault,
                            };
                            try {
                              await ref
                                  .read(deliveryAddressesProvider.notifier)
                                  .update(address.id, updated);
                            } catch (_) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Could not save address. Please try again.')),
                                );
                              }
                              return;
                            }
                            if (dialogCtx.mounted) {
                              Navigator.of(dialogCtx).pop();
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Address updated successfully')),
                              );
                            }
                          },
                          child: const Text(
                            'Save Changes',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStepAddress(List<dynamic> items) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text(
                    '1',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: storeOrange,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Select a delivery address',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: storeGreen,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => context.push('/marketplace/addresses'),
                child: const Text('Add new address',
                    style: TextStyle(fontSize: 12, color: Color(0xff007185))),
              ),
            ],
          ),
          const Divider(height: 20),
          for (final address in items.cast<DeliveryAddress>())
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Container(
                decoration: BoxDecoration(
                  color: _addressId == address.id
                      ? const Color(0xfffcf5ee)
                      : storeWhite,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _addressId == address.id ? storeOrange : storeBorder,
                  ),
                ),
                child: InkWell(
                  onTap: () {
                    setState(() => _addressId = address.id);
                    ref
                        .read(analyticsServiceProvider)
                        .trackCheckoutStep('address_selected', metadata: {
                      'address_id': address.id,
                      'city': address.villageOrCity,
                      'state': address.state,
                      'pincode': address.postalCode,
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _addressId == address.id
                                      ? storeOrange
                                      : storeBorder,
                                  width: _addressId == address.id ? 5 : 2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        address.recipientName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14),
                                      ),
                                      if (address.isDefault) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: storeGreen.withValues(
                                                alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'Default',
                                            style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: storeGreen),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${address.summary}\nPhone: ${address.phone}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        height: 1.4,
                                        color: Color(0xff333333)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (!address.isDefault) ...[
                              TextButton(
                                onPressed: () async {
                                  await ref
                                      .read(deliveryAddressesProvider.notifier)
                                      .makeDefault(address.id);
                                  setState(() => _addressId = address.id);
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  minimumSize: const Size(50, 26),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Set as default',
                                  style: TextStyle(
                                      fontSize: 12, color: Color(0xff007185)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('|',
                                  style: TextStyle(
                                      color: storeBorder, fontSize: 12)),
                              const SizedBox(width: 8),
                            ],
                            TextButton.icon(
                              onPressed: () => _showEditAddressDialog(address),
                              icon: const Icon(Icons.edit_outlined,
                                  size: 14, color: Color(0xff007185)),
                              label: const Text(
                                'Edit',
                                style: TextStyle(
                                    fontSize: 12, color: Color(0xff007185)),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                minimumSize: const Size(50, 26),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('|',
                                style: TextStyle(
                                    color: storeBorder, fontSize: 12)),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () => _confirmDeleteAddress(address),
                              icon: const Icon(Icons.delete_outline,
                                  size: 14, color: storeError),
                              label: const Text(
                                'Delete',
                                style:
                                    TextStyle(fontSize: 12, color: storeError),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                minimumSize: const Size(50, 26),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStepPayment() {
    final walletBal = ref.watch(milterraWalletProvider).totalBalance;
    final capabilities = ref.watch(paymentCapabilitiesProvider);
    final cart = ref.watch(cartProvider).valueOrNull;
    final coupon = ref.watch(appliedCouponProvider);
    final quote = _addressId == null
        ? null
        : ref.watch(checkoutQuoteProvider(_quoteKey(cart, coupon))).valueOrNull;
    final isPrelaunch =
        quote?.isPrelaunch ?? capabilities.valueOrNull?.isPrelaunch ?? false;
    final onlineAvailable = capabilities.valueOrNull?.onlineAvailable == true;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text(
                '2',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: storeOrange,
                ),
              ),
              SizedBox(width: 10),
              Text(
                'Payment method',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: storeGreen,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xfffff8e1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: storeAmber),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 18, color: storeGreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isPrelaunch
                        ? 'Pre-launch preview only: Choose how you would prefer to pay after official launch. No money, UPI request, QR code, or bank details are generated.'
                        : capabilities.isLoading
                            ? 'Checking available payment methods…'
                            : !onlineAvailable
                                ? 'Online payment is currently unavailable. You can place a Cash on Delivery order.'
                                : 'COD is collected on delivery. Online payments open a secure Razorpay checkout after you place the order.',
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: storeGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isPrelaunch)
            _paymentOptionTile(
              value: 'wallet',
              title:
                  'Milterra Wallet & Milk Earnings (${storeMoney(walletBal)} shown)',
              subtitle:
                  'Preview this preference; no wallet balance will be deducted',
              icon: Icons.account_balance_wallet_outlined,
            ),
          _paymentOptionTile(
            value: 'cod',
            title: 'Cash on Delivery',
            subtitle: isPrelaunch
                ? 'Register that you would prefer to pay after delivery'
                : 'Pay the courier on delivery',
            icon: Icons.payments_outlined,
          ),
          if (isPrelaunch || onlineAvailable)
            _paymentOptionTile(
              value: 'upi',
              title: isPrelaunch
                  ? 'UPI (Google Pay, PhonePe, Paytm, BHIM) — Preview'
                  : 'UPI',
              subtitle: isPrelaunch
                  ? 'Pre-launch preview only: No payment request or QR code is generated'
                  : 'Pay through secure hosted Razorpay checkout',
              icon: Icons.qr_code_scanner_outlined,
            ),
          if (isPrelaunch || onlineAvailable)
            _paymentOptionTile(
              value: 'card',
              title: isPrelaunch
                  ? 'Credit or Debit Card — Preview'
                  : 'Credit or Debit Card',
              subtitle: isPrelaunch
                  ? 'Pre-launch preview: Do not enter a card; no payment request is made'
                  : 'Pay through secure hosted checkout',
              icon: Icons.credit_card_outlined,
            ),
          if (isPrelaunch || onlineAvailable)
            _paymentOptionTile(
              value: 'netbanking',
              title: isPrelaunch ? 'Net Banking — Preview' : 'Net Banking',
              subtitle: isPrelaunch
                  ? 'Pre-launch preview: Select preferred bank without payment processing'
                  : 'Pay through secure hosted checkout',
              icon: Icons.account_balance_outlined,
            ),
        ],
      ),
    );
  }

  Widget _paymentOptionTile({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = _paymentMethod == value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? const Color(0xfffcf5ee) : storeWhite,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? storeOrange : storeBorder,
          ),
        ),
        child: ListTile(
          onTap: () {
            setState(() => _paymentMethod = value);
            ref
                .read(analyticsServiceProvider)
                .trackPaymentStep(value, metadata: {
              'action': 'select_payment_method',
            });
          },
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? storeOrange : storeBorder,
                width: selected ? 5 : 2,
              ),
            ),
          ),
          title: Row(
            children: [
              Icon(icon, size: 18, color: storeGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: storeMuted),
          ),
        ),
      ),
    );
  }

  Widget _buildStepReviewItems(dynamic cart) {
    if (cart == null || cart.items.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text(
                '3',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: storeOrange,
                ),
              ),
              SizedBox(width: 10),
              Text(
                'Review items and delivery',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: storeGreen,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          for (final item in cart.items) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: storeWhite,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: storeBorder),
                    ),
                    child: item.primaryImage != null &&
                            item.primaryImage!.isNotEmpty
                        ? Image.network(
                            item.primaryImage!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.inventory_2_outlined),
                          )
                        : const Icon(Icons.inventory_2_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xff0f1111),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Qty: ${item.quantity} | ${item.inStock ? "In Stock" : "Unavailable"}',
                          style:
                              const TextStyle(fontSize: 11, color: storeMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    storeMoney(item.lineTotal),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: storeOrange,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderSummaryBox(dynamic cart) {
    final count = cart?.itemCount ?? 0;
    final appliedCoupon = ref.watch(appliedCouponProvider);
    final quoteKey = _quoteKey(cart, appliedCoupon);
    final quoteState = _addressId == null || count == 0
        ? null
        : ref.watch(checkoutQuoteProvider(quoteKey));
    final quote = quoteState?.valueOrNull;
    final subtotal = quote?.subtotal ?? cart?.subtotal ?? 0.0;
    final discount = quote?.discount ?? 0.0;
    final orderTotal = quote?.total;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: storeAmber,
                foregroundColor: storeGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
              onPressed:
                  _submitting || count == 0 || quote == null ? null : _checkout,
              child: Text(
                quote == null
                    ? 'Calculating delivery and total…'
                    : _getPaymentButtonLabel(orderTotal!, quote.isPrelaunch),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: storeGreen,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (quoteState?.hasError == true) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xfffef2f2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xfff87171)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.cloud_off_outlined,
                          size: 16, color: Color(0xffdc2626)),
                      SizedBox(width: 6),
                      Text(
                        'Checkout is temporarily unavailable',
                        style: TextStyle(
                          color: Color(0xff991b1b),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    ref.watch(localBasketStorageProvider).isPersisted
                        ? 'Your basket has been saved. Please retry verifying prices and delivery.'
                        : 'Your basket is stored in memory for this session only. Please retry verifying prices and delivery.',
                    style: const TextStyle(
                      color: Color(0xff7f1d1d),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 32,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xffb91c1c),
                        side: const BorderSide(color: Color(0xfff87171)),
                      ),
                      onPressed: () {
                        ref
                            .read(cartProvider.notifier)
                            .refresh(throwOnError: false);
                        ref.invalidate(checkoutQuoteProvider(quoteKey));
                      },
                      icon: const Icon(Icons.refresh, size: 14),
                      label: const Text('Retry Verification',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          const Text(
            'By placing your order, you agree to Milterra\'s Conditions of Use & Sale.',
            style: TextStyle(fontSize: 10, color: storeMuted),
            textAlign: TextAlign.center,
          ),
          const Divider(height: 24),
          const Text(
            'Order Summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: storeGreen,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Items ($count):',
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xff565959))),
              Text(storeMoney(subtotal),
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xff0f1111))),
            ],
          ),
          if (cart != null && cart.items.isNotEmpty) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: () => setState(
                  () => _summaryItemsExpanded = !_summaryItemsExpanded),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Text(
                      _summaryItemsExpanded
                          ? 'Hide items'
                          : 'View items (${cart.items.length})',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xff007185),
                      ),
                    ),
                    Icon(
                      _summaryItemsExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 16,
                      color: const Color(0xff007185),
                    ),
                  ],
                ),
              ),
            ),
            if (_summaryItemsExpanded) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xfff7faf9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: storeBorder.withValues(alpha: 0.7)),
                ),
                child: Column(
                  children: [
                    for (final item in cart.items)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: storeBorder),
                              ),
                              child: item.primaryImage != null &&
                                      item.primaryImage!.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(3),
                                      child: Image.network(
                                        item.primaryImage!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(
                                                Icons.inventory_2_outlined,
                                                size: 14),
                                      ),
                                    )
                                  : const Icon(Icons.inventory_2_outlined,
                                      size: 14),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xff0f1111),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Qty: ${item.quantity} × ${storeMoney(item.currentPrice)}',
                                    style: const TextStyle(
                                        fontSize: 10, color: storeMuted),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              storeMoney(item.lineTotal),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xff0f1111),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
          if (appliedCoupon != null) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Promotion (${appliedCoupon.code}):',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff067d62))),
                Text('-${storeMoney(discount)}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff067d62))),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Delivery charge:',
                  style: TextStyle(fontSize: 13, color: Color(0xff565959))),
              Text(
                  quote == null
                      ? 'Calculating…'
                      : quote.deliveryFee == 0
                          ? 'FREE'
                          : storeMoney(quote.deliveryFee),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff067d62))),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Order Total:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: storeGreen,
                ),
              ),
              Text(
                orderTotal == null ? 'Calculating…' : storeMoney(orderTotal),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: storeOrange,
                ),
              ),
            ],
          ),
          if (discount > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xffe8f5e9),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xffa5d6a7)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline,
                      size: 14, color: Color(0xff1b5e20)),
                  const SizedBox(width: 6),
                  Text('Your Coupon Savings: ${storeMoney(discount)}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff1b5e20))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xfff7faf9),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: storeBorder),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_outline, size: 16, color: storeGreen),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Pre-launch interest checkout · No payment collected',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: storeGreen),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
