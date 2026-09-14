import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../marketplace/models/product_models.dart';
import '../../marketplace/providers/product_provider.dart';

final wishlistErrorProvider = StateProvider<String?>((ref) => null);
final wishlistLoadingProvider = StateProvider<bool>((ref) => false);
final wishlistProvider =
    StateNotifierProvider<WishlistNotifier, List<Product>>((ref) {
  final user = ref.watch(currentUserProvider);
  return WishlistNotifier(ref, enabled: user != null);
});
final wishlistCountProvider =
    Provider<int>((ref) => ref.watch(wishlistProvider).length);
final wishlistItemCountProvider = wishlistCountProvider;
final isWishlistedProvider = Provider.family<bool, String>(
    (ref, id) => ref.watch(wishlistProvider).any((p) => p.id == id));

class WishlistNotifier extends StateNotifier<List<Product>> {
  WishlistNotifier(this.ref, {bool enabled = true}) : super([]) {
    if (enabled) Future.microtask(refresh);
  }
  final Ref ref;
  Dio get dio => ref.read(dioProvider);
  Future<void> refresh() async {
    if (!mounted) return;
    ref.read(wishlistLoadingProvider.notifier).state = true;
    try {
      final response = await dio.get('/marketplace/wishlist');
      final products = <Product>[];
      for (final key in response.data['data'] as List) {
        try {
          products.add(
              await ref.read(productDetailProvider(key.toString()).future));
        } on DioException catch (e) {
          if (e.response?.statusCode != 404) rethrow;
          // Retain the stored reference, but don't display unpublished products.
        }
      }
      if (!mounted) return;
      state = products;
      ref.read(wishlistErrorProvider.notifier).state = null;
    } catch (_) {
      if (mounted)
        ref.read(wishlistErrorProvider.notifier).state =
            'Wishlist could not be loaded. Please retry.';
    } finally {
      if (mounted) ref.read(wishlistLoadingProvider.notifier).state = false;
    }
  }

  Future<bool> toggle(Product product) async {
    if (state.any((p) => p.id == product.id)) {
      await remove(product.id);
      return false;
    }
    await add(product);
    return true;
  }

  Future<void> add(Product product) async {
    await dio.put('/marketplace/wishlist/${product.id}');
    if (mounted && !state.any((p) => p.id == product.id))
      state = [...state, product];
  }

  Future<void> remove(String id) async {
    await dio.delete('/marketplace/wishlist/$id');
    if (mounted) state = state.where((p) => p.id != id).toList();
  }
}

Future<void> toggleWishlist(
    BuildContext context, WidgetRef ref, Product product) async {
  if (ref.read(currentUserProvider) == null) {
    context.push('/login');
    return;
  }
  try {
    final added = await ref.read(wishlistProvider.notifier).toggle(product);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            added ? 'Saved to your wishlist.' : 'Removed from wishlist.')));
  } catch (_) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Wishlist was not saved. Please retry.')));
  }
}
