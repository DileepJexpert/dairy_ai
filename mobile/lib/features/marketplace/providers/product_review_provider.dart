import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';

class ProductReviewEntry {
  const ProductReviewEntry({
    required this.id,
    required this.productId,
    required this.authorName,
    required this.rating,
    required this.headline,
    required this.content,
    required this.sourceLabel,
    required this.isSeeded,
    required this.createdAt,
  });

  final String id;
  final String productId;
  final String authorName;
  final int rating;
  final String headline;
  final String content;
  final String sourceLabel;
  final bool isSeeded;
  final DateTime? createdAt;

  factory ProductReviewEntry.fromJson(Map<String, dynamic> json) =>
      ProductReviewEntry(
        id: json['id']?.toString() ?? '',
        productId: json['product_id']?.toString() ?? '',
        authorName: json['author_name']?.toString() ?? 'Visitor',
        rating: int.tryParse(json['rating']?.toString() ?? '') ?? 0,
        headline: json['headline']?.toString() ?? '',
        content: json['content']?.toString() ?? '',
        sourceLabel: json['source_label']?.toString() ?? 'Visitor feedback',
        isSeeded: json['is_seeded'] == true,
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      );
}

class ProductReviewRepository {
  const ProductReviewRepository(this._dio);

  final Dio _dio;

  Future<List<ProductReviewEntry>> list(String productId) async {
    final response = await _dio.get('/marketplace/products/$productId/reviews');
    final body = response.data;
    if (body is! Map || body['data'] is! List) {
      throw const FormatException('Product feedback response was invalid');
    }
    return (body['data'] as List)
        .whereType<Map>()
        .map((item) => ProductReviewEntry.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .toList();
  }

  Future<ProductReviewEntry> create({
    required String productId,
    required String authorName,
    required int rating,
    required String headline,
    required String content,
  }) async {
    final response = await _dio.post(
      '/marketplace/products/$productId/reviews',
      data: {
        'author_name': authorName,
        'rating': rating,
        'headline': headline,
        'content': content,
      },
    );
    final body = response.data;
    if (body is! Map || body['data'] is! Map) {
      throw const FormatException('Saved feedback response was invalid');
    }
    return ProductReviewEntry.fromJson(
      Map<String, dynamic>.from(body['data'] as Map),
    );
  }
}

final productReviewRepositoryProvider = Provider<ProductReviewRepository>(
  (ref) => ProductReviewRepository(ref.watch(dioProvider)),
);

final productReviewsProvider =
    FutureProvider.family<List<ProductReviewEntry>, String>((ref, productId) {
  return ref.watch(productReviewRepositoryProvider).list(productId);
});
