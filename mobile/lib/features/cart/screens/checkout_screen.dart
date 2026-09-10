import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/delivery_address_provider.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String? _addressId;
  bool _submitting = false;

  Future<void> _checkout() async {
    if (_addressId == null) return;
    setState(() => _submitting = true);
    try {
      final key =
          'flutter-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(9999)}';
      await ref.read(dioProvider).post('/marketplace/orders/checkout', data: {
        'delivery_address_id': _addressId,
        'idempotency_key': key,
      });
      ref.read(cartProvider.notifier).refresh();
      if (mounted) {
        context.go('/marketplace/orders');
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Checkout failed: $error')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider).valueOrNull;
    final addresses = ref.watch(deliveryAddressesProvider);
    final currency =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: addresses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) {
          if (items.isEmpty)
            return const Center(
                child: Text('Add a delivery address before checkout.'));
          if (_addressId == null) {
            _addressId = items
                .firstWhere((item) => item.isDefault, orElse: () => items.first)
                .id;
          }
          return ListView(padding: const EdgeInsets.all(16), children: [
            Text('Deliver to', style: Theme.of(context).textTheme.titleMedium),
            ...items.map((address) => RadioListTile<String>(
                value: address.id,
                groupValue: _addressId,
                onChanged: (value) => setState(() => _addressId = value),
                title: Text(address.recipientName),
                subtitle: Text(address.summary))),
            const Divider(height: 32),
            Text('Order total', style: Theme.of(context).textTheme.titleMedium),
            ListTile(
                title: const Text('Items'),
                trailing: Text('${cart?.itemCount ?? 0}')),
            ListTile(
                title: const Text('Total'),
                trailing: Text(currency.format(cart?.subtotal ?? 0),
                    style: const TextStyle(fontWeight: FontWeight.bold))),
          ]);
        },
      ),
      bottomNavigationBar: SafeArea(
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                  onPressed: _submitting || cart == null || cart.items.isEmpty
                      ? null
                      : _checkout,
                  child: Text(
                      _submitting ? 'Creating order...' : 'Place order')))),
    );
  }
}
