import 'package:dairy_ai/core/constants.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/product_models.dart';

class StorefrontPlacement {
  const StorefrontPlacement({
    required this.id,
    required this.productId,
    required this.placementType,
    required this.headline,
    required this.product,
    this.subheadline,
    this.badge,
    this.startsAt,
    this.endsAt,
    this.priority = 100,
    this.isActive = true,
  });

  final String id;
  final String productId;
  final String placementType;
  final String headline;
  final String? subheadline;
  final String? badge;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int priority;
  final bool isActive;
  final Product product;

  factory StorefrontPlacement.fromJson(Map<String, dynamic> json) {
    final productJson = json['product'];
    if (productJson is! Map) {
      throw const FormatException('Placement is missing its product');
    }
    return StorefrontPlacement(
      id: json['id'].toString(),
      productId: json['product_id'].toString(),
      placementType: json['placement_type']?.toString() ?? 'highlight',
      headline: json['headline']?.toString() ?? 'Featured at Milterra',
      subheadline: json['subheadline']?.toString(),
      badge: json['badge']?.toString(),
      startsAt: DateTime.tryParse(json['starts_at']?.toString() ?? ''),
      endsAt: DateTime.tryParse(json['ends_at']?.toString() ?? ''),
      priority: int.tryParse(json['priority']?.toString() ?? '') ?? 100,
      isActive: json['is_active'] != false,
      product: Product.fromJson(Map<String, dynamic>.from(productJson)),
    );
  }
}

class MerchandisingRepository {
  const MerchandisingRepository(this.ref);
  final Ref ref;

  Future<List<StorefrontPlacement>> list({bool admin = false}) async {
    // Public storefront reads need neither credentials nor a JSON content-type.
    // Keeping this a CORS-simple GET also prevents an expired browser session
    // from delaying or suppressing anonymous merchandising content.
    final client = admin
        ? ref.read(dioProvider)
        : Dio(BaseOptions(
            baseUrl: AppConstants.baseUrl,
            connectTimeout: AppConstants.connectTimeout,
            receiveTimeout: AppConstants.receiveTimeout,
            headers: const {'Accept': 'application/json'},
          ));
    final response = await client.get(admin
        ? '/admin/marketplace/merchandising/placements'
        : '/marketplace/merchandising/placements');
    final body = response.data;
    if (body is! Map || body['data'] is! List) {
      throw const FormatException('Placement response did not contain a list');
    }
    return (body['data'] as List)
        .whereType<Map>()
        .map((item) =>
            StorefrontPlacement.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> create({
    required String productId,
    required String placementType,
    required String headline,
    String? subheadline,
    String? badge,
    DateTime? startsAt,
    DateTime? endsAt,
    int priority = 100,
  }) async {
    await ref
        .read(dioProvider)
        .post('/admin/marketplace/merchandising/placements', data: {
      'product_id': productId,
      'placement_type': placementType,
      'headline': headline,
      'subheadline': subheadline,
      'badge': badge,
      'starts_at': startsAt?.toUtc().toIso8601String(),
      'ends_at': endsAt?.toUtc().toIso8601String(),
      'priority': priority,
      'is_active': true,
    });
  }

  Future<void> setActive(String placementId, bool active) async {
    await ref.read(dioProvider).put(
      '/admin/marketplace/merchandising/placements/$placementId',
      data: {'is_active': active},
    );
  }

  Future<void> delete(String placementId) async {
    await ref.read(dioProvider).delete(
      '/admin/marketplace/merchandising/placements/$placementId',
    );
  }
}

final merchandisingRepositoryProvider = Provider<MerchandisingRepository>(
  MerchandisingRepository.new,
);

final storefrontPlacementsProvider =
    FutureProvider<List<StorefrontPlacement>>((ref) {
  return ref.read(merchandisingRepositoryProvider).list();
});

final adminStorefrontPlacementsProvider =
    FutureProvider<List<StorefrontPlacement>>((ref) {
  return ref.read(merchandisingRepositoryProvider).list(admin: true);
});
