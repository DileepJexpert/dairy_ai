import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/delivery_address.dart';
import '../providers/delivery_address_provider.dart';
import '../../marketplace/widgets/store_design.dart';

class DeliveryAddressesScreen extends ConsumerWidget {
  const DeliveryAddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(deliveryAddressesProvider);

    return Scaffold(
      backgroundColor: storeCream,
      body: Column(
        children: [
          // Amazon Top Navigation
          const StoreHeader(currentCategory: 'All'),
          const StoreCategoryNavigation(selected: 'Your Addresses'),

          // Main Addresses Container
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < StoreLayout.tablet;

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                              maxWidth: StoreLayout.maxWidth),
                          child: Padding(
                            padding: EdgeInsets.all(isMobile ? 12 : 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Breadcrumbs
                                Wrap(
                                  children: [
                                    InkWell(
                                      onTap: () => context.go('/shop'),
                                      child: const Text('Your Account',
                                          style: TextStyle(
                                              fontSize: 12, color: storeMuted)),
                                    ),
                                    const Text(' › ',
                                        style: TextStyle(
                                            fontSize: 12, color: storeMuted)),
                                    const Text(
                                      'Your Addresses',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: storeGreen,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                const Text(
                                  'Your Addresses',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: storeGreen,
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Addresses Grid / List
                                addresses.when(
                                  loading: () => const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(48),
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                  error: (e, _) => Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(32),
                                      child: Column(
                                        children: [
                                          Text('Could not load addresses: $e',
                                              style: StoreType.body),
                                          const SizedBox(height: 12),
                                          OutlinedButton(
                                            onPressed: () => ref
                                                .read(deliveryAddressesProvider
                                                    .notifier)
                                                .refresh(),
                                            child: const Text('Try again'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  data: (items) {
                                    return LayoutBuilder(
                                      builder: (context, space) {
                                        final columns = isMobile
                                            ? 1
                                            : (space.maxWidth >= 900 ? 3 : 2);
                                        final cardWidth =
                                            ((space.maxWidth - 16 * (columns - 1)) /
                                                    columns)
                                                .clamp(260.0, space.maxWidth);

                                        return Wrap(
                                          spacing: 16,
                                          runSpacing: 16,
                                          children: [
                                            // Add Address Card
                                            SizedBox(
                                              width: cardWidth,
                                              height: 240,
                                              child: _buildAddAddressCard(
                                                  context, ref),
                                            ),

                                            // Existing Addresses Cards
                                            for (final address in items)
                                              SizedBox(
                                                width: cardWidth,
                                                height: 240,
                                                child: _buildAddressCard(
                                                    context, ref, address),
                                              ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const StoreFooter(),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddAddressCard(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => _showAddressForm(context, ref),
      borderRadius: BorderRadius.circular(StoreLayout.radius),
      child: Container(
        decoration: BoxDecoration(
          color: storeWhite,
          borderRadius: BorderRadius.circular(StoreLayout.radius),
          border: Border.all(
            color: storeBorder,
            width: 2,
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 48, color: storeMuted),
              SizedBox(height: 12),
              Text(
                'Add address',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: storeGreen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddressCard(
      BuildContext context, WidgetRef ref, DeliveryAddress address) {
    return Container(
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(
          color: address.isDefault ? storeAmber : storeBorder,
          width: address.isDefault ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Default Tag
          if (address.isDefault)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: const BoxDecoration(
                color: Color(0xfffcf5ee),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(StoreLayout.radius),
                  topRight: Radius.circular(StoreLayout.radius),
                ),
                border: Border(bottom: BorderSide(color: storeAmber)),
              ),
              child: const Text(
                'Default address',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: storeOrange,
                ),
              ),
            ),

          // Address Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    address.recipientName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xff0f1111),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    address.summary,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xff333333),
                      height: 1.35,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Phone number: ${address.phone}',
                    style: const TextStyle(fontSize: 12, color: storeMuted),
                  ),
                ],
              ),
            ),
          ),

          // Actions Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (!address.isDefault) ...[
                  InkWell(
                    onTap: () => ref
                        .read(deliveryAddressesProvider.notifier)
                        .makeDefault(address.id),
                    child: const Text(
                      'Set as Default',
                      style: TextStyle(fontSize: 12, color: Color(0xff007185)),
                    ),
                  ),
                  const Text('|', style: TextStyle(color: storeBorder)),
                ],
                InkWell(
                  onTap: () => ref
                      .read(deliveryAddressesProvider.notifier)
                      .delete(address.id),
                  child: const Text(
                    'Remove',
                    style: TextStyle(fontSize: 12, color: Color(0xff007185)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddressForm(BuildContext context, WidgetRef ref) async {
    final formKey = GlobalKey<FormState>();
    final fields = <String, TextEditingController>{
      for (final key in [
        'recipient_name',
        'phone',
        'address_line1',
        'village_or_city',
        'district',
        'state',
        'postal_code'
      ])
        key: TextEditingController(),
    };

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: storeWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.viewInsetsOf(sheetContext).bottom + 24),
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add a new delivery address',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: storeGreen,
                  ),
                ),
                const SizedBox(height: 16),
                for (final field in [
                  ('recipient_name', 'Full name (First and Last name)'),
                  ('phone', 'Mobile number (10 digits)'),
                  ('address_line1', 'Flat, House no., Building, Company, Apartment'),
                  ('village_or_city', 'Town / Village / City'),
                  ('district', 'District / Tehsil'),
                  ('state', 'State'),
                  ('postal_code', '6-digit PIN code'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      controller: fields[field.$1],
                      keyboardType:
                          field.$1 == 'phone' || field.$1 == 'postal_code'
                              ? TextInputType.phone
                              : TextInputType.text,
                      decoration: InputDecoration(
                        labelText: field.$2,
                        filled: true,
                        fillColor: const Color(0xfffcfcfc),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: storeBorder),
                        ),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Required'
                              : null,
                    ),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: storeAmber,
                      foregroundColor: storeGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(21),
                      ),
                    ),
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      if (fields['postal_code']!.text.trim().length != 6) return;
                      await ref.read(deliveryAddressesProvider.notifier).create({
                        for (final entry in fields.entries)
                          entry.key: entry.value.text.trim(),
                      });
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    },
                    child: const Text(
                      'Add Address',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    for (final controller in fields.values) {
      controller.dispose();
    }
  }
}

