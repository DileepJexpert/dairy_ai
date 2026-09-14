import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../marketplace/models/marketplace_models.dart';
import '../../marketplace/providers/product_provider.dart';
import '../../admin/providers/admin_marketplace_provider.dart';
import '../../auth/providers/auth_provider.dart';

class SellerPortalSession {
  const SellerPortalSession(
      {required this.sellerAccount, required this.isLoggedIn});
  final SellerAccount? sellerAccount;
  final bool isLoggedIn;
}

class SellerPortalNotifier extends StateNotifier<SellerPortalSession> {
  SellerPortalNotifier(this.ref)
      : super(
            const SellerPortalSession(sellerAccount: null, isLoggedIn: false));
  final Ref ref;
  void loginAsSeller(SellerAccount account) =>
      state = SellerPortalSession(sellerAccount: account, isLoggedIn: true);
  Future<void> logout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted)
      state = const SellerPortalSession(sellerAccount: null, isLoggedIn: false);
  }

  Future<void> registerNewSeller(SellerAccount account) async {
    await ref.read(dioProvider).post('/vendor/register', data: {
      'business_name': account.businessName,
      'vendor_type': 'other',
      'gst_number': account.gstin,
      'license_number': account.fssaiLicense,
      'district': account.warehouseCity,
      'state': account.warehouseState,
    });
    await ref.read(adminMarketplaceProvider.notifier).refresh(propagate: true);
  }

  Future<void> createOfferForSeller({
    required String productId,
    required String sellerSku,
    required double mrp,
    required double sellingPrice,
    required int availableStock,
    FulfillmentType fulfillmentType = FulfillmentType.sellerDirect,
  }) async {
    await ref.read(dioProvider).post('/vendor/commerce/offers', data: {
      'source_product_id': productId,
      'seller_sku': sellerSku,
      'mrp': mrp,
      'selling_price': sellingPrice,
      'available_stock': availableStock,
    });
    ref.invalidate(productsProvider);
    await ref.read(adminMarketplaceProvider.notifier).refresh(propagate: true);
  }
}

final sellerPortalProvider =
    StateNotifierProvider<SellerPortalNotifier, SellerPortalSession>((ref) {
  ref.watch(currentUserProvider);
  return SellerPortalNotifier(ref);
});
