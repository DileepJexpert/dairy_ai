import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/marketplace_models.dart';
import '../providers/marketplace_provider.dart';

class MarketplaceScreen extends ConsumerWidget {
  const MarketplaceScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(marketplaceListingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Marketplace')),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/marketplace/sell'),
          icon: const Icon(Icons.add),
          label: const Text('Sell cattle')),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(children: [
              Expanded(
                  child: OutlinedButton.icon(
                      onPressed: () => context.push('/marketplace/feed'),
                      icon: const Icon(Icons.grass),
                      label: const Text('Feed & Nutrition'))),
              const SizedBox(width: 8),
              Expanded(
                  child: OutlinedButton.icon(
                      onPressed: () => context.push('/marketplace/equipment'),
                      icon: const Icon(Icons.agriculture),
                      label: const Text('Equipment'))),
            ])),
        const Padding(
            padding: EdgeInsets.only(top: 10), child: Text('Buy Animals')),
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              _chip(ref, null, 'All'),
              ...ListingCategory.values.map((x) => _chip(ref, x, x.name)),
            ])),
        Expanded(
            child: data.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load listings: $e')),
          data: (items) => RefreshIndicator(
            onRefresh: () =>
                ref.read(marketplaceListingsProvider.notifier).refresh(),
            child: items.isEmpty
                ? ListView(children: const [
                    SizedBox(height: 220),
                    Center(child: Text('No cattle listings found'))
                  ])
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (_, i) => _card(context, ref, items[i])),
          ),
        )),
      ]),
    );
  }

  Widget _chip(WidgetRef ref, ListingCategory? value, String label) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
          label: Text(label),
          selected: value == ref.watch(marketplaceFilterProvider).category,
          onSelected: (_) {
            ref.read(marketplaceFilterProvider.notifier).state =
                MarketplaceFilter(category: value);
            ref.read(marketplaceListingsProvider.notifier).refresh();
          }));
  Widget _card(BuildContext context, WidgetRef ref, MarketplaceListing x) => Card(
      child: ListTile(
          onTap: () => context.push('/marketplace/listing/${x.id}'),
          leading: SizedBox(
              width: 64,
              height: 64,
              child: x.photos.isEmpty
                  ? const Icon(Icons.pets, size: 38)
                  : Image.network(x.photos.first,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.pets))),
          title: Text(x.title),
          subtitle: Text(
              '${x.breed ?? x.category.name}\n${NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(x.price)} • ${[
            x.locationDistrict,
            x.locationState
          ].whereType<String>().join(', ')}'),
          isThreeLine: true,
          trailing: IconButton(
              icon: Icon(x.isFavorited ? Icons.favorite : Icons.favorite_border,
                  color: Colors.red),
              onPressed: () => ref
                  .read(marketplaceListingsProvider.notifier)
                  .toggleFavorite(x))));
}
