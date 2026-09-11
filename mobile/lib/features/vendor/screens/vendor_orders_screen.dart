import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../cart/providers/order_repository.dart';
import '../../marketplace/widgets/store_design.dart';
import '../../admin/providers/admin_marketplace_provider.dart';

class VendorOrdersScreen extends ConsumerStatefulWidget {
  const VendorOrdersScreen({super.key});

  @override
  ConsumerState<VendorOrdersScreen> createState() => _VendorOrdersScreenState();
}

class _VendorOrdersScreenState extends ConsumerState<VendorOrdersScreen> {
  String _selectedFilter = 'ALL';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allOrders = ref.watch(ordersNotifierProvider);
    final query = _searchCtrl.text.trim().toLowerCase();

    final filteredOrders = allOrders.where((order) {
      final s = order.status.toUpperCase();
      if (_selectedFilter == 'NEW' && !s.contains('CONFIRMED') && !s.contains('PLACED') && !s.contains('PENDING')) {
        return false;
      }
      if (_selectedFilter == 'PACKED' && !s.contains('PACK')) {
        return false;
      }
      if (_selectedFilter == 'IN_TRANSIT' && !s.contains('DISPATCH') && !s.contains('OUT') && !s.contains('TRANSIT')) {
        return false;
      }
      if (_selectedFilter == 'DELIVERED' && !s.contains('DELIVERED')) {
        return false;
      }

      if (query.isNotEmpty) {
        final matchId = order.id.toLowerCase().contains(query);
        final matchName = (order.address['recipient_name']?.toString() ?? '').toLowerCase().contains(query);
        final matchCity = (order.address['city']?.toString() ?? '').toLowerCase().contains(query);
        final matchItem = order.items.any((i) => i.title.toLowerCase().contains(query));
        return matchId || matchName || matchCity || matchItem;
      }

      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xfff8fafc),
      appBar: AppBar(
        backgroundColor: const Color(0xff0d1b15),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: storeAmber,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('SELLER PORTAL',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: storeGreen)),
            ),
            const SizedBox(width: 10),
            const Text('Merchant Order Fulfillment & Dispatch Hub',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'View Marketplace',
            icon: const Icon(Icons.storefront_outlined),
            onPressed: () => context.push('/shop'),
          ),
          IconButton(
            tooltip: 'Refresh Queue',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;

          return Column(
            children: [
              // Top Stats & Quick Filter Strip
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _filterChip('ALL', 'All Orders (${allOrders.length})'),
                                const SizedBox(width: 8),
                                _filterChip('NEW', 'New / Awaiting Packing'),
                                const SizedBox(width: 8),
                                _filterChip('PACKED', 'Ready for Dispatch'),
                                const SizedBox(width: 8),
                                _filterChip('IN_TRANSIT', 'In Transit / Dispatched'),
                                const SizedBox(width: 8),
                                _filterChip('DELIVERED', 'Delivered'),
                              ],
                            ),
                          ),
                        ),
                        if (isWide) ...[
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 260,
                            height: 38,
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: 'Search order, buyer, AWB...',
                                hintStyle: const TextStyle(fontSize: 12),
                                prefixIcon: const Icon(Icons.search, size: 18),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: storeBorder),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: storeBorder),

              // Orders List
              Expanded(
                child: filteredOrders.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.all(18),
                        itemCount: filteredOrders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          return _buildOrderFulfillmentCard(context, filteredOrders[index], isWide);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _filterChip(String key, String label) {
    final selected = _selectedFilter == key;
    return ChoiceChip(
      selected: selected,
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        color: selected ? Colors.white : const Color(0xff334155),
      ),
      selectedColor: storeGreen,
      backgroundColor: const Color(0xfff1f5f9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (_) => setState(() => _selectedFilter = key),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_shipping_outlined, size: 64, color: storeMuted),
          const SizedBox(height: 14),
          const Text(
            'No orders found matching this filter',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: storeGreen),
          ),
          const SizedBox(height: 6),
          const Text(
            'All current customer orders have been processed and dispatched.',
            style: TextStyle(fontSize: 13, color: storeMuted),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => setState(() {
              _selectedFilter = 'ALL';
              _searchCtrl.clear();
            }),
            child: const Text('Reset Filter'),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderFulfillmentCard(BuildContext context, StoreOrder order, bool isWide) {
    final status = order.status.toUpperCase();
    final isNew = status.contains('CONFIRMED') || status.contains('PLACED') || status.contains('PENDING');
    final isPacked = status.contains('PACK');
    final isDispatched = status.contains('DISPATCH') || status.contains('SHIP') || status.contains('OUT') || status.contains('TRANSIT');
    final isDelivered = status.contains('DELIVERED');

    Color statusBg = const Color(0xffe2e8f0);
    Color statusFg = const Color(0xff334155);
    if (isNew) {
      statusBg = const Color(0xfffef3c7);
      statusFg = const Color(0xffb45309);
    } else if (isPacked) {
      statusBg = const Color(0xffe0f2fe);
      statusFg = const Color(0xff0369a1);
    } else if (isDispatched) {
      statusBg = const Color(0xffede9fe);
      statusFg = const Color(0xff6d28d9);
    } else if (isDelivered) {
      statusBg = const Color(0xffdcfce7);
      statusFg = const Color(0xff15803d);
    }

    final recipientName = order.address['recipient_name']?.toString() ?? 'Customer';
    final city = order.address['city']?.toString() ?? 'Jaipur';
    final state = order.address['state']?.toString() ?? 'Rajasthan';
    final street = order.address['street_address']?.toString() ?? 'Dairy Lane';
    final phone = order.address['phone_number']?.toString() ?? '+91 98000 00000';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xffe2e8f0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xfff8fafc),
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(bottom: BorderSide(color: Color(0xffe2e8f0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        order.status,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: statusFg),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '# ${order.id}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: storeGreen),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• ${order.createdAt}',
                      style: const TextStyle(fontSize: 12, color: storeMuted),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      storeMoney(order.total),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: storeGreen),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: order.paymentStatus.toUpperCase() == 'PAID'
                            ? const Color(0xffdcfce7)
                            : const Color(0xfffef3c7),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        order.paymentStatus,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: order.paymentStatus.toUpperCase() == 'PAID'
                              ? const Color(0xff166534)
                              : const Color(0xffb45309),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Content Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Buyer & Destination Details
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('SHIPPING DESTINATION',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: storeMuted, letterSpacing: 0.5)),
                          const SizedBox(height: 4),
                          Text(recipientName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          Text('$street, $city, $state', style: const TextStyle(fontSize: 12, color: Color(0xff475569))),
                          Text('Phone: $phone', style: const TextStyle(fontSize: 12, color: Color(0xff475569))),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.local_shipping, size: 14, color: storeGreen),
                              const SizedBox(width: 4),
                              Text(order.carrier, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: storeGreen)),
                              const SizedBox(width: 10),
                              const Icon(Icons.qr_code, size: 14, color: storeMuted),
                              const SizedBox(width: 4),
                              Text(order.trackingNumber, style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace', color: storeMuted)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Items List
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ORDERED ITEMS',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: storeMuted, letterSpacing: 0.5)),
                          const SizedBox(height: 6),
                          for (final item in order.items)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: const Color(0xfff1f5f9),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(Icons.inventory_2_outlined, size: 16, color: storeGreen),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${item.quantity}x ${item.title}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    storeMoney(item.lineTotal),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: storeGreen),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                const Divider(height: 24, color: Color(0xffe2e8f0)),

                // Action Operations Toolbar
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Print Shipping Label & Packing Slip
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xff1e293b),
                        side: const BorderSide(color: Color(0xffcbd5e1)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      icon: const Icon(Icons.print_outlined, size: 16),
                      label: const Text('Print Label & Packing Slip', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      onPressed: () => _showShippingLabelDialog(context, order),
                    ),

                    // Attach Lab Test Certificate
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: storeGreen,
                        side: const BorderSide(color: storeGreen),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      icon: const Icon(Icons.verified_outlined, size: 16),
                      label: const Text('Attach Lab Test Certificate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      onPressed: () => _showAttachCertificateDialog(context, order),
                    ),

                    // AWB & Dispatch Action
                    if (isNew)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xff0284c7),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        icon: const Icon(Icons.qr_code_2, size: 16),
                        label: const Text('Pack & Generate AWB', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () => _showGenerateAwbDialog(context, order),
                      )
                    else if (isPacked)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: storeGreen,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        icon: const Icon(Icons.local_shipping, size: 16),
                        label: const Text('Dispatch to Courier Partner', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          ref.read(ordersNotifierProvider.notifier).updateOrderStatus(
                            order.id,
                            'DISPATCHED',
                            remarks: 'Handed over to ${order.carrier} van for linehaul transit.',
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: storeGreen,
                              content: Text('Order #${order.id} marked as Dispatched!'),
                            ),
                          );
                        },
                      )
                    else if (isDispatched)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xff15803d),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        icon: const Icon(Icons.check_circle_outline, size: 16),
                        label: const Text('Simulate Delivery Confirmation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          ref.read(ordersNotifierProvider.notifier).updateOrderStatus(
                            order.id,
                            'DELIVERED',
                            remarks: 'Delivered to recipient with digital proof of delivery.',
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: storeGreen,
                              content: Text('Order #${order.id} marked as Delivered!'),
                            ),
                          );
                        },
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

  void _showGenerateAwbDialog(BuildContext context, StoreOrder order) {
    String selectedCarrier = 'DTDC Express Surface';
    double temperatureCelsius = 4.2;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Row(
                children: [
                  const Icon(Icons.local_shipping, color: storeGreen, size: 22),
                  const SizedBox(width: 10),
                  Text('Generate Dispatch AWB: #${order.id}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: storeGreen)),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Logistics Partner:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCarrier,
                      decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      items: const [
                        DropdownMenuItem(value: 'DTDC Express Surface', child: Text('DTDC Express Surface (1-2 Days)')),
                        DropdownMenuItem(value: 'Delhivery Cold-Chain Logistics', child: Text('Delhivery Cold-Chain Logistics')),
                        DropdownMenuItem(value: 'Blue Dart Surface Cargo', child: Text('Blue Dart Surface Cargo')),
                        DropdownMenuItem(value: 'Milterra Direct Rural Fleet', child: Text('Milterra Direct Rural Fleet')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedCarrier = val);
                      },
                    ),
                    const SizedBox(height: 14),
                    const Text('Cold-Chain Sensor Verification:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xfff0fdf4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xffbbf7d0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.ac_unit, color: storeGreen, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Pre-Dispatch Temperature: ${temperatureCelsius.toStringAsFixed(1)}°C',
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: storeGreen)),
                                const Text('Meets FSSAI Cold-Chain preservation standards (< 8°C).',
                                    style: TextStyle(fontSize: 10.5, color: Color(0xff166534))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel', style: TextStyle(color: storeMuted)),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: storeGreen),
                  onPressed: () {
                    final awb = 'AWB-${Random().nextInt(899999) + 100000}';
                    ref.read(ordersNotifierProvider.notifier).updateOrderStatus(
                      order.id,
                      'PACKED',
                      carrier: selectedCarrier,
                      trackingNumber: awb,
                      remarks: 'Packed and sealed in insulated crate. Monitored temperature: ${temperatureCelsius.toStringAsFixed(1)}°C.',
                    );
                    Navigator.pop(dialogCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: storeGreen,
                        content: Text('AWB $awb generated! Order status set to PACKED.'),
                      ),
                    );
                  },
                  child: const Text('Generate AWB & Mark Packed'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showShippingLabelDialog(BuildContext context, StoreOrder order) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Label Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: storeGreen, borderRadius: BorderRadius.circular(6)),
                            child: const Icon(Icons.local_shipping, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(order.carrier.toUpperCase(),
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: storeGreen)),
                              const Text('PRIORITY EXPRESS LOGISTICS', style: TextStyle(fontSize: 9, color: storeMuted)),
                            ],
                          ),
                        ],
                      ),
                      Text(
                        'AWB: ${order.trackingNumber}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                  const Divider(height: 20, thickness: 1.5),

                  // Simulated Barcode
                  Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (int i = 0; i < 35; i++)
                          Container(
                            width: (i % 3 == 0) ? 3 : (i % 2 == 0) ? 1.5 : 2,
                            height: 38,
                            color: Colors.black,
                            margin: const EdgeInsets.symmetric(horizontal: 1.2),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Sender & Recipient Box
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xfff8fafc),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xffe2e8f0)),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('DISPATCH FROM:', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: storeMuted)),
                              SizedBox(height: 4),
                              Text('Milterra Fulfillment Hub #4', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              Text('Karnal Dairy Corridor, Gate 4\nHaryana - 132001\nGSTIN: 06AAACM9921D1Z4',
                                  style: TextStyle(fontSize: 10, color: Color(0xff475569))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xfff8fafc),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xffe2e8f0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('SHIP TO:', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: storeMuted)),
                              const SizedBox(height: 4),
                              Text(order.address['recipient_name']?.toString() ?? 'Buyer',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              Text(
                                '${order.address['street_address']}\n${order.address['city']}, ${order.address['state']} - ${order.address['postal_code'] ?? '302001'}\nPhone: ${order.address['phone_number']}',
                                style: const TextStyle(fontSize: 10, color: Color(0xff475569)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Packing Manifest Slip
                  const Text('PACKING MANIFEST', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: storeMuted)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xffe2e8f0)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      children: [
                        for (final item in order.items)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                const Icon(Icons.check_box_outlined, size: 14, color: storeGreen),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${item.quantity}x ${item.title}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                                Text(
                                  storeMoney(item.lineTotal),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx),
                        child: const Text('Close'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: storeGreen),
                        icon: const Icon(Icons.print, size: 16),
                        label: const Text('Print Dispatch Manifest'),
                        onPressed: () {
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: storeGreen,
                              content: Text('Shipping label sent to thermal warehouse printer!'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAttachCertificateDialog(BuildContext context, StoreOrder order) {
    final certificates = ref.watch(adminMarketplaceProvider).batchCertificates;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.verified, color: storeGreen, size: 22),
            const SizedBox(width: 10),
            Text('Attach Lab Certificate to #${order.id}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: storeGreen)),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select certified batch report for items in this shipment:',
                  style: TextStyle(fontSize: 12, color: Color(0xff475569))),
              const SizedBox(height: 12),
              for (final cert in certificates)
                Card(
                  elevation: 0,
                  color: const Color(0xfff8fafc),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Color(0xffe2e8f0)),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.science, color: storeGreen),
                    title: Text('${cert.batchNumber} · ${cert.productTitle}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    subtitle: Text('Purity: ${cert.purityPercent}% | ${cert.laboratory}',
                        style: const TextStyle(fontSize: 10.5, color: storeMuted)),
                    trailing: FilledButton.tonal(
                      onPressed: () {
                        Navigator.pop(dialogCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: storeGreen,
                            content: Text('Batch #${cert.batchNumber} test certificate attached to Order #${order.id}!'),
                          ),
                        );
                      },
                      child: const Text('Attach', style: TextStyle(fontSize: 11)),
                    ),
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
        ],
      ),
    );
  }
}
