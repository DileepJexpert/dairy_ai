import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../cart/providers/order_repository.dart';
import '../../marketplace/widgets/store_design.dart';

final adminOrdersProvider =
    Provider.autoDispose<List<StoreOrder>>((ref) {
  return ref.watch(ordersNotifierProvider);
});

class CommerceOrdersScreen extends ConsumerStatefulWidget {
  const CommerceOrdersScreen({super.key});

  @override
  ConsumerState<CommerceOrdersScreen> createState() =>
      _CommerceOrdersScreenState();
}

class _CommerceOrdersScreenState extends ConsumerState<CommerceOrdersScreen> {
  String _selectedStatus = 'All';

  void _updateFulfillment(
    String orderId,
    String newStatus, {
    String? carrier,
    String? trackingNumber,
    String? location,
    String? remarks,
  }) {
    ref.read(ordersNotifierProvider.notifier).updateOrderStatus(
          orderId,
          newStatus,
          carrier: carrier,
          trackingNumber: trackingNumber,
          location: location,
          remarks: remarks,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order #$orderId fulfillment updated to $newStatus'),
          backgroundColor: storeGreen,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showDispatchDialog(BuildContext context, StoreOrder order) {
    String selectedCourier = 'DTDC Express Surface';
    final awbController = TextEditingController(
        text: 'DTDC-${Random().nextInt(899999) + 100000}');
    final hubController = TextEditingController(text: 'DTDC Central Hub, Jaipur');

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: storeWhite,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: storeGreen,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.local_shipping,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text('Dispatch via Courier Partner',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order ID: ${order.id}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: storeGreen)),
                    const SizedBox(height: 12),
                    const Text('Select Courier Partner',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: storeMuted)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCourier,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'DTDC Express Surface',
                            child: Text('DTDC Express Surface (Recommended)')),
                        DropdownMenuItem(
                            value: 'Delhivery Logistics',
                            child: Text('Delhivery Surface Cargo')),
                        DropdownMenuItem(
                            value: 'Blue Dart Air Express',
                            child: Text('Blue Dart Express Air')),
                        DropdownMenuItem(
                            value: 'Milterra Direct Fleet',
                            child: Text('Milterra Temperature-Controlled Fleet')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedCourier = val;
                            if (val.contains('DTDC')) {
                              awbController.text =
                                  'DTDC-${Random().nextInt(899999) + 100000}';
                              hubController.text = 'DTDC Central Hub, Jaipur';
                            } else if (val.contains('Delhivery')) {
                              awbController.text =
                                  'DEL-${Random().nextInt(899999) + 100000}';
                              hubController.text = 'Delhivery Mega Gateway, Delhi';
                            } else if (val.contains('Blue Dart')) {
                              awbController.text =
                                  'BLU-${Random().nextInt(899999) + 100000}';
                              hubController.text = 'Blue Dart Cargo Depot, Jaipur';
                            } else {
                              awbController.text =
                                  'MLT-${Random().nextInt(899999) + 100000}';
                              hubController.text = 'Milterra Central Cold Depot';
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text('AWB / Tracking Number',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: storeMuted)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: awbController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Dispatch Facility / Hub Location',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: storeMuted)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: hubController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: storeGreen,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    _updateFulfillment(
                      order.id,
                      'DISPATCHED',
                      carrier: selectedCourier,
                      trackingNumber: awbController.text.trim(),
                      location: hubController.text.trim(),
                      remarks:
                          'Handed over to $selectedCourier. Consignment picked up for transit.',
                    );
                  },
                  icon: const Icon(Icons.send, size: 16),
                  label: const Text('Confirm & Dispatch'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(adminOrdersProvider);

    return Scaffold(
      backgroundColor: storeCream,
      appBar: AppBar(
        title: const Text('Milterra · Commerce Admin'),
        backgroundColor: storeGreen,
        foregroundColor: storeWhite,
        leading: IconButton(
          tooltip: 'Back to shop',
          onPressed: () => context.go('/shop'),
          icon: const Icon(Icons.storefront_outlined),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/admin/commerce'),
            icon: const Icon(Icons.category_outlined,
                color: storeAmber, size: 18),
            label: const Text('Categories',
                style: TextStyle(color: storeWhite)),
          ),
          TextButton.icon(
            onPressed: () => context.go('/admin/commerce/products'),
            icon: const Icon(Icons.inventory_2_outlined,
                color: storeAmber, size: 18),
            label: const Text('Products & Stock',
                style: TextStyle(color: storeWhite)),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Refresh orders',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(adminOrdersProvider),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _buildOrdersView(context, orders),
    );
  }

  Widget _buildOrdersView(BuildContext context, List<StoreOrder> orders) {
    var list = orders;
    if (_selectedStatus != 'All') {
      list = list.where((o) {
        final st = o.status.toUpperCase();
        if (_selectedStatus == 'Pending') {
          return st.contains('PENDING') || st.contains('CONFIRMED');
        } else if (_selectedStatus == 'Packed') {
          return st.contains('PACK');
        } else if (_selectedStatus == 'Shipped') {
          return st.contains('SHIP') || st.contains('DISPATCH');
        } else if (_selectedStatus == 'Delivered') {
          return st.contains('DELIVER');
        }
        return st.contains(_selectedStatus.toUpperCase());
      }).toList();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < StoreLayout.tablet;

        return SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: StoreLayout.maxWidth),
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 12 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Admin Tabs & Breadcrumbs
                    Row(
                      children: [
                        InkWell(
                          onTap: () => context.go('/shop'),
                          child: const Text('Milterra Storefront',
                              style: TextStyle(
                                  fontSize: 12, color: storeMuted)),
                        ),
                        const Text(' › ',
                            style:
                                TextStyle(fontSize: 12, color: storeMuted)),
                        const Text(
                            'Commerce Admin › Orders & Courier Fulfillment',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: storeGreen)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Customer Orders & Fulfillment',
                                style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: storeGreen)),
                            const SizedBox(height: 4),
                            Text(
                              '${orders.length} total orders · Real-time courier dispatch (DTDC, Delhivery) & tracking',
                              style: const TextStyle(
                                  fontSize: 13, color: storeMuted),
                            ),
                          ],
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: storeBorder),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => ref.invalidate(adminOrdersProvider),
                          icon: const Icon(Icons.sync,
                              size: 16, color: storeGreen),
                          label: const Text('Sync Orders',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: storeGreen)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Status Filters
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        'All',
                        'Pending',
                        'Packed',
                        'Shipped',
                        'Delivered'
                      ].map((st) {
                        final isSel = _selectedStatus == st;
                        return ChoiceChip(
                          label: Text(st),
                          selected: isSel,
                          selectedColor: storeGreen,
                          labelStyle: TextStyle(
                            color: isSel ? storeWhite : storeGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          onSelected: (_) =>
                              setState(() => _selectedStatus = st),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Orders List
                    if (list.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: storeWhite,
                          borderRadius:
                              BorderRadius.circular(StoreLayout.radius),
                          border: Border.all(color: storeBorder),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 48, color: storeMuted),
                            SizedBox(height: 12),
                            Text('No orders match the selected filter',
                                style: TextStyle(
                                    fontSize: 16, color: storeMuted)),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: list.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 18),
                        itemBuilder: (context, index) {
                          return _buildOrderAdminCard(context, list[index]);
                        },
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

  Widget _buildOrderAdminCard(BuildContext context, StoreOrder order) {
    final id = order.id;
    final currentStatus = order.status;
    final total = order.total;
    final createdAt = order.createdAt;
    final address = order.address;
    final recipient = address['recipient_name']?.toString() ?? 'Customer';
    final street = address['street_address']?.toString() ?? '';
    final city = address['city']?.toString() ?? '';
    final phone = address['phone_number']?.toString() ?? '';
    final items = order.items;

    Color badgeColor = const Color(0xff067d62);
    if (currentStatus.contains('PENDING') || currentStatus.contains('CONFIRMED')) {
      badgeColor = storeOrange;
    } else if (currentStatus.contains('PACKED')) {
      badgeColor = const Color(0xff0277bd);
    } else if (currentStatus.contains('DELIVERED')) {
      badgeColor = const Color(0xff2e7d32);
    }

    return Container(
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xfff5f7f6),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(StoreLayout.radius),
                topRight: Radius.circular(StoreLayout.radius),
              ),
              border: Border(bottom: BorderSide(color: storeBorder)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Wrap(
                  spacing: 20,
                  runSpacing: 4,
                  children: [
                    Text('ORDER # $id',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: storeGreen)),
                    Text('Date: $createdAt',
                        style: const TextStyle(
                            fontSize: 12, color: storeMuted)),
                    Text('Total: ${storeMoney(total)}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: storeOrange)),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xffe8f5e9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xffa5d6a7)),
                      ),
                      child: Text(
                        '${order.carrier} (${order.trackingNumber})',
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff1b5e20)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: badgeColor),
                      ),
                      child: Text(
                        currentStatus,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: badgeColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Recipient Details
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.person_pin_outlined,
                        color: storeGreen, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ship to: $recipient · $phone',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xff0f1111))),
                          Text('$street, $city',
                              style: const TextStyle(
                                  fontSize: 12, color: storeMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Line Items
                for (final item in items) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.check,
                            size: 14, color: storeGreen),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${item.title} × ${item.quantity}',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xff333333)),
                          ),
                        ),
                        Text(
                          storeMoney(item.lineTotal),
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: storeOrange),
                        ),
                      ],
                    ),
                  ),
                ],

                const Divider(height: 20),

                // Fulfillment Controls
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Progress Stage:',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: storeGreen)),
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        backgroundColor: currentStatus == 'PACKED'
                            ? storeGreen
                            : null,
                        foregroundColor: currentStatus == 'PACKED'
                            ? storeWhite
                            : null,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => _updateFulfillment(
                        id,
                        'PACKED',
                        location: 'Milterra Central Hub, Karnal',
                        remarks: 'Order packed in food-grade sealed pack.',
                      ),
                      child: const Text('1. Mark Packed',
                          style: TextStyle(fontSize: 11)),
                    ),
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        backgroundColor: currentStatus == 'DISPATCHED'
                            ? storeGreen
                            : null,
                        foregroundColor: currentStatus == 'DISPATCHED'
                            ? storeWhite
                            : null,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => _showDispatchDialog(context, order),
                      child: const Text('2. Dispatch via DTDC (AWB)',
                          style: TextStyle(fontSize: 11)),
                    ),
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        backgroundColor: currentStatus == 'OUT_FOR_DELIVERY'
                            ? storeGreen
                            : null,
                        foregroundColor: currentStatus == 'OUT_FOR_DELIVERY'
                            ? storeWhite
                            : null,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => _updateFulfillment(
                        id,
                        'OUT_FOR_DELIVERY',
                        location: 'City Sub-Hub',
                        remarks:
                            'Out for delivery with courier agent Rajesh.',
                      ),
                      child: const Text('3. Out for Delivery',
                          style: TextStyle(fontSize: 11)),
                    ),
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        backgroundColor: currentStatus == 'DELIVERED'
                            ? storeGreen
                            : null,
                        foregroundColor: currentStatus == 'DELIVERED'
                            ? storeWhite
                            : null,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => _updateFulfillment(
                        id,
                        'DELIVERED',
                        location: order.address['city']?.toString() ??
                            'Customer Address',
                        remarks: 'Delivered directly to recipient.',
                      ),
                      child: const Text('4. Mark Delivered',
                          style: TextStyle(fontSize: 11)),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact),
                      onPressed: () => context.go('/marketplace/orders/$id'),
                      icon: const Icon(Icons.open_in_new, size: 14),
                      label: const Text('Customer Tracking View',
                          style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
