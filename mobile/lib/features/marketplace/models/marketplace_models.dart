import 'package:flutter/foundation.dart';

/// Categories of marketplace listings.
enum ListingCategory { cattle, equipment, feed }

/// Status of a listing.
enum ListingStatus { active, sold, expired }

/// A single marketplace listing.
@immutable
class Listing {
  final int id;
  final String title;
  final String description;
  final ListingCategory category;
  final double price;
  final String? imageUrl;
  final String sellerName;
  final String? sellerPhone;
  final String? location;
  final ListingStatus status;
  final DateTime createdAt;

  const Listing({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.price,
    this.imageUrl,
    required this.sellerName,
    this.sellerPhone,
    this.location,
    required this.status,
    required this.createdAt,
  });

  factory Listing.fromJson(Map<String, dynamic> json) {
    return Listing(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: ListingCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => ListingCategory.cattle,
      ),
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['image_url'] as String?,
      sellerName: json['seller_name'] as String? ?? 'Unknown',
      sellerPhone: json['seller_phone'] as String?,
      location: json['location'] as String?,
      status: ListingStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ListingStatus.active,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'category': category.name,
        'price': price,
        'image_url': imageUrl,
        'location': location,
      };

  String get categoryLabel {
    switch (category) {
      case ListingCategory.cattle:
        return 'Cattle for Sale';
      case ListingCategory.equipment:
        return 'Equipment';
      case ListingCategory.feed:
        return 'Feed Supplies';
    }
  }
}
