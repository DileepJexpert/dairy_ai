import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CampaignPosterConfig {
  final String id;
  final String brand;
  final String title;
  final String highlightTag;
  final String wasPrice;
  final String nowPrice;
  final String rewardTag;
  final String couponCode;
  final String imagePath;
  final String category;
  final Color primaryColor;
  final Color accentColor;

  const CampaignPosterConfig({
    required this.id,
    this.brand = 'MILTERRA',
    required this.title,
    required this.highlightTag,
    required this.wasPrice,
    required this.nowPrice,
    required this.rewardTag,
    required this.couponCode,
    required this.imagePath,
    required this.category,
    this.primaryColor = const Color(0xff111827),
    this.accentColor = const Color(0xffd97706),
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'brand': brand,
        'title': title,
        'highlightTag': highlightTag,
        'wasPrice': wasPrice,
        'nowPrice': nowPrice,
        'rewardTag': rewardTag,
        'couponCode': couponCode,
        'imagePath': imagePath,
        'category': category,
      };

  factory CampaignPosterConfig.fromJson(Map<String, dynamic> j) =>
      CampaignPosterConfig(
        id: j['id'] ?? '',
        brand: j['brand'] ?? 'MILTERRA',
        title: j['title'] ?? '',
        highlightTag: j['highlightTag'] ?? '',
        wasPrice: j['wasPrice'] ?? '',
        nowPrice: j['nowPrice'] ?? '',
        rewardTag: j['rewardTag'] ?? '',
        couponCode: j['couponCode'] ?? '',
        imagePath: j['imagePath'] ?? '',
        category: j['category'] ?? '',
      );

  CampaignPosterConfig copyWith({
    String? title,
    String? highlightTag,
    String? wasPrice,
    String? nowPrice,
    String? rewardTag,
    String? couponCode,
    String? imagePath,
    String? category,
  }) =>
      CampaignPosterConfig(
        id: id,
        brand: brand,
        title: title ?? this.title,
        highlightTag: highlightTag ?? this.highlightTag,
        wasPrice: wasPrice ?? this.wasPrice,
        nowPrice: nowPrice ?? this.nowPrice,
        rewardTag: rewardTag ?? this.rewardTag,
        couponCode: couponCode ?? this.couponCode,
        imagePath: imagePath ?? this.imagePath,
        category: category ?? this.category,
        primaryColor: primaryColor,
        accentColor: accentColor,
      );
}

const List<CampaignPosterConfig> defaultCampaignPosters = [
  CampaignPosterConfig(
    id: 'cow-ghee',
    brand: 'MILTERRA',
    title: 'Vedic A2 Cow Ghee Range',
    highlightTag: 'PRICE DROPPED BY ₹200',
    wasPrice: '₹1,600',
    nowPrice: '₹1,399',
    rewardTag: '+ 5% Milterra Coins',
    couponCode: 'BILONA200',
    imagePath: 'assets/store/poster-card-cow-ghee.jpg',
    category: 'Vedic Bilona Ghee',
    accentColor: Color(0xffd97706),
  ),
  CampaignPosterConfig(
    id: 'mustard-oil',
    brand: 'MILTERRA',
    title: 'Wood-Pressed Sarso Oil Range',
    highlightTag: 'EXTRA 15% OFF',
    wasPrice: '₹490',
    nowPrice: '₹430',
    rewardTag: '100% Wood-Pressed Kolhu',
    couponCode: 'SARSO15',
    imagePath: 'assets/store/poster-card-mustard-oil.jpg',
    category: 'Cold-Pressed Sarso (Mustard) Oil',
    accentColor: Color(0xffb45309),
  ),
  CampaignPosterConfig(
    id: 'buffalo-ghee',
    brand: 'MILTERRA',
    title: 'Cultured Murrah Buffalo Ghee',
    highlightTag: 'EXCLUSIVE HARVEST',
    wasPrice: '₹550',
    nowPrice: '₹499',
    rewardTag: 'Granular Danedar Texture',
    couponCode: 'MURRAH50',
    imagePath: 'assets/store/poster-card-buffalo-ghee.jpg',
    category: 'Cultured Buffalo Ghee',
    accentColor: Color(0xff0d9488),
  ),
  CampaignPosterConfig(
    id: 'paneer',
    brand: 'MILTERRA',
    title: 'Fresh Living Malai Paneer',
    highlightTag: 'FARM FRESH DAILY BATCH',
    wasPrice: '₹260',
    nowPrice: '₹210',
    rewardTag: 'Zero Chemical • Same-Day Churn',
    couponCode: 'FRESH10',
    imagePath: 'assets/store/poster-card-paneer.jpg',
    category: 'Fresh Milk & Dairy',
    accentColor: Color(0xff16a34a),
  ),
];

class CampaignPostersNotifier extends StateNotifier<List<CampaignPosterConfig>> {
  CampaignPostersNotifier() : super(defaultCampaignPosters) {
    _loadFromStorage();
  }

  static const _storageKey = 'milterra_campaign_posters_v1';
  final _storage = const FlutterSecureStorage();

  Future<void> _loadFromStorage() async {
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List;
        state = decoded
            .map((item) => CampaignPosterConfig.fromJson(
                Map<String, dynamic>.from(item as Map)))
            .toList();
      }
    } catch (_) {
      // Use defaults if storage fails or is empty
    }
  }

  Future<void> updatePoster(int index, CampaignPosterConfig updated) async {
    if (index < 0 || index >= state.length) return;
    final newList = List<CampaignPosterConfig>.from(state);
    newList[index] = updated;
    state = newList;
    await _persist();
  }

  Future<void> resetToDefaults() async {
    state = List<CampaignPosterConfig>.from(defaultCampaignPosters);
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final jsonStr = jsonEncode(state.map((p) => p.toJson()).toList());
      await _storage.write(key: _storageKey, value: jsonStr);
    } catch (_) {}
  }
}

final campaignPostersProvider = StateNotifierProvider<
    CampaignPostersNotifier, List<CampaignPosterConfig>>((ref) {
  return CampaignPostersNotifier();
});
