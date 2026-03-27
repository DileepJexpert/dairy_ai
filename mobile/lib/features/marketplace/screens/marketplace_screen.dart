import 'package:flutter/material.dart';
import 'package:dairy_ai/app/theme.dart';
import 'package:dairy_ai/features/marketplace/models/marketplace_models.dart';

/// Marketplace placeholder screen with category tabs, coming soon banner,
/// and sample listing cards.
class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketplace'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.pets, size: 20), text: 'Cattle'),
            Tab(icon: Icon(Icons.build, size: 20), text: 'Equipment'),
            Tab(icon: Icon(Icons.grass, size: 20), text: 'Feed'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ---------- Coming soon banner ----------
          const _ComingSoonBanner(),

          // ---------- Tab views ----------
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _CategoryListView(
                  category: ListingCategory.cattle,
                  listings: _sampleCattleListings,
                ),
                _CategoryListView(
                  category: ListingCategory.equipment,
                  listings: _sampleEquipmentListings,
                ),
                _CategoryListView(
                  category: ListingCategory.feed,
                  listings: _sampleFeedListings,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Coming soon banner.
// ---------------------------------------------------------------------------
class _ComingSoonBanner extends StatelessWidget {
  const _ComingSoonBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            DairyTheme.primaryGreen,
            DairyTheme.primaryGreen.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.storefront, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Marketplace Coming Soon!',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Buy and sell cattle, equipment, and feed supplies directly from the app.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.9),
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

// ---------------------------------------------------------------------------
// Category list view.
// ---------------------------------------------------------------------------
class _CategoryListView extends StatelessWidget {
  final ListingCategory category;
  final List<_SampleListing> listings;

  const _CategoryListView({
    required this.category,
    required this.listings,
  });

  @override
  Widget build(BuildContext context) {
    if (listings.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_categoryIcon(category),
                size: 64, color: DairyTheme.subtleGrey),
            const SizedBox(height: 12),
            Text(
              'No listings yet',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: DairyTheme.subtleGrey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: listings.length,
      itemBuilder: (context, index) =>
          _ListingCard(listing: listings[index], category: category),
    );
  }

  IconData _categoryIcon(ListingCategory cat) {
    switch (cat) {
      case ListingCategory.cattle:
        return Icons.pets;
      case ListingCategory.equipment:
        return Icons.build;
      case ListingCategory.feed:
        return Icons.grass;
    }
  }
}

// ---------------------------------------------------------------------------
// Listing card.
// ---------------------------------------------------------------------------
class _ListingCard extends StatelessWidget {
  final _SampleListing listing;
  final ListingCategory category;

  const _ListingCard({required this.listing, required this.category});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showComingSoon(context),
        child: Row(
          children: [
            // Image placeholder.
            Container(
              width: 100,
              height: 100,
              color: _categoryColor(category).withOpacity(0.1),
              child: Icon(
                _categoryIcon(category),
                size: 36,
                color: _categoryColor(category).withOpacity(0.4),
              ),
            ),

            // Details.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      listing.description,
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          listing.price,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: DairyTheme.primaryGreen,
                          ),
                        ),
                        Row(
                          children: [
                            Icon(Icons.location_on,
                                size: 12, color: DairyTheme.subtleGrey),
                            const SizedBox(width: 2),
                            Text(listing.location,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(ListingCategory cat) {
    switch (cat) {
      case ListingCategory.cattle:
        return Icons.pets;
      case ListingCategory.equipment:
        return Icons.build;
      case ListingCategory.feed:
        return Icons.grass;
    }
  }

  Color _categoryColor(ListingCategory cat) {
    switch (cat) {
      case ListingCategory.cattle:
        return DairyTheme.accentOrange;
      case ListingCategory.equipment:
        return Colors.blue;
      case ListingCategory.feed:
        return DairyTheme.primaryGreen;
    }
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Marketplace is coming soon! Stay tuned.'),
        backgroundColor: DairyTheme.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sample data models and data (placeholder until API is ready).
// ---------------------------------------------------------------------------
class _SampleListing {
  final String title;
  final String description;
  final String price;
  final String location;

  const _SampleListing({
    required this.title,
    required this.description,
    required this.price,
    required this.location,
  });
}

const _sampleCattleListings = [
  _SampleListing(
    title: 'Holstein Friesian Cow - 3 years',
    description: 'Healthy, producing 18L/day. All vaccinations up to date.',
    price: '85,000',
    location: 'Anand, GJ',
  ),
  _SampleListing(
    title: 'Gir Cow - Pregnant (7 months)',
    description: 'Pure Gir breed, excellent milk quality with high A2 protein.',
    price: '1,20,000',
    location: 'Rajkot, GJ',
  ),
  _SampleListing(
    title: 'Murrah Buffalo - 4 years',
    description: 'Producing 12L/day, 7% fat content. Good temperament.',
    price: '95,000',
    location: 'Karnal, HR',
  ),
  _SampleListing(
    title: 'Jersey Cross Heifer - 18 months',
    description: 'Ready for first insemination. From high-yielding mother.',
    price: '55,000',
    location: 'Pune, MH',
  ),
];

const _sampleEquipmentListings = [
  _SampleListing(
    title: 'Milking Machine - 2 Cluster',
    description: 'Automatic milking machine, used 1 year. Good condition.',
    price: '45,000',
    location: 'Anand, GJ',
  ),
  _SampleListing(
    title: 'Chaff Cutter - Heavy Duty',
    description: 'Electric chaff cutter, 1HP motor. Cuts up to 500kg/hr.',
    price: '18,000',
    location: 'Ludhiana, PB',
  ),
  _SampleListing(
    title: 'Bulk Milk Cooler - 500L',
    description: 'Stainless steel, direct expansion type. 2 years warranty left.',
    price: '2,50,000',
    location: 'Kolhapur, MH',
  ),
];

const _sampleFeedListings = [
  _SampleListing(
    title: 'Cattle Feed - 50kg bags',
    description: 'High protein compound feed (20% CP). Minimum order 10 bags.',
    price: '1,200/bag',
    location: 'Mehsana, GJ',
  ),
  _SampleListing(
    title: 'Mineral Mixture - 25kg',
    description: 'Complete mineral supplement with calcium, phosphorus, and trace minerals.',
    price: '850/bag',
    location: 'Anand, GJ',
  ),
  _SampleListing(
    title: 'Silage - Maize (per ton)',
    description: 'Fresh maize silage, properly fermented. Delivery available.',
    price: '3,500/ton',
    location: 'Nashik, MH',
  ),
];
