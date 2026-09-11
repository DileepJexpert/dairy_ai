import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import '../../finance/providers/wallet_provider.dart';
import '../models/delivery_address.dart';
import '../providers/cart_provider.dart';
import '../providers/delivery_address_provider.dart';
import '../providers/coupon_provider.dart';
import '../providers/order_repository.dart';
import '../../marketplace/widgets/store_design.dart';

import 'package:flutter/services.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String? _addressId;
  String _paymentMethod = 'wallet';
  bool _submitting = false;
  bool _summaryItemsExpanded = true;

  String _getPaymentButtonLabel(double totalAmount) {
    if (_submitting) return 'Placing Order…';
    switch (_paymentMethod) {
      case 'wallet':
        return 'Use wallet & place order (${storeMoney(totalAmount)})';
      case 'upi':
        return 'Pay ${storeMoney(totalAmount)} via UPI (QR / Apps)';
      case 'card':
        return 'Pay ${storeMoney(totalAmount)} securely via Card';
      case 'netbanking':
        return 'Pay ${storeMoney(totalAmount)} via Net Banking';
      case 'cod':
        return 'Place order with Cash on Delivery (${storeMoney(totalAmount)})';
      default:
        return 'Pay ${storeMoney(totalAmount)} securely';
    }
  }

  Future<void> _checkout() async {
    if (_addressId == null) return;

    final cart = ref.read(cartProvider).valueOrNull;
    final subtotal = cart?.subtotal ?? 799.0;
    final appliedCoupon = ref.read(appliedCouponProvider);
    final discount = appliedCoupon?.calculateDiscount(subtotal) ?? 0.0;
    final totalAmount = (subtotal - discount).clamp(0.0, double.infinity);
    final generatedOrderId = 'ORD-2026-${Random().nextInt(8999) + 1000}';

    // Extract selected address details
    final addresses = ref.read(deliveryAddressesProvider).valueOrNull ?? [];
    final DeliveryAddress? selectedAddress = addresses.where((a) => a.id == _addressId).firstOrNull ??
        (addresses.isNotEmpty ? addresses.first : null);

    final currentUser = ref.read(currentUserProvider);
    final addressMap = {
      'recipient_name': selectedAddress?.recipientName ?? currentUser?.name ?? 'Milterra Member',
      'street_address': selectedAddress?.addressLine1 ?? 'Milterra Dairy Corridor, Gate #4',
      'city': selectedAddress?.villageOrCity ?? 'Karnal',
      'state': selectedAddress?.state ?? 'Haryana',
      'postal_code': selectedAddress?.postalCode ?? '132001',
      'phone_number': selectedAddress?.phone ?? currentUser?.phone ?? '+91 98000 00000',
    };

    if (_paymentMethod == 'wallet') {
      final walletState = ref.read(milterraWalletProvider);
      if (walletState.totalBalance < totalAmount) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: storeError,
              content: Text('Insufficient Milterra Wallet balance. Please select COD, UPI, or Card.'),
            ),
          );
        }
        return;
      }
      setState(() => _submitting = true);
      ref.read(milterraWalletProvider.notifier).payOrder(totalAmount, generatedOrderId);
      await _finalizeOrderPlacement(
        generatedOrderId: generatedOrderId,
        totalAmount: totalAmount,
        subtotal: subtotal,
        discount: discount,
        addressMap: addressMap,
        paymentStatus: 'PAID',
      );
    } else if (_paymentMethod == 'cod') {
      setState(() => _submitting = true);
      await _finalizeOrderPlacement(
        generatedOrderId: generatedOrderId,
        totalAmount: totalAmount,
        subtotal: subtotal,
        discount: discount,
        addressMap: addressMap,
        paymentStatus: 'PENDING',
      );
    } else if (_paymentMethod == 'upi') {
      _showUpiPaymentDialog(
        totalAmount: totalAmount,
        generatedOrderId: generatedOrderId,
        subtotal: subtotal,
        discount: discount,
        addressMap: addressMap,
      );
    } else if (_paymentMethod == 'card') {
      _showCardPaymentDialog(
        totalAmount: totalAmount,
        generatedOrderId: generatedOrderId,
        subtotal: subtotal,
        discount: discount,
        addressMap: addressMap,
      );
    } else if (_paymentMethod == 'netbanking') {
      _showNetBankingDialog(
        totalAmount: totalAmount,
        generatedOrderId: generatedOrderId,
        subtotal: subtotal,
        discount: discount,
        addressMap: addressMap,
      );
    }
  }

  Future<void> _finalizeOrderPlacement({
    required String generatedOrderId,
    required double totalAmount,
    required double subtotal,
    required double discount,
    required Map<String, dynamic> addressMap,
    required String paymentStatus,
  }) async {
    setState(() => _submitting = true);
    final cart = ref.read(cartProvider).valueOrNull;

    // Persist to unified Order Repository before cart is cleared
    ref.read(ordersNotifierProvider.notifier).placeOrder(
      orderId: generatedOrderId,
      cartItems: cart?.items ?? [],
      deliveryAddress: addressMap,
      paymentMethod: _paymentMethod,
      subtotal: subtotal,
      discount: discount,
      total: totalAmount,
      paymentStatus: paymentStatus,
    );

    try {
      final key =
          'flutter-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(9999)}';
      final res = await ref.read(dioProvider).post('/marketplace/orders/checkout', data: {
        'delivery_address_id': _addressId,
        'payment_method': _paymentMethod,
        'idempotency_key': key,
      });
      ref.read(appliedCouponProvider.notifier).removeCoupon();
      ref.read(cartProvider.notifier).refresh();
      if (mounted) {
        final data = (res.data as Map?)?['data'] as Map?;
        final orderId = data?['id']?.toString() ?? generatedOrderId;
        context.go('/marketplace/orders/$orderId');
      }
    } catch (_) {
      ref.read(appliedCouponProvider.notifier).removeCoupon();
      ref.read(cartProvider.notifier).clear().catchError((_) {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: storeGreen,
            content: Text(
              _paymentMethod == 'wallet'
                  ? 'Order placed successfully using Milterra Wallet!'
                  : 'Order placed successfully! Total: ${storeMoney(totalAmount)}',
            ),
          ),
        );
        context.go('/marketplace/orders/$generatedOrderId');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showUpiPaymentDialog({
    required double totalAmount,
    required String generatedOrderId,
    required double subtotal,
    required double discount,
    required Map<String, dynamic> addressMap,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        bool verifying = false;
        String selectedVpaApp = 'GPay';
        final vpaController = TextEditingController(text: 'farmer@okaxis');

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: storeWhite,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xffe8f5e9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.qr_code_scanner, color: storeGreen, size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Milterra UPI Instant Gateway',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: storeGreen,
                                  ),
                                ),
                                Text(
                                  'NPCI Certified 256-bit Encrypted',
                                  style: TextStyle(fontSize: 11, color: storeMuted),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: verifying ? null : () => Navigator.of(dialogCtx).pop(),
                          ),
                        ],
                      ),
                      const Divider(height: 24),

                      // Amount Box
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xfffcf5ee),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xffffd199)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Payable Amount:',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: storeGreen),
                            ),
                            Text(
                              storeMoney(totalAmount),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: storeOrange,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Dynamic QR Code Simulator Container
                      Center(
                        child: Container(
                          width: 200,
                          height: 200,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: storeBorder, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CustomPaint(
                                size: const Size(176, 176),
                                painter: _SimulatedQrPainter(),
                              ),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: storeGreen, width: 1.5),
                                ),
                                child: const Icon(Icons.eco, size: 20, color: storeGreen),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Center(
                        child: Text(
                          'Scan with Google Pay, PhonePe, Paytm, or BHIM',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: storeMuted),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // UPI VPA Copy Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xfff5f7f6),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: storeBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.account_balance, size: 16, color: storeGreen),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'milterra.pure@icici',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: storeGreen),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                Clipboard.setData(const ClipboardData(text: 'milterra.pure@icici'));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('UPI ID copied to clipboard!'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Text('Copy',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: storeOrange)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Fast Pay Apps selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          for (final app in ['GPay', 'PhonePe', 'Paytm', 'BHIM'])
                            ChoiceChip(
                              label: Text(app, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              selected: selectedVpaApp == app,
                              selectedColor: const Color(0xffe8f5e9),
                              labelStyle: TextStyle(
                                color: selectedVpaApp == app ? storeGreen : storeMuted,
                              ),
                              onSelected: (_) => setDialogState(() => selectedVpaApp = app),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: vpaController,
                        decoration: const InputDecoration(
                          labelText: 'Or Enter Custom UPI ID (VPA)',
                          hintText: 'e.g. yourname@oksbi',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.alternate_email, size: 18),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Action Button
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: storeAmber,
                          foregroundColor: storeGreen,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: verifying
                            ? null
                            : () async {
                                setDialogState(() => verifying = true);
                                await Future.delayed(const Duration(milliseconds: 1400));
                                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                                await _finalizeOrderPlacement(
                                  generatedOrderId: generatedOrderId,
                                  totalAmount: totalAmount,
                                  subtotal: subtotal,
                                  discount: discount,
                                  addressMap: addressMap,
                                  paymentStatus: 'PAID',
                                );
                              },
                        child: verifying
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: storeGreen),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Verifying UPI Approval…',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: storeGreen),
                                  ),
                                ],
                              )
                            : Text(
                                'Approve ₹${totalAmount.toStringAsFixed(2)} Payment',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: storeGreen),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCardPaymentDialog({
    required double totalAmount,
    required String generatedOrderId,
    required double subtotal,
    required double discount,
    required Map<String, dynamic> addressMap,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        bool step3ds = false;
        bool processing = false;
        final cardNumCtrl = TextEditingController(text: '4532 8920 1148 7639');
        final currentUser = ref.read(currentUserProvider);
        final nameCtrl = TextEditingController(text: currentUser?.name?.toUpperCase() ?? 'MILTERRA MEMBER');
        final expCtrl = TextEditingController(text: '08/29');
        final cvvCtrl = TextEditingController(text: '482');
        final otpCtrl = TextEditingController(text: '774102');

        return StatefulBuilder(
          builder: (context, setCardState) {
            return Dialog(
              backgroundColor: storeWhite,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xffe8f5e9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.credit_card, color: storeGreen, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  step3ds ? '3D Secure Bank Verification' : 'Milterra SafePay Card Gateway',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: storeGreen,
                                  ),
                                ),
                                const Text(
                                  'Visa · MasterCard · RuPay · 256-Bit SSL',
                                  style: TextStyle(fontSize: 11, color: storeMuted),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: processing ? null : () => Navigator.of(dialogCtx).pop(),
                          ),
                        ],
                      ),
                      const Divider(height: 24),

                      if (!step3ds) ...[
                        // Virtual Card Graphic Banner
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xff1b382b), Color(0xff2d5f47)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'MILTERRA PLATINUM',
                                    style: TextStyle(
                                      color: storeAmber,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  Icon(Icons.contactless, color: Colors.white70, size: 20),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                cardNumCtrl.text.isEmpty ? '•••• •••• •••• ••••' : cardNumCtrl.text,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  letterSpacing: 2.2,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('CARDHOLDER',
                                          style: TextStyle(color: Colors.white54, fontSize: 9)),
                                      Text(
                                        nameCtrl.text.toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('EXPIRES',
                                          style: TextStyle(color: Colors.white54, fontSize: 9)),
                                      Text(
                                        expCtrl.text,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Form Inputs
                        TextField(
                          controller: cardNumCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Card Number',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.credit_card_outlined),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          onChanged: (_) => setCardState(() {}),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: expCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'MM / YY',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                onChanged: (_) => setCardState(() {}),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: cvvCtrl,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: 'CVV',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Name on Card',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person_outline),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          onChanged: (_) => setCardState(() {}),
                        ),
                        const SizedBox(height: 18),

                        // Submit to 3DS Button
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: storeAmber,
                            foregroundColor: storeGreen,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: processing
                              ? null
                              : () async {
                                  setCardState(() => processing = true);
                                  await Future.delayed(const Duration(milliseconds: 900));
                                  setCardState(() {
                                    processing = false;
                                    step3ds = true;
                                  });
                                },
                          child: processing
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: storeGreen),
                                    ),
                                    SizedBox(width: 10),
                                    Text('Connecting to Bank Gateway…',
                                        style: TextStyle(fontWeight: FontWeight.bold, color: storeGreen)),
                                  ],
                                )
                              : Text(
                                  'Proceed to 3D Secure (${storeMoney(totalAmount)})',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: storeGreen),
                                ),
                        ),
                      ] else ...[
                        // 3D Secure Simulation Panel
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xfff0f7ff),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xffb8d8ff)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.verified_user, color: Color(0xff0052cc), size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Verified by VISA / RuPay Secure',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xff0052cc),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'A 6-digit one-time authorization passcode was simulated for order payment of ${storeMoney(totalAmount)}.',
                                style: const TextStyle(fontSize: 12, color: Color(0xff333333)),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Sent to mobile linked to card ending with •••• 7639',
                                style: TextStyle(fontSize: 11, color: storeMuted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: otpCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Enter 6-digit Bank OTP',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.password_outlined),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: TextButton.icon(
                            onPressed: () => otpCtrl.text = '774102',
                            icon: const Icon(Icons.flash_on, size: 14, color: storeOrange),
                            label: const Text('Autofill Test Passcode (774102)',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: storeOrange)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: storeGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: processing
                              ? null
                              : () async {
                                  setCardState(() => processing = true);
                                  await Future.delayed(const Duration(milliseconds: 1200));
                                  if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                                  await _finalizeOrderPlacement(
                                    generatedOrderId: generatedOrderId,
                                    totalAmount: totalAmount,
                                    subtotal: subtotal,
                                    discount: discount,
                                    addressMap: addressMap,
                                    paymentStatus: 'PAID',
                                  );
                                },
                          child: processing
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    ),
                                    SizedBox(width: 10),
                                    Text('Authorizing Payment with Bank…',
                                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                  ],
                                )
                              : const Text('Authorize & Complete Payment',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showNetBankingDialog({
    required double totalAmount,
    required String generatedOrderId,
    required double subtotal,
    required double discount,
    required Map<String, dynamic> addressMap,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        String selectedBank = 'State Bank of India';
        bool processing = false;

        final banks = [
          'State Bank of India',
          'HDFC Bank',
          'ICICI Bank',
          'Axis Bank',
          'Punjab National Bank',
          'Bank of Baroda',
          'Rajasthan Rural Apex Cooperative Bank',
        ];

        return StatefulBuilder(
          builder: (context, setBankState) {
            return Dialog(
              backgroundColor: storeWhite,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xffe8f5e9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.account_balance, color: storeGreen, size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Select Your Bank',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: storeGreen,
                                  ),
                                ),
                                Text(
                                  'Fast & Secure Net Banking Portal',
                                  style: TextStyle(fontSize: 11, color: storeMuted),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: processing ? null : () => Navigator.of(dialogCtx).pop(),
                          ),
                        ],
                      ),
                      const Divider(height: 24),

                      // Bank list
                      for (final bank in banks)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: InkWell(
                            onTap: () => setBankState(() => selectedBank = bank),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: selectedBank == bank ? const Color(0xfffcf5ee) : storeWhite,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: selectedBank == bank ? storeOrange : storeBorder,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    selectedBank == bank
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_unchecked,
                                    size: 18,
                                    color: selectedBank == bank ? storeOrange : storeMuted,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      bank,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight:
                                            selectedBank == bank ? FontWeight.bold : FontWeight.normal,
                                        color: storeGreen,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 18),

                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: storeAmber,
                          foregroundColor: storeGreen,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: processing
                            ? null
                            : () async {
                                setBankState(() => processing = true);
                                await Future.delayed(const Duration(milliseconds: 1300));
                                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                                await _finalizeOrderPlacement(
                                  generatedOrderId: generatedOrderId,
                                  totalAmount: totalAmount,
                                  subtotal: subtotal,
                                  discount: discount,
                                  addressMap: addressMap,
                                  paymentStatus: 'PAID',
                                );
                              },
                        child: processing
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: storeGreen),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Redirecting to $selectedBank…',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: storeGreen),
                                  ),
                                ],
                              )
                            : Text(
                                'Pay ${storeMoney(totalAmount)} via $selectedBank',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: storeGreen),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
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
                        child: const Icon(Icons.eco,
                            color: storeAmber, size: 20),
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
                      'Secure checkout',
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
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
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
                    .firstWhere((item) => item.isDefault, orElse: () => items.first)
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
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
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
        content: Text('Are you sure you want to delete the delivery address for "${address.recipientName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: storeError),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              await ref.read(deliveryAddressesProvider.notifier).delete(address.id);
              final remaining = ref.read(deliveryAddressesProvider).valueOrNull ?? [];
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
    final pinCtrl = TextEditingController(text: address.postalCode);
    final landmarkCtrl = TextEditingController(text: address.landmark ?? '');

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: storeWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
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
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Full Name / Recipient',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: line1Ctrl,
                      decoration: const InputDecoration(
                        labelText: 'Flat, House no., Building, Street',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: cityCtrl,
                            decoration: const InputDecoration(
                              labelText: 'City / Village',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: stateCtrl,
                            decoration: const InputDecoration(
                              labelText: 'State',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: pinCtrl,
                            decoration: const InputDecoration(
                              labelText: 'PIN Code',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: landmarkCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Landmark (Optional)',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: storeAmber,
                          foregroundColor: storeGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                        ),
                        onPressed: () async {
                          final updated = {
                            'recipient_name': nameCtrl.text.trim(),
                            'phone': phoneCtrl.text.trim(),
                            'address_line1': line1Ctrl.text.trim(),
                            'village_or_city': cityCtrl.text.trim(),
                            'state': stateCtrl.text.trim(),
                            'postal_code': pinCtrl.text.trim(),
                            'landmark': landmarkCtrl.text.trim(),
                            'district': cityCtrl.text.trim(),
                            'is_default': address.isDefault,
                          };
                          await ref.read(deliveryAddressesProvider.notifier).update(address.id, updated);
                          if (dialogCtx.mounted) {
                            Navigator.of(dialogCtx).pop();
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Address updated successfully')),
                            );
                          }
                        },
                        child: const Text(
                          'Save Changes',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
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
                    color: _addressId == address.id
                        ? storeOrange
                        : storeBorder,
                  ),
                ),
                child: InkWell(
                  onTap: () => setState(() => _addressId = address.id),
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
                                            fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      if (address.isDefault) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: storeGreen.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
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
                                        fontSize: 12, height: 1.4, color: Color(0xff333333)),
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
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                                style: TextStyle(
                                    fontSize: 12, color: storeError),
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
          _paymentOptionTile(
            value: 'wallet',
            title: 'Milterra Wallet & Milk Earnings (${storeMoney(walletBal)} Available)',
            subtitle: 'Instant deduction from cooperative milk earnings & store credits',
            icon: Icons.account_balance_wallet_outlined,
          ),
          _paymentOptionTile(
            value: 'cod',
            title: 'Cash on Delivery (Pay upon delivery)',
            subtitle: 'Pay via cash, UPI, or card at your doorstep',
            icon: Icons.payments_outlined,
          ),
          _paymentOptionTile(
            value: 'upi',
            title: 'UPI (Google Pay, PhonePe, Paytm, BHIM)',
            subtitle: 'Instant payment from your linked bank account',
            icon: Icons.qr_code_scanner_outlined,
          ),
          _paymentOptionTile(
            value: 'card',
            title: 'Credit or Debit Card',
            subtitle: 'Visa, MasterCard, RuPay, Maestro accepted',
            icon: Icons.credit_card_outlined,
          ),
          _paymentOptionTile(
            value: 'netbanking',
            title: 'Net Banking',
            subtitle: 'SBI, HDFC, ICICI, Axis, and all major rural cooperative banks',
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
          onTap: () => setState(() => _paymentMethod = value),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 4),
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
                          style: const TextStyle(
                              fontSize: 11, color: storeMuted),
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
    final subtotal = cart?.subtotal ?? 0.0;
    final count = cart?.itemCount ?? 0;
    final appliedCoupon = ref.watch(appliedCouponProvider);
    final discount = appliedCoupon?.calculateDiscount(subtotal) ?? 0.0;
    final orderTotal = (subtotal - discount).clamp(0.0, double.infinity);

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
              onPressed: _submitting || count == 0 ? null : _checkout,
              child: Text(
                _getPaymentButtonLabel(orderTotal),
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
                  style: const TextStyle(fontSize: 13, color: Color(0xff565959))),
              Text(storeMoney(subtotal),
                  style: const TextStyle(fontSize: 13, color: Color(0xff0f1111))),
            ],
          ),
          if (cart != null && cart.items.isNotEmpty) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: () => setState(() => _summaryItemsExpanded = !_summaryItemsExpanded),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Text(
                      _summaryItemsExpanded ? 'Hide items' : 'View items (${cart.items.length})',
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
                                        errorBuilder: (_, __, ___) => const Icon(
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
                                    'Qty: ${item.quantity} × ${storeMoney(item.unitPrice)}',
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
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xff067d62))),
                Text('-${storeMoney(discount)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xff067d62))),
              ],
            ),
          ],
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Delivery charge:',
                  style: TextStyle(fontSize: 13, color: Color(0xff565959))),
              Text('FREE',
                  style: TextStyle(
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
                storeMoney(orderTotal),
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
                  const Icon(Icons.check_circle_outline, size: 14, color: Color(0xff1b5e20)),
                  const SizedBox(width: 6),
                  Text('Your Coupon Savings: ${storeMoney(discount)}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xff1b5e20))),
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
                Icon(Icons.lock_outline,
                    size: 16, color: storeGreen),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Secure checkout',
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

class _SimulatedQrPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xff122b1e)
      ..style = PaintingStyle.fill;

    void drawFinder(double x, double y) {
      canvas.drawRect(Rect.fromLTWH(x, y, 42, 42), paint);
      canvas.drawRect(
        Rect.fromLTWH(x + 6, y + 6, 30, 30),
        Paint()..color = Colors.white,
      );
      canvas.drawRect(Rect.fromLTWH(x + 12, y + 12, 18, 18), paint);
    }

    drawFinder(0, 0);
    drawFinder(size.width - 42, 0);
    drawFinder(0, size.height - 42);

    final rng = Random(42);
    final moduleSize = size.width / 21;
    for (int r = 0; r < 21; r++) {
      for (int c = 0; c < 21; c++) {
        final isTopLeft = r < 7 && c < 7;
        final isTopRight = r < 7 && c >= 14;
        final isBottomLeft = r >= 14 && c < 7;
        final isCenter = r >= 8 && r <= 12 && c >= 8 && c <= 12;

        if (!isTopLeft && !isTopRight && !isBottomLeft && !isCenter) {
          if (rng.nextBool()) {
            canvas.drawRect(
              Rect.fromLTWH(c * moduleSize + 0.5, r * moduleSize + 0.5, moduleSize - 1, moduleSize - 1),
              paint,
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

