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
    id: 'wild-honey',
    brand: 'MILTERRA',
    title: 'Raw Wild Mustard Honey',
    highlightTag: 'UNFILTERED & NMR TESTED',
    wasPrice: '₹450',
    nowPrice: '₹350',
    rewardTag: '+ 5% Milterra Coins',
    couponCode: 'HONEY15',
    imagePath: 'assets/store/raw-mustard-honey.jpg',
    category: 'Wood-Pressed Oils & Pure Sweeteners',
    accentColor: Color(0xffd97706),
  ),
  CampaignPosterConfig(
    id: 'shata-dhauta',
    brand: 'MILTERRA',
    title: '100x Washed Ghee Cream',
    highlightTag: 'AYURVEDIC RADIANCE',
    wasPrice: '₹890',
    nowPrice: '₹699',
    rewardTag: '100-Times Washed in Copper',
    couponCode: 'SHATA20',
    imagePath: 'assets/store/shata-dhauta-ghrita.jpg',
    category: 'Vedic Skincare & Botanicals',
    accentColor: Color(0xffb45309),
  ),
  CampaignPosterConfig(
    id: 'live-microgreens',
    brand: 'MILTERRA',
    title: 'Live Farm Microgreens',
    highlightTag: 'HARVESTED ON ORDER (LIVE)',
    wasPrice: '₹220',
    nowPrice: '₹160',
    rewardTag: '+ 5% Milterra Coins',
    couponCode: 'GREENS20',
    imagePath: 'assets/store/live-microgreens.jpg',
    category: 'Hydroponic & Organic Greens',
    accentColor: Color(0xff15803d),
  ),
  CampaignPosterConfig(
    id: 'white-butter',
    brand: 'MILTERRA',
    title: 'Vedic A2 White Butter',
    highlightTag: 'HAND-CHURNED BILONA MAKHAN',
    wasPrice: '₹380',
    nowPrice: '₹299',
    rewardTag: 'Cultured Farm Makhan',
    couponCode: 'MAKHAN15',
    imagePath: 'assets/store/white-butter.jpg',
    category: 'Vedic A2 Dairy & Farm Fresh',
    accentColor: Color(0xffd97706),
  ),
];

class CampaignPostersNotifier extends StateNotifier<List<CampaignPosterConfig>> {
  CampaignPostersNotifier() : super(defaultCampaignPosters) {
    _loadFromStorage();
  }

  static const _storageKey = 'milterra_campaign_posters_v3';
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
