import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/store_theme.dart';
import '../../marketplace/models/banner_model.dart';
import '../../marketplace/providers/banner_provider.dart';

/// Amazon-style dynamic showcase carousel for MILTERRA storefront.
/// Cards are pushed dynamically from the backend and display promotional/category cards.
class StorefrontCarousel extends ConsumerWidget {
  const StorefrontCarousel({
    super.key,
    required this.onSelectCategory,
  });

  final ValueChanged<String> onSelectCategory;

  Color _parseColor(String hex, Color fallback) {
    try {
      final clean = hex.replaceAll('#', '').trim();
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      } else if (clean.length == 8) {
        return Color(int.parse(clean, radix: 16));
      }
    } catch (_) {}
    return fallback;
  }

  IconData _resolveIcon(String? iconName) {
    switch (iconName) {
      case 'local_fire_department':
        return Icons.local_fire_department_outlined;
      case 'water_drop':
        return Icons.water_drop_outlined;
      case 'opacity':
        return Icons.opacity_outlined;
      case 'wb_sunny':
        return Icons.wb_sunny_outlined;
      case 'grass':
        return Icons.grass_outlined;
      case 'yard':
        return Icons.yard_outlined;
      case 'eco':
        return Icons.eco_outlined;
      case 'spa':
        return Icons.spa_outlined;
      default:
        return Icons.verified_outlined;
    }
  }

  void _handleBannerTap(BuildContext context, StorefrontBanner banner) {
    switch (banner.actionType.toLowerCase()) {
      case 'category':
        onSelectCategory(banner.actionValue);
        break;
      case 'product':
        context.push('/shop/product/${banner.actionValue}');
        break;
      case 'url':
        // Optional external route
        break;
      default:
        onSelectCategory(banner.actionValue);
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bannersAsync = ref.watch(storefrontBannersProvider);

    return bannersAsync.when(
      loading: () => const SizedBox(
        height: 180,
        child: Center(
          child: CircularProgressIndicator(color: storeGreen, strokeWidth: 2),
        ),
      ),
      error: (_, __) => _buildBannerRow(context, StorefrontBanner.defaultBanners),
      data: (banners) => _buildBannerRow(context, banners),
    );
  }

  Widget _buildBannerRow(BuildContext context, List<StorefrontBanner> banners) {
    if (banners.isEmpty) return const SizedBox.shrink();

    return Container(
      color: storeCream,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: StoreLayout.maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        color: storeGold,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'FEATURED COLLECTIONS & SPECIALS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: storeGreen,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'Swipe to explore ›',
                      style: TextStyle(
                        fontSize: 11,
                        color: storeMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 195,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: banners.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final banner = banners[index];
                    final bg = _parseColor(banner.bgColor, storeGreen);
                    final textCol = _parseColor(banner.textColor, Colors.white);
                    final icon = _resolveIcon(banner.iconName);

                    return InkWell(
                      onTap: () => _handleBannerTap(context, banner),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 270,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              bg,
                              bg.withValues(alpha: 0.82),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top Tag & Icon Badge
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: storeGold.withValues(alpha: 0.45),
                                    ),
                                  ),
                                  child: Text(
                                    banner.subtitle ?? 'MILTERRA DIRECT',
                                    style: const TextStyle(
                                      color: storeGold,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(icon, size: 16, color: storeGold),
                                ),
                              ],
                            ),
                            const Spacer(),

                            // Title
                            Text(
                              banner.title,
                              style: TextStyle(
                                fontFamily: 'CormorantGaramond',
                                fontSize: 21,
                                fontWeight: FontWeight.bold,
                                color: textCol,
                                height: 1.15,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),

                            // Bottom Action Pill
                            const Row(
                              children: [
                                Text(
                                  'Explore Now',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: storeGold,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 13,
                                  color: storeGold,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
