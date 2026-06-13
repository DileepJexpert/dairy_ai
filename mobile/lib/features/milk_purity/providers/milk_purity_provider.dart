import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/core/api_client.dart';
import '../models/milk_purity_models.dart';

final milkPurityRepoProvider = Provider<MilkPurityRepository>((ref) {
  return MilkPurityRepository(ref.read(apiClientProvider));
});

class MilkPurityRepository {
  final Dio _dio;
  MilkPurityRepository(this._dio);

  Future<List<BrandSummary>> searchBrands(String query, {String? state}) async {
    final params = <String, dynamic>{'q': query};
    if (state != null) params['state'] = state;
    final response = await _dio.get('/purity/search', queryParameters: params);
    final brands = response.data['data']['brands'] as List;
    return brands
        .map((e) => BrandSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<BrandScore> getBrandScore(String slug) async {
    final response = await _dio.get('/purity/brand/$slug');
    return BrandScore.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<List<BrandSummary>> getTopBrands({String? state, int limit = 10}) async {
    final params = <String, dynamic>{'limit': limit};
    if (state != null) params['state'] = state;
    final response = await _dio.get('/purity/top', queryParameters: params);
    final brands = response.data['data']['brands'] as List;
    return brands
        .map((e) => BrandSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CompareResult> compareBrands(String slugA, String slugB) async {
    final response = await _dio.get('/purity/compare', queryParameters: {
      'brand_a': slugA,
      'brand_b': slugB,
    });
    return CompareResult.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }
}

final topBrandsProvider = FutureProvider<List<BrandSummary>>((ref) async {
  final repo = ref.read(milkPurityRepoProvider);
  return repo.getTopBrands(limit: 20);
});

final brandScoreProvider =
    FutureProvider.family<BrandScore, String>((ref, slug) async {
  final repo = ref.read(milkPurityRepoProvider);
  return repo.getBrandScore(slug);
});

final searchBrandsProvider =
    FutureProvider.family<List<BrandSummary>, String>((ref, query) async {
  if (query.trim().isEmpty) return [];
  final repo = ref.read(milkPurityRepoProvider);
  return repo.searchBrands(query);
});

final compareBrandsProvider = FutureProvider.family<CompareResult,
    ({String slugA, String slugB})>((ref, params) async {
  final repo = ref.read(milkPurityRepoProvider);
  return repo.compareBrands(params.slugA, params.slugB);
});
