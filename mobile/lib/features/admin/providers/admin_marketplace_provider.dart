import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../marketplace/models/marketplace_models.dart';
import '../../marketplace/models/product_models.dart';

class AdminMarketplaceState {
  const AdminMarketplaceState({
    required this.sellers,
    required this.offers,
    required this.deals,
    required this.coupons,
    required this.auditLogs,
    required this.customProducts,
  });

  final List<SellerAccount> sellers;
  final List<SellerOffer> offers;
  final List<DealPromotion> deals;
  final List<PlatformCoupon> coupons;
  final List<MarketplaceAuditLog> auditLogs;
  final List<Product> customProducts;

  AdminMarketplaceState copyWith({
    List<SellerAccount>? sellers,
    List<SellerOffer>? offers,
    List<DealPromotion>? deals,
    List<PlatformCoupon>? coupons,
    List<MarketplaceAuditLog>? auditLogs,
    List<Product>? customProducts,
  }) =>
      AdminMarketplaceState(
        sellers: sellers ?? this.sellers,
        offers: offers ?? this.offers,
        deals: deals ?? this.deals,
        coupons: coupons ?? this.coupons,
        auditLogs: auditLogs ?? this.auditLogs,
        customProducts: customProducts ?? this.customProducts,
      );
}

class AdminMarketplaceNotifier extends StateNotifier<AdminMarketplaceState> {
  AdminMarketplaceNotifier()
      : super(AdminMarketplaceState(
          sellers: _defaultSellers,
          offers: _defaultOffers,
          deals: _defaultDeals,
          coupons: _defaultCoupons,
          auditLogs: _defaultAuditLogs,
          customProducts: const [],
        ));

  void logAction({
    required AuditAction action,
    required String entityType,
    required String entityId,
    required String details,
    String userRole = 'SUPER_ADMIN',
    String userIdentifier = 'admin@milterra.com',
  }) {
    final log = MarketplaceAuditLog(
      id: 'log-${DateTime.now().millisecondsSinceEpoch}',
      userRole: userRole,
      userIdentifier: userIdentifier,
      action: action,
      entityType: entityType,
      entityId: entityId,
      details: details,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(auditLogs: [log, ...state.auditLogs]);
  }

  void approveSeller(String sellerId) {
    final updated = state.sellers.map((s) {
      if (s.id == sellerId) {
        return s.copyWith(status: SellerStatus.approved);
      }
      return s;
    }).toList();
    state = state.copyWith(sellers: updated);
    logAction(
      action: AuditAction.sellerApproval,
      entityType: 'SellerAccount',
      entityId: sellerId,
      details: 'Approved seller KYC credentials and granted seller portal access.',
    );
  }

  void suspendSeller(String sellerId, String reason) {
    final updated = state.sellers.map((s) {
      if (s.id == sellerId) {
        return s.copyWith(status: SellerStatus.suspended);
      }
      return s;
    }).toList();
    state = state.copyWith(sellers: updated);
    logAction(
      action: AuditAction.sellerSuspension,
      entityType: 'SellerAccount',
      entityId: sellerId,
      details: 'Suspended seller account: $reason',
    );
  }

  void updateCommission(String sellerId, double rate) {
    final updated = state.sellers.map((s) {
      if (s.id == sellerId) {
        return s.copyWith(commissionRatePercent: rate);
      }
      return s;
    }).toList();
    state = state.copyWith(sellers: updated);
    logAction(
      action: AuditAction.statusChange,
      entityType: 'SellerAccount',
      entityId: sellerId,
      details: 'Updated commission rate to $rate%.',
    );
  }

  void updateOfferPrice(String offerId, double newPrice, double newMrp) {
    final updated = state.offers.map((o) {
      if (o.id == offerId) {
        final discount = newMrp > newPrice ? ((newMrp - newPrice) / newMrp) * 100 : 0.0;
        return o.copyWith(
          sellingPrice: newPrice,
          mrp: newMrp,
          discountPercent: discount,
        );
      }
      return o;
    }).toList();
    state = state.copyWith(offers: updated);
    logAction(
      action: AuditAction.priceChange,
      entityType: 'SellerOffer',
      entityId: offerId,
      details: 'Changed offer price to ₹${newPrice.toStringAsFixed(0)} (MRP ₹${newMrp.toStringAsFixed(0)}).',
    );
  }

  void updateOfferStock(String offerId, int newStock) {
    final updated = state.offers.map((o) {
      if (o.id == offerId) {
        return o.copyWith(
          availableStock: newStock,
          offerStatus: newStock <= 0 ? OfferStatus.outOfStock : OfferStatus.active,
        );
      }
      return o;
    }).toList();
    state = state.copyWith(offers: updated);
    logAction(
      action: AuditAction.stockAdjust,
      entityType: 'SellerOffer',
      entityId: offerId,
      details: 'Updated warehouse stock to $newStock units.',
    );
  }

  void addDeal(DealPromotion deal) {
    state = state.copyWith(deals: [deal, ...state.deals]);
    logAction(
      action: AuditAction.dealCreate,
      entityType: 'DealPromotion',
      entityId: deal.id,
      details: 'Created ${deal.dealType.name} for ${deal.productTitle} at ₹${deal.dealPrice.toStringAsFixed(0)}.',
    );
  }

  void addCoupon(PlatformCoupon coupon) {
    state = state.copyWith(coupons: [coupon, ...state.coupons]);
    logAction(
      action: AuditAction.statusChange,
      entityType: 'PlatformCoupon',
      entityId: coupon.code,
      details: 'Created discount coupon code ${coupon.code}.',
    );
  }

  void addCustomProduct(Product p) {
    state = state.copyWith(customProducts: [p, ...state.customProducts]);
    logAction(
      action: AuditAction.catalogCreate,
      entityType: 'Product',
      entityId: p.id,
      details: 'Published new catalog SKU: ${p.title} (${p.taxonomy?['status'] ?? 'Active'}).',
    );
  }
}

final adminMarketplaceProvider =
    StateNotifierProvider<AdminMarketplaceNotifier, AdminMarketplaceState>((ref) {
  return AdminMarketplaceNotifier();
});

// Default Mock Data
final _defaultSellers = [
  SellerAccount(
    id: 'seller-milterra-direct',
    businessName: 'Milterra Direct Sourcing Cooperative',
    tradeName: 'Milterra Direct',
    gstin: '24AAACM1234F1Z5',
    fssaiLicense: '10722001000456',
    contactEmail: 'sourcing@milterra.com',
    contactPhone: '+91 98765 43210',
    warehouseCity: 'Anand',
    warehouseState: 'Gujarat',
    bankAccountNumber: '9876543210001',
    ifscCode: 'SBIN0001234',
    upiId: 'milterra.direct@sbi',
    status: SellerStatus.approved,
    commissionRatePercent: 0.0,
    ratingScore: 4.9,
    totalRatingsCount: 3420,
    createdAt: DateTime(2024, 1, 1),
  ),
  SellerAccount(
    id: 'seller-gir-organics',
    businessName: 'Gir Organic Dairy Farmers Producer Co.',
    tradeName: 'Gir Organics',
    gstin: '24BBCPG5678K1Z2',
    fssaiLicense: '10723002000789',
    contactEmail: 'contact@girorganics.in',
    contactPhone: '+91 94280 11223',
    warehouseCity: 'Junagadh',
    warehouseState: 'Gujarat',
    bankAccountNumber: '1122334455667',
    ifscCode: 'HDFC0000456',
    upiId: 'girorganics@hdfcbank',
    status: SellerStatus.approved,
    commissionRatePercent: 7.5,
    ratingScore: 4.7,
    totalRatingsCount: 840,
    createdAt: DateTime(2024, 6, 15),
  ),
  SellerAccount(
    id: 'seller-krishi-poshan',
    businessName: 'Krishi Poshan Cattle Feeds LLP',
    tradeName: 'Krishi Poshan',
    gstin: '08AACKP9012L1Z8',
    fssaiLicense: '10824003000112',
    contactEmail: 'partner@krishiposhan.com',
    contactPhone: '+91 98290 33445',
    warehouseCity: 'Jaipur',
    warehouseState: 'Rajasthan',
    bankAccountNumber: '5566778899001',
    ifscCode: 'BARB0JAIPUR',
    upiId: 'krishiposhan@icici',
    status: SellerStatus.pendingApproval,
    commissionRatePercent: 8.0,
    ratingScore: 4.6,
    totalRatingsCount: 120,
    createdAt: DateTime(2025, 1, 10),
  ),
];

final _defaultOffers = [
  const SellerOffer(
    id: 'off-ghee-milterra',
    productId: 'mil-ghee-500',
    sellerId: 'seller-milterra-direct',
    sellerName: 'Milterra Direct',
    sellerSku: 'MIL-GHEE-500-DIR',
    mrp: 750.0,
    sellingPrice: 699.0,
    discountPercent: 7.0,
    availableStock: 140,
    lowStockThreshold: 10,
    deliveryPromise: 'FREE delivery by Tomorrow',
    fulfillmentType: FulfillmentType.fulfilledByMilterra,
    offerStatus: OfferStatus.active,
    sellerRating: 4.9,
    isBuyBoxWinner: true,
  ),
  const SellerOffer(
    id: 'off-ghee-gir',
    productId: 'mil-ghee-500',
    sellerId: 'seller-gir-organics',
    sellerName: 'Gir Organics Producer Co.',
    sellerSku: 'GIR-GHEE-500-ORG',
    mrp: 750.0,
    sellingPrice: 679.0,
    discountPercent: 9.0,
    availableStock: 25,
    lowStockThreshold: 5,
    deliveryPromise: 'FREE delivery in 2 days',
    fulfillmentType: FulfillmentType.sellerDirect,
    offerStatus: OfferStatus.active,
    sellerRating: 4.7,
    isBuyBoxWinner: false,
  ),
  const SellerOffer(
    id: 'off-buff-milterra',
    productId: 'mil-buff-500',
    sellerId: 'seller-milterra-direct',
    sellerName: 'Milterra Direct',
    sellerSku: 'MIL-BUFF-500-DIR',
    mrp: 650.0,
    sellingPrice: 599.0,
    discountPercent: 8.0,
    availableStock: 85,
    lowStockThreshold: 8,
    deliveryPromise: 'FREE delivery by Tomorrow',
    fulfillmentType: FulfillmentType.fulfilledByMilterra,
    offerStatus: OfferStatus.active,
    sellerRating: 4.9,
    isBuyBoxWinner: true,
  ),
  const SellerOffer(
    id: 'off-buff-gir',
    productId: 'mil-buff-500',
    sellerId: 'seller-gir-organics',
    sellerName: 'Gir Organics Producer Co.',
    sellerSku: 'GIR-BUFF-500-ORG',
    mrp: 650.0,
    sellingPrice: 585.0,
    discountPercent: 10.0,
    availableStock: 18,
    lowStockThreshold: 4,
    deliveryPromise: 'FREE delivery in 2 days',
    fulfillmentType: FulfillmentType.sellerDirect,
    offerStatus: OfferStatus.active,
    sellerRating: 4.7,
    isBuyBoxWinner: false,
  ),
  const SellerOffer(
    id: 'off-paneer-milterra',
    productId: 'fresh_paneer_200g',
    sellerId: 'seller-milterra-direct',
    sellerName: 'Milterra Direct',
    sellerSku: 'MIL-PAN-200-DIR',
    mrp: 140.0,
    sellingPrice: 125.0,
    discountPercent: 11.0,
    availableStock: 45,
    lowStockThreshold: 10,
    deliveryPromise: 'Express Morning Delivery (6 AM - 9 AM)',
    fulfillmentType: FulfillmentType.fulfilledByMilterra,
    offerStatus: OfferStatus.active,
    sellerRating: 4.9,
    isBuyBoxWinner: true,
  ),
];

final _defaultDeals = [
  DealPromotion(
    id: 'deal-ghee-hero',
    title: 'Deal of the Day · Vedic A2 Cow Ghee',
    dealType: DealType.dealOfTheDay,
    productId: 'mil-ghee-500',
    productTitle: 'Milterra A2 Desi Cow Ghee (Bilona Churned, 500ml)',
    productImage: 'assets/store/minera-360-jar.jpg',
    mrp: 750.0,
    dealPrice: 629.0,
    discountPercent: 16.0,
    startTime: DateTime.now().subtract(const Duration(hours: 4)),
    endTime: DateTime.now().add(const Duration(hours: 14, minutes: 22)),
    isActive: true,
  ),
  DealPromotion(
    id: 'deal-paneer-lightning',
    title: 'Lightning Deal · Fresh Farm Paneer 200g',
    dealType: DealType.lightningDeal,
    productId: 'fresh_paneer_200g',
    productTitle: 'Fresh Malai Paneer 200g (Vacuum Sealed)',
    productImage: 'assets/store/calci-feed-combo.jpg',
    mrp: 140.0,
    dealPrice: 110.0,
    discountPercent: 21.0,
    startTime: DateTime.now().subtract(const Duration(hours: 2)),
    endTime: DateTime.now().add(const Duration(hours: 4, minutes: 30)),
    isActive: true,
  ),
];

final _defaultCoupons = [
  PlatformCoupon(
    id: 'cpn-1',
    code: 'MILTERRA10',
    description: '10% instant discount on orders above ₹499',
    discountType: CouponType.percentage,
    discountValue: 10.0,
    minOrderValue: 499.0,
    maxDiscountCap: 250.0,
    validUntil: DateTime.now().add(const Duration(days: 30)),
    usageCount: 1420,
    isActive: true,
  ),
  PlatformCoupon(
    id: 'cpn-2',
    code: 'FARMER50',
    description: 'Flat ₹50 off on first dairy order above ₹299',
    discountType: CouponType.flat,
    discountValue: 50.0,
    minOrderValue: 299.0,
    maxDiscountCap: 50.0,
    validUntil: DateTime.now().add(const Duration(days: 60)),
    usageCount: 890,
    isActive: true,
  ),
];

final _defaultAuditLogs = [
  MarketplaceAuditLog(
    id: 'log-1',
    userRole: 'SUPER_ADMIN',
    userIdentifier: 'admin@milterra.com',
    action: AuditAction.priceChange,
    entityType: 'SellerOffer',
    entityId: 'off-ghee-milterra',
    details: 'Adjusted base selling price of Milterra Ghee to ₹699.',
    timestamp: DateTime.now().subtract(const Duration(minutes: 35)),
  ),
  MarketplaceAuditLog(
    id: 'log-2',
    userRole: 'CATALOG_ADMIN',
    userIdentifier: 'catalog@milterra.com',
    action: AuditAction.statusChange,
    entityType: 'Product',
    entityId: 'mil-minera-5kg',
    details: 'Assigned status Concept Preview under Animal Nutrition > Supplements.',
    timestamp: DateTime.now().subtract(const Duration(hours: 2, minutes: 15)),
  ),
  MarketplaceAuditLog(
    id: 'log-3',
    userRole: 'SUPER_ADMIN',
    userIdentifier: 'admin@milterra.com',
    action: AuditAction.sellerApproval,
    entityType: 'SellerAccount',
    entityId: 'seller-gir-organics',
    details: 'Approved Gir Organic Dairy Farmers KYC after FSSAI document verification.',
    timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
  ),
];
