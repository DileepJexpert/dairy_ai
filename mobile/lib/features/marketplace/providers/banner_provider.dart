import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import '../models/banner_model.dart';

/// Provider for dynamic storefront banners loaded from backend API.
/// If API call fails or returns empty, falls back to default promotional cards.
final storefrontBannersProvider =
    FutureProvider<List<StorefrontBanner>>((ref) async {
  try {
    final dio = ref.read(dioProvider);
    final response = await dio.get('/marketplace/storefront/banners');

    if (response.statusCode == 200 && response.data is List) {
      final list = (response.data as List)
          .map((item) =>
              StorefrontBanner.fromJson(item as Map<String, dynamic>))
          .toList();

      if (list.isNotEmpty) {
        return list;
      }
    }
  } catch (_) {
    // Graceful fallback to default cards if backend is loading or unavailable
  }

  return StorefrontBanner.defaultBanners;
});
