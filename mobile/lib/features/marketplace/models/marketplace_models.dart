import 'package:flutter/foundation.dart';

enum ListingCategory { cow, buffalo, bull, calf, heifer }

enum ListingStatus { active, sold, cancelled, expired }

@immutable
class MarketplaceListing {
  const MarketplaceListing(
      {required this.id,
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
      this.isFavorited = false});
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
          category: ListingCategory.values.byName(j['category'] as String),
          title: j['title'] as String? ?? '',
          price: (j['price'] as num?)?.toDouble() ?? 0,
          status:
              ListingStatus.values.byName(j['status'] as String? ?? 'active'),
          createdAt: DateTime.parse(j['created_at'] as String),
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
          isFavorited: j['is_favorited'] as bool? ?? false);
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
      isFavorited: isFavorited ?? this.isFavorited);
}

@immutable
class MarketplaceFilter {
  const MarketplaceFilter(
      {this.category,
      this.breed,
      this.minPrice,
      this.maxPrice,
      this.state,
      this.district,
      this.isPregnant,
      this.healthVerified,
      this.sort = 'newest'});
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
        'health_verified': healthVerified
      }..removeWhere((_, v) => v == null || v == '');
}
