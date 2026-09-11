import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/taxonomy.dart';

final taxonomyProvider = FutureProvider<TaxonomyCatalogue>((ref) async {
  try {
    final response = await ref.watch(dioProvider).get('/marketplace/taxonomy');
    final body = response.data;
    if (body is Map && body['enabled'] == true && body['data'] is List) {
      return TaxonomyCatalogue(
          enabled: true,
          nodes: (body['data'] as List)
              .map((n) =>
                  TaxonomyNode.fromJson(Map<String, dynamic>.from(n as Map)))
              .toList());
    }
    return const TaxonomyCatalogue(enabled: false, nodes: []);
  } catch (_) {
    return const TaxonomyCatalogue(enabled: false, nodes: []);
  }
});

final commerceAccessProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return {'can_manage_taxonomy': false};
  return Map<String, dynamic>.from(
      (await ref.watch(dioProvider).get('/commerce/access')).data['data']);
});

final adminTaxonomyProvider = FutureProvider<List<TaxonomyNode>>((ref) async {
  // Recreated on account changes; server remains authoritative for every call.
  ref.watch(currentUserProvider);
  final body =
      (await ref.watch(dioProvider).get('/admin/commerce/taxonomy')).data;
  return (body['data'] as List)
      .map((n) => TaxonomyNode.fromJson(Map<String, dynamic>.from(n)))
      .toList();
});
