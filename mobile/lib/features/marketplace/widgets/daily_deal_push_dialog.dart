import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/product_provider.dart';
import '../providers/merchandising_provider.dart';
import 'store_design.dart';

/// Opens the admin control panel dialog to push a product as the
/// "Highlighted Product of the Day", "Top Seller of the Day", or "New Launch".
Future<void> showPushDailyDealDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (context) => const _PushDailyDealDialog(),
  );
}

class _PushDailyDealDialog extends ConsumerStatefulWidget {
  const _PushDailyDealDialog();

  @override
  ConsumerState<_PushDailyDealDialog> createState() =>
      _PushDailyDealDialogState();
}

class _PushDailyDealDialogState extends ConsumerState<_PushDailyDealDialog> {
  String? _selectedProductId;
  String _selectedBadge = '⚡ TOP SELLER OF THE DAY';
  String _selectedType = 'highlight';
  final TextEditingController _headlineController =
      TextEditingController(text: 'Direct Farm Harvest · Limited Daily Batch');
  bool _isSaving = false;

  final List<String> _badgeOptions = [
    '⚡ TOP SELLER OF THE DAY',
    '🔥 PRODUCT OF THE DAY',
    '✨ NEW LAUNCH',
    '🎯 LIMITED BATCH HARVEST',
    '🏆 VEDIC HERITAGE SPECIAL',
  ];

  final Map<String, String> _typeMap = {
    'highlight': 'Hero Highlight',
    'deal': 'Lightning Deal',
    'new_launch': 'New Launch',
  };

  @override
  void dispose() {
    _headlineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider(null)).valueOrNull ?? [];
    final activeProducts =
        products.where((p) => p.isActive && !p.isConcept).toList();
    final placements =
        ref.watch(storefrontPlacementsProvider).valueOrNull ?? [];

    StorefrontPlacement? currentHighlight;
    for (final pl in placements) {
      if (pl.isActive &&
          (pl.placementType == 'highlight' ||
              pl.placementType == 'deal' ||
              pl.placementType == 'new_launch')) {
        currentHighlight = pl;
        break;
      }
    }

    if (_selectedProductId == null && activeProducts.isNotEmpty) {
      _selectedProductId = currentHighlight?.productId ?? activeProducts.first.id;
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 30,
              offset: Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xffb45309), Color(0xffd97706), Color(0xff164e2e)],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.local_fire_department,
                        color: Color(0xfffef08a), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STOREFRONT HERO ENGINE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xfffef08a),
                            letterSpacing: 1.0,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Push Highlighted Product of the Day',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
            ),

            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Active Live Banner status
                    if (currentHighlight != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xfff0fdf4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xffbbf7d0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle,
                                color: Color(0xff16a34a), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'CURRENTLY LIVE: ',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xff166534),
                                        ),
                                      ),
                                      Text(
                                        currentHighlight.badge ?? 'TOP SELLER',
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xffb45309),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    currentHighlight.product.title,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xff1e293b),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    const Text(
                      '1. Select Product to Highlight',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xff1e293b),
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedProductId,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xffcbd5e1)),
                        ),
                      ),
                      items: activeProducts.map((p) {
                        return DropdownMenuItem<String>(
                          value: p.id,
                          child: Text(
                            '${p.title} (${storeMoney(p.price)})',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedProductId = val);
                      },
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      '2. Choose Live Beacon Badge',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xff1e293b),
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedBadge,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xffcbd5e1)),
                        ),
                      ),
                      items: _badgeOptions.map((b) {
                        return DropdownMenuItem<String>(
                          value: b,
                          child: Text(
                            b,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedBadge = val);
                      },
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      '3. Highlight Catchphrase / Headline',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xff1e293b),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _headlineController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Pure Vedic Clay-Pot Churn · Limited Stock',
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xffcbd5e1)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Placement Type Radio Chips
                    const Text(
                      '4. Placement Style',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xff1e293b),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: _typeMap.entries.map((e) {
                        final isSel = _selectedType == e.key;
                        return ChoiceChip(
                          selected: isSel,
                          label: Text(e.value),
                          selectedColor: const Color(0xffb45309),
                          backgroundColor: const Color(0xfff1f5f9),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSel ? Colors.white : const Color(0xff334155),
                          ),
                          onSelected: (val) {
                            if (val) setState(() => _selectedType = e.key);
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            // Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xfff8fafc),
                border: Border(top: BorderSide(color: Color(0xffe2e8f0))),
              ),
              child: Row(
                children: [
                  OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xff164e2e),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                    ),
                    onPressed: _isSaving ? null : _pushLive,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.rocket_launch, size: 16),
                    label: Text(
                      _isSaving ? 'Pushing...' : '🚀 Push to Storefront Live',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pushLive() async {
    if (_selectedProductId == null) return;
    setState(() => _isSaving = true);

    try {
      final repo = ref.read(merchandisingRepositoryProvider);

      // Deactivate any existing active highlight placements first
      final currentPlacements =
          await repo.list(admin: true);
      for (final pl in currentPlacements) {
        if (pl.isActive &&
            (pl.placementType == 'highlight' ||
                pl.placementType == 'deal' ||
                pl.placementType == 'new_launch')) {
          await repo.setActive(pl.id, false);
        }
      }

      // Create new highlight placement
      await repo.create(
        productId: _selectedProductId!,
        placementType: _selectedType,
        headline: _headlineController.text.trim().isNotEmpty
            ? _headlineController.text.trim()
            : 'Featured Farm Deal of the Day',
        badge: _selectedBadge,
        priority: 999,
        startsAt: DateTime.now().subtract(const Duration(minutes: 5)),
        endsAt: DateTime.now().add(const Duration(days: 30)),
      );

      // Refresh providers
      ref.invalidate(storefrontPlacementsProvider);
      ref.invalidate(adminStorefrontPlacementsProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xff15803d),
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$_selectedBadge is now LIVE on the Storefront Hero Carousel!',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not push deal: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
