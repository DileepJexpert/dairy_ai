import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/taxonomy.dart';

final taxonomyProvider = FutureProvider<TaxonomyCatalogue>((ref) async {
  final body = (await ref.watch(dioProvider).get('/marketplace/taxonomy')).data
      as Map<String, dynamic>;
  return TaxonomyCatalogue(
      enabled: body['enabled'] == true,
      nodes: (body['data'] as List)
          .map((n) => TaxonomyNode.fromJson(Map<String, dynamic>.from(n)))
          .toList());
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
