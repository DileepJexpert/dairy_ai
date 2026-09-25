import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/delivery_address.dart';
import '../providers/cart_provider.dart';
import '../providers/delivery_address_provider.dart';
import '../widgets/address_location_fields.dart';
import '../../marketplace/widgets/store_design.dart';

class DeliveryAddressesScreen extends ConsumerWidget {
  const DeliveryAddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(deliveryAddressesProvider);
    final cartCount = ref.watch(cartItemCountProvider);

    return Scaffold(
      backgroundColor: storeCream,
      body: Column(
        children: [
          // Store Top Header & Navigation
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
                                // Breadcrumbs and Cart quick-return row
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Wrap(
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        InkWell(
                                          onTap: () => context.go('/account'),
                                          child: const Text('Your Account',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: storeMuted)),
                                        ),
                                        const Text(' › ',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: storeMuted)),
                                        if (cartCount > 0) ...[
                                          InkWell(
                                            onTap: () =>
                                                context.go('/marketplace/cart'),
                                            child: Text('Cart ($cartCount)',
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: storeMuted)),
                                          ),
                                          const Text(' › ',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: storeMuted)),
                                        ],
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
                                    // Header Action Buttons
                                    Wrap(
                                      spacing: 8,
                                      children: [
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: storeGreen,
                                            side: const BorderSide(
                                                color: storeBorder),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 8),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                          ),
                                          icon: const Icon(Icons.arrow_back,
                                              size: 15),
                                          label: Text(
                                            cartCount > 0
                                                ? 'Back to Cart ($cartCount)'
                                                : 'Back to Cart',
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600),
                                          ),
                                          onPressed: () =>
                                              context.go('/marketplace/cart'),
                                        ),
                                        FilledButton.icon(
                                          style: FilledButton.styleFrom(
                                            backgroundColor: storeAmber,
                                            foregroundColor: storeGreen,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 8),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                          ),
                                          icon: const Icon(Icons.add, size: 16),
                                          label: const Text(
                                            'Add Address',
                                            style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          onPressed: () =>
                                              _showAddressForm(context, ref),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Title & Subtitle
                                const Text(
                                  'Your Addresses',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: storeGreen,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Add, update, or remove your saved shipping and billing addresses for 1-click checkout.',
                                  style: TextStyle(
                                      fontSize: 13, color: storeMuted),
                                ),
                                const SizedBox(height: 18),

                                // Cart Helper Alert Banner
                                if (cartCount > 0)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 20),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xfff0fdf4),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: const Color(0xff86efac)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.shopping_bag_outlined,
                                            color: storeGreen, size: 24),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'You have $cartCount item${cartCount > 1 ? 's' : ''} in your cart.',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: storeGreen,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              const Text(
                                                'Select any address below and tap "Deliver to this Address" to return directly to your cart.',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xff374151)),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        FilledButton.tonal(
                                          style: FilledButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xffdcfce7),
                                            foregroundColor: storeGreen,
                                          ),
                                          onPressed: () =>
                                              context.go('/marketplace/cart'),
                                          child: const Text('Return to Cart'),
                                        ),
                                      ],
                                    ),
                                  ),

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
                                        final cardWidth = ((space.maxWidth -
                                                    16 * (columns - 1)) /
                                                columns)
                                            .clamp(280.0, space.maxWidth);

                                        return Wrap(
                                          spacing: 16,
                                          runSpacing: 16,
                                          children: [
                                            // Add Address Card
                                            SizedBox(
                                              width: cardWidth,
                                              height: 310,
                                              child: _buildAddAddressCard(
                                                  context, ref),
                                            ),

                                            // Existing Addresses Cards
                                            for (final address in items)
                                              SizedBox(
                                                width: cardWidth,
                                                height: 310,
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
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xfff5f7f6),
                  shape: BoxShape.circle,
                  border: Border.all(color: storeBorder),
                ),
                child: const Icon(Icons.add_location_alt_outlined,
                    size: 30, color: storeGreen),
              ),
              const SizedBox(height: 14),
              const Text(
                'Add address',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: storeGreen,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Deliver to a new location',
                style: TextStyle(fontSize: 12, color: storeMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddressCard(
      BuildContext context, WidgetRef ref, DeliveryAddress address) {
    final addressType = _detectAddressType(address);

    return Container(
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(
          color: address.isDefault ? storeAmber : storeBorder,
          width: address.isDefault ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Default Tag & Address Type
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: address.isDefault
                  ? const Color(0xfffef8ee)
                  : const Color(0xfff8fafc),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(StoreLayout.radius),
                topRight: Radius.circular(StoreLayout.radius),
              ),
              border: Border(
                bottom: BorderSide(
                  color: address.isDefault ? storeAmber : storeBorder,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Tag: Default Badge
                if (address.isDefault)
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 14, color: storeOrange),
                      SizedBox(width: 4),
                      Text(
                        'Default address',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: storeOrange,
                        ),
                      ),
                    ],
                  )
                else
                  const SizedBox.shrink(),

                // Address Type Tag Chip (Home / Work / Other)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _typeColor(addressType).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _typeColor(addressType).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_typeIcon(addressType),
                          size: 11, color: _typeColor(addressType)),
                      const SizedBox(width: 4),
                      Text(
                        addressType.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _typeColor(addressType),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Address Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Recipient Name
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 12,
                        backgroundColor: Color(0xffe2e8f0),
                        child: Icon(Icons.person,
                            size: 14, color: Color(0xff475569)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          address.recipientName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xff0f1111),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Street line 1
                  Text(
                    address.addressLine1,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xff1f2937),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Landmark if present
                  if (address.landmark != null &&
                      address.landmark!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 12, color: storeMuted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Landmark: ${address.landmark!.trim()}',
                            style: const TextStyle(
                                fontSize: 11, color: storeMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // City, District, State - PIN
                  const SizedBox(height: 4),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${address.villageOrCity}, ${address.district}, ${address.state} ',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xff4b5563),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xfff1f5f9),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          address.postalCode,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: storeDarkGreenNav,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Phone Number
                  const Spacer(),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined,
                          size: 13, color: storeMuted),
                      const SizedBox(width: 6),
                      Text(
                        '+91 ${address.phone}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xff334155),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 1),

          // Actions Row: Deliver Here + Edit + Default + Remove
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Deliver Here Button (fast return to Cart)
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: address.isDefault
                          ? storeAmber
                          : const Color(0xfffef3c7),
                      foregroundColor: storeGreen,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    icon: const Icon(Icons.local_shipping_outlined, size: 14),
                    label: const Text(
                      'Deliver Here',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      if (!address.isDefault) {
                        await ref
                            .read(deliveryAddressesProvider.notifier)
                            .makeDefault(address.id);
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: storeGreen,
                            content: Text(
                              'Delivery set to ${address.recipientName} (${address.postalCode}). Returning to cart…',
                            ),
                          ),
                        );
                        context.go('/marketplace/cart');
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),

                // Edit Action
                IconButton(
                  tooltip: 'Edit Address',
                  icon: const Icon(Icons.edit_outlined,
                      size: 18, color: Color(0xff007185)),
                  onPressed: () => _showAddressForm(
                    context,
                    ref,
                    initialAddress: address,
                  ),
                ),

                // Make Default (if not already)
                if (!address.isDefault)
                  IconButton(
                    tooltip: 'Set as Default Address',
                    icon: const Icon(Icons.star_outline,
                        size: 19, color: storeOrange),
                    onPressed: () async {
                      await ref
                          .read(deliveryAddressesProvider.notifier)
                          .makeDefault(address.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: storeGreen,
                            content: Text('Default address updated.'),
                          ),
                        );
                      }
                    },
                  ),

                // Remove Action with Confirmation
                IconButton(
                  tooltip: 'Remove Address',
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: Color(0xffdc2626)),
                  onPressed: () => _confirmDelete(context, ref, address),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, DeliveryAddress address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Address?'),
        content: Text(
          'Are you sure you want to delete the delivery address for "${address.recipientName}" at ${address.villageOrCity} (${address.postalCode})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xffdc2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(deliveryAddressesProvider.notifier).delete(address.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Address removed successfully.')),
        );
      }
    }
  }

  Future<void> _showAddressForm(BuildContext context, WidgetRef ref,
      {DeliveryAddress? initialAddress}) async {
    final isEditing = initialAddress != null;
    final formKey = GlobalKey<FormState>();

    var selectedType = isEditing ? _detectAddressType(initialAddress) : 'Home';
    var isDefault = isEditing ? initialAddress.isDefault : false;
    var isSaving = false;

    final fields = <String, TextEditingController>{
      'recipient_name': TextEditingController(
          text: isEditing ? initialAddress.recipientName : ''),
      'phone':
          TextEditingController(text: isEditing ? initialAddress.phone : ''),
      'address_line1': TextEditingController(
          text: isEditing ? initialAddress.addressLine1 : ''),
      'landmark': TextEditingController(
          text: isEditing ? (initialAddress.landmark ?? '') : ''),
      'village_or_city': TextEditingController(
          text: isEditing ? initialAddress.villageOrCity : ''),
      'district':
          TextEditingController(text: isEditing ? initialAddress.district : ''),
      'state':
          TextEditingController(text: isEditing ? initialAddress.state : ''),
      'postal_code': TextEditingController(
          text: isEditing ? initialAddress.postalCode : ''),
    };

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: storeWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.viewInsetsOf(sheetContext).bottom + 24),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEditing
                            ? 'Edit Delivery Address'
                            : 'Add a New Delivery Address',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: storeGreen,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Address Type Selector Chips
                  const Text('Address Type',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    children: ['Home', 'Work', 'Other'].map((type) {
                      final selected = selectedType == type;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          avatar: Icon(_typeIcon(type),
                              size: 15,
                              color: selected ? Colors.white : storeGreen),
                          label: Text(type),
                          selected: selected,
                          selectedColor: storeGreen,
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : Colors.black87,
                            fontWeight:
                                selected ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (val) {
                            if (val) setModalState(() => selectedType = type);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Name & Phone Row
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: fields['recipient_name'],
                          decoration: const InputDecoration(
                            labelText: 'Full Name *',
                            hintText: 'First and last name',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                          ),
                          validator: (v) => v == null || v.trim().length < 2
                              ? 'Enter full name'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: fields['phone'],
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: '10-Digit Mobile *',
                            prefixText: '+91 ',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                          ),
                          validator: (v) {
                            final text =
                                (v ?? '').replaceAll(RegExp(r'\D'), '');
                            return text.length < 8 || text.length > 12
                                ? 'Valid mobile required'
                                : null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Flat, House no.
                  TextFormField(
                    controller: fields['address_line1'],
                    decoration: const InputDecoration(
                      labelText: 'Flat, House no., Building, Apartment *',
                      hintText: 'e.g. Flat 402, Lotus Court',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    validator: (v) => v == null || v.trim().length < 3
                        ? 'Flat/house details required'
                        : null,
                  ),
                  const SizedBox(height: 12),

                  // Landmark
                  TextFormField(
                    controller: fields['landmark'],
                    decoration: const InputDecoration(
                      labelText: 'Landmark (Optional)',
                      hintText: 'e.g. Near City Hospital / Metro Gate 2',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  AddressLocationFields(
                    pin: fields['postal_code']!,
                    city: fields['village_or_city']!,
                    stateName: fields['state']!,
                    district: fields['district']!,
                  ),
                  const SizedBox(height: 8),

                  // Default Address Switch
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Make this my default delivery address',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    value: isDefault,
                    activeColor: storeGreen,
                    onChanged: (val) =>
                        setModalState(() => isDefault = val ?? false),
                  ),
                  const SizedBox(height: 12),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: storeAmber,
                        foregroundColor: storeGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(StoreLayout.radius),
                        ),
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setModalState(() => isSaving = true);

                              final payload = <String, dynamic>{
                                'recipient_name':
                                    fields['recipient_name']!.text.trim(),
                                'phone': fields['phone']!.text.trim(),
                                'address_line1':
                                    fields['address_line1']!.text.trim(),
                                'address_line2': selectedType,
                                'landmark':
                                    fields['landmark']!.text.trim().isNotEmpty
                                        ? fields['landmark']!.text.trim()
                                        : null,
                                'village_or_city':
                                    fields['village_or_city']!.text.trim(),
                                'district': fields['district']!.text.trim(),
                                'state': fields['state']!.text.trim(),
                                'postal_code':
                                    fields['postal_code']!.text.trim(),
                                'is_default': isDefault,
                              };

                              try {
                                if (isEditing) {
                                  await ref
                                      .read(deliveryAddressesProvider.notifier)
                                      .update(initialAddress.id, payload);
                                } else {
                                  await ref
                                      .read(deliveryAddressesProvider.notifier)
                                      .create(payload);
                                }

                                if (sheetContext.mounted) {
                                  Navigator.pop(sheetContext);
                                }

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: storeGreen,
                                      content: Text(isEditing
                                          ? 'Address updated successfully!'
                                          : 'New delivery address added!'),
                                    ),
                                  );
                                }
                              } catch (err) {
                                setModalState(() => isSaving = false);
                                if (sheetContext.mounted) {
                                  ScaffoldMessenger.of(sheetContext)
                                      .showSnackBar(
                                    SnackBar(
                                      backgroundColor: storeError,
                                      content:
                                          Text('Error saving address: $err'),
                                    ),
                                  );
                                }
                              }
                            },
                      child: isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: storeGreen,
                              ),
                            )
                          : Text(
                              isEditing ? 'Update Address' : 'Save Address',
                              style: const TextStyle(
                                fontSize: 15,
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
      ),
    );

    for (final controller in fields.values) {
      controller.dispose();
    }
  }

  static String _detectAddressType(DeliveryAddress address) {
    final line2 = (address.addressLine2 ?? '').trim().toLowerCase();
    if (line2.contains('work') || line2.contains('office')) return 'Work';
    if (line2.contains('other')) return 'Other';
    if (line2.contains('home')) return 'Home';
    final lmark = (address.landmark ?? '').trim().toLowerCase();
    if (lmark.contains('office') || lmark.contains('work')) return 'Work';
    return 'Home';
  }

  static IconData _typeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'work':
      case 'office':
        return Icons.business_outlined;
      case 'other':
        return Icons.location_on_outlined;
      default:
        return Icons.home_outlined;
    }
  }

  static Color _typeColor(String type) {
    switch (type.toLowerCase()) {
      case 'work':
      case 'office':
        return const Color(0xff2563eb);
      case 'other':
        return const Color(0xff475569);
      default:
        return const Color(0xff0d9488);
    }
  }
}
