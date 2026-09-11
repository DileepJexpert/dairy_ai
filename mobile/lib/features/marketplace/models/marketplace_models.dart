import 'package:flutter/foundation.dart';

enum SellerStatus { pendingApproval, approved, suspended, rejected }
enum OfferStatus { active, paused, outOfStock, underReview }
enum FulfillmentType { fulfilledByMilterra, sellerDirect }
enum DealType { dealOfTheDay, lightningDeal, festivalSpecial }
enum CouponType { percentage, flat }
enum AuditAction { priceChange, imageUpdate, stockAdjust, dealCreate, sellerApproval, sellerSuspension, catalogCreate, statusChange }

@immutable
class SellerAccount {
  const SellerAccount({
    required this.id,
    required this.businessName,
    this.tradeName,
    this.gstin,
    this.fssaiLicense,
    this.contactEmail,
    this.contactPhone,
    this.warehouseCity,
    this.warehouseState,
    this.bankAccountNumber,
    this.ifscCode,
    this.upiId,
    this.status = SellerStatus.pendingApproval,
    this.commissionRatePercent = 8.0,
    this.ratingScore = 4.8,
    this.totalRatingsCount = 0,
    required this.createdAt,
  });

  final String id;
  final String businessName;
  final String? tradeName;
  final String? gstin;
  final String? fssaiLicense;
  final String? contactEmail;
  final String? contactPhone;
  final String? warehouseCity;
  final String? warehouseState;
  final String? bankAccountNumber;
  final String? ifscCode;
  final String? upiId;
  final SellerStatus status;
  final double commissionRatePercent;
  final double ratingScore;
  final int totalRatingsCount;
  final DateTime createdAt;

  SellerAccount copyWith({
    SellerStatus? status,
    double? commissionRatePercent,
    double? ratingScore,
    int? totalRatingsCount,
  }) =>
      SellerAccount(
        id: id,
        businessName: businessName,
        tradeName: tradeName,
        gstin: gstin,
        fssaiLicense: fssaiLicense,
        contactEmail: contactEmail,
        contactPhone: contactPhone,
        warehouseCity: warehouseCity,
        warehouseState: warehouseState,
        bankAccountNumber: bankAccountNumber,
        ifscCode: ifscCode,
        upiId: upiId,
        status: status ?? this.status,
        commissionRatePercent: commissionRatePercent ?? this.commissionRatePercent,
        ratingScore: ratingScore ?? this.ratingScore,
        totalRatingsCount: totalRatingsCount ?? this.totalRatingsCount,
        createdAt: createdAt,
      );
}

@immutable
class SellerOffer {
  const SellerOffer({
    required this.id,
    required this.productId,
    required this.sellerId,
    required this.sellerName,
    required this.sellerSku,
    required this.mrp,
    required this.sellingPrice,
    this.discountPercent = 0.0,
    required this.availableStock,
    this.lowStockThreshold = 5,
    this.deliveryPromise = 'FREE delivery by Tomorrow',
    this.fulfillmentType = FulfillmentType.fulfilledByMilterra,
    this.offerStatus = OfferStatus.active,
    this.sellerRating = 4.8,
    this.isBuyBoxWinner = false,
  });

  final String id;
  final String productId;
  final String sellerId;
  final String sellerName;
  final String sellerSku;
  final double mrp;
  final double sellingPrice;
  final double discountPercent;
  final int availableStock;
  final int lowStockThreshold;
  final String deliveryPromise;
  final FulfillmentType fulfillmentType;
  final OfferStatus offerStatus;
  final double sellerRating;
  final bool isBuyBoxWinner;

  SellerOffer copyWith({
    double? sellingPrice,
    double? mrp,
    double? discountPercent,
    int? availableStock,
    int? lowStockThreshold,
    OfferStatus? offerStatus,
    bool? isBuyBoxWinner,
  }) =>
      SellerOffer(
        id: id,
        productId: productId,
        sellerId: sellerId,
        sellerName: sellerName,
        sellerSku: sellerSku,
        mrp: mrp ?? this.mrp,
        sellingPrice: sellingPrice ?? this.sellingPrice,
        discountPercent: discountPercent ?? this.discountPercent,
        availableStock: availableStock ?? this.availableStock,
        lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
        deliveryPromise: deliveryPromise,
        fulfillmentType: fulfillmentType,
        offerStatus: offerStatus ?? this.offerStatus,
        sellerRating: sellerRating,
        isBuyBoxWinner: isBuyBoxWinner ?? this.isBuyBoxWinner,
      );
}

@immutable
class DealPromotion {
  const DealPromotion({
    required this.id,
    required this.title,
    required this.dealType,
    required this.productId,
    required this.productTitle,
    required this.productImage,
    required this.mrp,
    required this.dealPrice,
    required this.discountPercent,
    required this.startTime,
    required this.endTime,
    this.isActive = true,
  });

  final String id;
  final String title;
  final DealType dealType;
  final String productId;
  final String productTitle;
  final String productImage;
  final double mrp;
  final double dealPrice;
  final double discountPercent;
  final DateTime startTime;
  final DateTime endTime;
  final bool isActive;
}

@immutable
class PlatformCoupon {
  const PlatformCoupon({
    required this.id,
    required this.code,
    required this.description,
    this.discountType = CouponType.percentage,
    required this.discountValue,
    this.minOrderValue = 0.0,
    this.maxDiscountCap,
    this.validUntil,
    this.usageCount = 0,
    this.isActive = true,
  });

  final String id;
  final String code;
  final String description;
  final CouponType discountType;
  final double discountValue;
  final double minOrderValue;
  final double? maxDiscountCap;
  final DateTime? validUntil;
  final int usageCount;
  final bool isActive;
}

@immutable
class MarketplaceAuditLog {
  const MarketplaceAuditLog({
    required this.id,
    required this.userRole,
    required this.userIdentifier,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.details,
    required this.timestamp,
  });

  final String id;
  final String userRole;
  final String userIdentifier;
  final AuditAction action;
  final String entityType;
  final String entityId;
  final String details;
  final DateTime timestamp;
}

enum ListingCategory { cow, buffalo, calf, heifer, bull, goat, sheep, equipment, feed }
enum ListingStatus { active, sold, paused, expired }

@immutable
class MarketplaceListing {
  const MarketplaceListing({
    required this.id,
    required this.sellerId,
    this.cattleId,
    required this.category,
    required this.title,
    required this.price,
    required this.status,
    required this.createdAt,
    this.breed,
    this.ageMonths,
    this.weightKg,
    this.milkYieldLitres,
    this.fatPct,
    this.lactationNumber,
    this.isPregnant = false,
    this.monthsPregnant,
    this.healthVerified = false,
    this.vaccinationVerified = false,
    this.description,
    this.isNegotiable = true,
    this.photos = const [],
    this.locationVillage,
    this.locationDistrict,
    this.locationState,
    this.distanceKm,
    this.viewsCount = 0,
    this.inquiriesCount = 0,
    this.sellerName,
    this.sellerPhone,
    this.isFavorited = false,
  });

  final String id, sellerId, title;
  final String? cattleId,
      breed,
      description,
      locationVillage,
      locationDistrict,
      locationState,
      sellerName,
      sellerPhone;
  final ListingCategory category;
  final ListingStatus status;
  final double price;
  final int? ageMonths, lactationNumber, monthsPregnant;
  final double? weightKg, milkYieldLitres, fatPct, distanceKm;
  final bool isPregnant,
      healthVerified,
      vaccinationVerified,
      isNegotiable,
      isFavorited;
  final List<String> photos;
  final int viewsCount, inquiriesCount;
  final DateTime createdAt;

  factory MarketplaceListing.fromJson(Map<String, dynamic> j) =>
      MarketplaceListing(
        id: j['id'].toString(),
        sellerId: j['seller_id'].toString(),
        cattleId: j['cattle_id']?.toString(),
        category: ListingCategory.values.byName(j['category'] as String? ?? 'cow'),
        title: j['title'] as String? ?? '',
        price: (j['price'] as num?)?.toDouble() ?? 0,
        status:
            ListingStatus.values.byName(j['status'] as String? ?? 'active'),
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
        breed: j['breed'] as String?,
        ageMonths: j['age_months'] as int?,
        weightKg: (j['weight_kg'] as num?)?.toDouble(),
        milkYieldLitres: (j['milk_yield_litres'] as num?)?.toDouble(),
        fatPct: (j['fat_pct'] as num?)?.toDouble(),
        lactationNumber: j['lactation_number'] as int?,
        isPregnant: j['is_pregnant'] as bool? ?? false,
        monthsPregnant: j['months_pregnant'] as int?,
        healthVerified: j['health_verified'] as bool? ?? false,
        vaccinationVerified: j['vaccination_verified'] as bool? ?? false,
        description: j['description'] as String?,
        isNegotiable: j['is_negotiable'] as bool? ?? true,
        photos:
            (j['photos'] as List? ?? []).map((x) => x.toString()).toList(),
        locationVillage: j['location_village'] as String?,
        locationDistrict: j['location_district'] as String?,
        locationState: j['location_state'] as String?,
        distanceKm: (j['distance_km'] as num?)?.toDouble(),
        viewsCount: j['views_count'] as int? ?? 0,
        inquiriesCount: j['inquiries_count'] as int? ?? 0,
        sellerName: j['seller_name'] as String?,
        sellerPhone: j['seller_phone'] as String?,
        isFavorited: j['is_favorited'] as bool? ?? false,
      );

  MarketplaceListing copyWith({bool? isFavorited}) => MarketplaceListing(
        id: id,
        sellerId: sellerId,
        cattleId: cattleId,
        category: category,
        title: title,
        price: price,
        status: status,
        createdAt: createdAt,
        breed: breed,
        ageMonths: ageMonths,
        weightKg: weightKg,
        milkYieldLitres: milkYieldLitres,
        fatPct: fatPct,
        lactationNumber: lactationNumber,
        isPregnant: isPregnant,
        monthsPregnant: monthsPregnant,
        healthVerified: healthVerified,
        vaccinationVerified: vaccinationVerified,
        description: description,
        isNegotiable: isNegotiable,
        photos: photos,
        locationVillage: locationVillage,
        locationDistrict: locationDistrict,
        locationState: locationState,
        distanceKm: distanceKm,
        viewsCount: viewsCount,
        inquiriesCount: inquiriesCount,
        sellerName: sellerName,
        sellerPhone: sellerPhone,
        isFavorited: isFavorited ?? this.isFavorited,
      );
}

@immutable
class MarketplaceFilter {
  const MarketplaceFilter({
    this.category,
    this.breed,
    this.minPrice,
    this.maxPrice,
    this.state,
    this.district,
    this.isPregnant,
    this.healthVerified,
    this.sort = 'newest',
  });

  final ListingCategory? category;
  final String? breed, state, district, sort;
  final double? minPrice, maxPrice;
  final bool? isPregnant, healthVerified;

  Map<String, dynamic> get query => {
        'category': category?.name,
        'breed': breed,
        'min_price': minPrice,
        'max_price': maxPrice,
        'state': state,
        'district': district,
        'is_pregnant': isPregnant,
        'health_verified': healthVerified,
      }..removeWhere((_, v) => v == null || v == '');
}
