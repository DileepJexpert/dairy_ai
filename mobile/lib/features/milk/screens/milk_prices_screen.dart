import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dairy_ai/core/extensions.dart';
import 'package:dairy_ai/features/milk/models/milk_models.dart';
import 'package:dairy_ai/features/milk/providers/milk_provider.dart';

/// Market prices screen showing district-wise milk prices,
/// best buyer suggestions, and price trends.
class MilkPricesScreen extends ConsumerStatefulWidget {
  const MilkPricesScreen({super.key});

  @override
  ConsumerState<MilkPricesScreen> createState() => _MilkPricesScreenState();
}

class _MilkPricesScreenState extends ConsumerState<MilkPricesScreen> {
  final _districtController = TextEditingController();

  @override
  void dispose() {
    _districtController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pricesAsync = ref.watch(milkPricesProvider);
    final selectedDistrict = ref.watch(milkDistrictProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Milk Prices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(milkPricesProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // --- District search ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _districtController,
              decoration: InputDecoration(
                hintText: 'Search by district',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: selectedDistrict != null &&
                        selectedDistrict.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _districtController.clear();
                          ref.read(milkDistrictProvider.notifier).state =
                              null;
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
              onSubmitted: (value) {
                ref.read(milkDistrictProvider.notifier).state =
                    value.trim().isNotEmpty ? value.trim() : null;
              },
            ),
          ),

          // --- Prices list ---
          Expanded(
            child: pricesAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator.adaptive()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: context.colorScheme.error),
                      const SizedBox(height: 12),
                      Text('Failed to load prices',
                          style: context.textTheme.bodyLarge),
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: () =>
                            ref.invalidate(milkPricesProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (prices) {
                if (prices.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.store,
                            size: 64,
                            color: Colors.grey.withOpacity(0.4)),
                        const SizedBox(height: 12),
                        Text(
                          selectedDistrict != null
                              ? 'No prices found for "$selectedDistrict"'
                              : 'No market prices available',
                          style: context.textTheme.bodyLarge
                              ?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return _PricesListView(prices: prices);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PricesListView extends StatelessWidget {
  final List<MilkPrice> prices;
  const _PricesListView({required this.prices});

  @override
  Widget build(BuildContext context) {
    // Group prices by district.
    final grouped = <String, List<MilkPrice>>{};
    for (final p in prices) {
      grouped.putIfAbsent(p.district, () => []).add(p);
    }

    // Sort districts alphabetically.
    final districts = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: districts.length,
      itemBuilder: (context, index) {
        final district = districts[index];
        final districtPrices = grouped[district]!
          ..sort((a, b) => b.pricePerLitre.compareTo(a.pricePerLitre));
        final bestPrice = districtPrices.first;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (index > 0) const SizedBox(height: 12),
            // District header
            Row(
              children: [
                const Icon(Icons.location_on, size: 18, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  district,
                  style: context.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Best buyer suggestion
            if (districtPrices.length > 1)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.green.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star,
                        size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: 'Best price: ',
                          style: context.textTheme.bodySmall,
                          children: [
                            TextSpan(
                              text:
                                  '${bestPrice.buyerName} @ Rs ${bestPrice.pricePerLitre.toStringAsFixed(1)}/L',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Price cards
            ...districtPrices.map(
              (price) => _PriceCard(
                price: price,
                isBest: price == bestPrice && districtPrices.length > 1,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PriceCard extends StatelessWidget {
  final MilkPrice price;
  final bool isBest;
  const _PriceCard({required this.price, this.isBest = false});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isBest
            ? BorderSide(color: Colors.green.withOpacity(0.4), width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        price.buyerName,
                        style: context.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (isBest) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'BEST',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        dateFormat.format(price.date),
                        style: context.textTheme.bodySmall
                            ?.copyWith(color: Colors.grey),
                      ),
                      if (price.fatPct != null) ...[
                        const SizedBox(width: 12),
                        Text(
                          'Fat: ${price.fatPct!.toStringAsFixed(1)}%',
                          style: context.textTheme.bodySmall
                              ?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Rs ${price.pricePerLitre.toStringAsFixed(1)}',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isBest ? Colors.green : null,
                  ),
                ),
                Text(
                  'per litre',
                  style: context.textTheme.bodySmall
                      ?.copyWith(color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
