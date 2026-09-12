import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../marketplace/models/product_models.dart';

/// Provides the reactive list of products saved in the user's wishlist.
final wishlistProvider =
    StateNotifierProvider<WishlistNotifier, List<Product>>((ref) {
  return WishlistNotifier();
});

/// Convenience provider for the total count of wishlisted items.
final wishlistItemCountProvider =
    Provider<int>((ref) => ref.watch(wishlistProvider).length);

/// Checks whether a product by [productId] is present in the wishlist.
final isWishlistedProvider = Provider.family<bool, String>((ref, productId) {
  return ref.watch(wishlistProvider).any((p) => p.id == productId);
});

class WishlistNotifier extends StateNotifier<List<Product>> {
  WishlistNotifier() : super([]);

  /// Checks if [productId] is already saved in wishlist.
  bool isWishlisted(String productId) {
    return state.any((p) => p.id == productId);
  }

  /// Toggles wishlist inclusion for [product].
  bool toggle(Product product) {
    if (isWishlisted(product.id)) {
      state = state.where((p) => p.id != product.id).toList();
      return false;
    } else {
      state = [...state, product];
      return true;
    }
  }

  /// Adds [product] to the wishlist if not already present.
  void add(Product product) {
    if (!isWishlisted(product.id)) {
      state = [...state, product];
    }
  }

  /// Removes [productId] from the wishlist.
  void remove(String productId) {
    state = state.where((p) => p.id != productId).toList();
  }

  /// Clears the entire wishlist.
  void clear() {
    state = [];
  }
}
