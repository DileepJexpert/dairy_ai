import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../marketplace/models/marketplace_models.dart';
import '../../admin/providers/admin_marketplace_provider.dart';

class SellerPortalSession {
  const SellerPortalSession({
    required this.sellerAccount,
    required this.isLoggedIn,
  });
  final SellerAccount? sellerAccount;
  final bool isLoggedIn;
}

class SellerPortalNotifier extends StateNotifier<SellerPortalSession> {
  SellerPortalNotifier(this.ref)
      : super(const SellerPortalSession(
          sellerAccount: null,
          isLoggedIn: false,
        ));

  final Ref ref;

  void loginAsSeller(SellerAccount account) {
    state = SellerPortalSession(sellerAccount: account, isLoggedIn: true);
  }

  void logout() {
    state = const SellerPortalSession(sellerAccount: null, isLoggedIn: false);
  }

  void registerNewSeller(SellerAccount newAccount) {
    ref.read(adminMarketplaceProvider.notifier).logAction(
      action: AuditAction.sellerApproval,
      entityType: 'SellerAccount',
      entityId: newAccount.id,
      details: 'New seller registration application submitted by ${newAccount.businessName}',
      userRole: 'SELLER',
      userIdentifier: newAccount.contactEmail ?? newAccount.contactPhone ?? 'seller',
    );
    // Auto log in as the newly registered seller
    state = SellerPortalSession(sellerAccount: newAccount, isLoggedIn: true);
  }

  void createOfferForSeller({
    required String productId,
    required String sellerSku,
    required double mrp,
    required double sellingPrice,
    required int availableStock,
    FulfillmentType fulfillmentType = FulfillmentType.sellerDirect,
  }) {
    if (state.sellerAccount == null) return;
    final seller = state.sellerAccount!;
    final discount = mrp > sellingPrice ? ((mrp - sellingPrice) / mrp) * 100 : 0.0;
    final offer = SellerOffer(
      id: 'off-${DateTime.now().millisecondsSinceEpoch}',
      productId: productId,
      sellerId: seller.id,
      sellerName: seller.businessName,
      sellerSku: sellerSku,
      mrp: mrp,
      sellingPrice: sellingPrice,
      discountPercent: discount,
      availableStock: availableStock,
      fulfillmentType: fulfillmentType,
      offerStatus: OfferStatus.active,
      sellerRating: seller.ratingScore,
      isBuyBoxWinner: false,
    );

    final currentOffers = ref.read(adminMarketplaceProvider).offers;
    ref.read(adminMarketplaceProvider.notifier).logAction(
      action: AuditAction.stockAdjust,
      entityType: 'SellerOffer',
      entityId: offer.id,
      details: 'Created offer for product $productId by ${seller.businessName} at ₹${sellingPrice.toStringAsFixed(0)}.',
      userRole: 'SELLER',
      userIdentifier: seller.businessName,
    );
    ref.read(adminMarketplaceProvider).copyWith(offers: [offer, ...currentOffers]);
  }
}

final sellerPortalProvider =
    StateNotifierProvider<SellerPortalNotifier, SellerPortalSession>((ref) {
  return SellerPortalNotifier(ref);
});
