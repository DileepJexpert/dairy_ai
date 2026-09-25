import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LocalBasketItem {
  final String productId;
  final int quantity;
  final double? priceWhenAdded;
  final String? title;
  final String? primaryImage;
  final String? unit;
  final String? packSize;
  final DateTime addedAt;

  const LocalBasketItem({
    required this.productId,
    required this.quantity,
    this.priceWhenAdded,
    this.title,
    this.primaryImage,
    this.unit,
    this.packSize,
    required this.addedAt,
  });

  LocalBasketItem copyWith({
    String? productId,
    int? quantity,
    double? priceWhenAdded,
    String? title,
    String? primaryImage,
    String? unit,
    String? packSize,
    DateTime? addedAt,
  }) {
    return LocalBasketItem(
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      priceWhenAdded: priceWhenAdded ?? this.priceWhenAdded,
      title: title ?? this.title,
      primaryImage: primaryImage ?? this.primaryImage,
      unit: unit ?? this.unit,
      packSize: packSize ?? this.packSize,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'quantity': quantity,
        if (priceWhenAdded != null) 'price_when_added': priceWhenAdded,
        if (title != null) 'title': title,
        if (primaryImage != null) 'primary_image': primaryImage,
        if (unit != null) 'unit': unit,
        if (packSize != null) 'pack_size': packSize,
        'added_at': addedAt.toIso8601String(),
      };

  factory LocalBasketItem.fromJson(Map<String, dynamic> json) {
    return LocalBasketItem(
      productId: json['product_id']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      priceWhenAdded: json['price_when_added'] != null
          ? double.tryParse(json['price_when_added'].toString())
          : null,
      title: json['title']?.toString(),
      primaryImage: json['primary_image']?.toString(),
      unit: json['unit']?.toString(),
      packSize: json['pack_size']?.toString(),
      addedAt: json['added_at'] != null
          ? DateTime.tryParse(json['added_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class LocalBasketStorage {
  static const storageKey = 'milterra_local_basket_v1';
  final FlutterSecureStorage? _storage;
  List<LocalBasketItem>? _memoryCache;

  LocalBasketStorage({FlutterSecureStorage? storage}) : _storage = storage;

  Future<List<LocalBasketItem>> load() async {
    if (_memoryCache != null) return List.unmodifiable(_memoryCache!);
    try {
      final raw = await _storage?.read(key: storageKey);
      if (raw == null || raw.isEmpty) {
        _memoryCache = [];
        return [];
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        _memoryCache = [];
        return [];
      }
      _memoryCache = decoded
          .whereType<Map>()
          .map((m) => LocalBasketItem.fromJson(Map<String, dynamic>.from(m)))
          .where((item) => item.productId.isNotEmpty && item.quantity > 0)
          .toList();
      return List.unmodifiable(_memoryCache!);
    } catch (_) {
      _memoryCache = [];
      return [];
    }
  }

  Future<void> save(List<LocalBasketItem> items) async {
    _memoryCache = List.from(items);
    try {
      final raw = jsonEncode(items.map((i) => i.toJson()).toList());
      await _storage?.write(key: storageKey, value: raw);
    } catch (_) {
      // In-memory cache guarantees seamless session operations if storage is restricted
    }
  }

  Future<List<LocalBasketItem>> addItem({
    required String productId,
    required int quantity,
    double? price,
    String? title,
    String? primaryImage,
    String? unit,
    String? packSize,
  }) async {
    final items = List<LocalBasketItem>.from(await load());
    final index = items.indexWhere((i) => i.productId == productId);
    if (index >= 0) {
      final existing = items[index];
      items[index] = existing.copyWith(
        quantity: existing.quantity + quantity,
        priceWhenAdded: price ?? existing.priceWhenAdded,
        title: title ?? existing.title,
        primaryImage: primaryImage ?? existing.primaryImage,
        unit: unit ?? existing.unit,
        packSize: packSize ?? existing.packSize,
      );
    } else {
      items.add(LocalBasketItem(
        productId: productId,
        quantity: quantity,
        priceWhenAdded: price,
        title: title,
        primaryImage: primaryImage,
        unit: unit,
        packSize: packSize,
        addedAt: DateTime.now(),
      ));
    }
    await save(items);
    return List.unmodifiable(items);
  }

  Future<List<LocalBasketItem>> updateQuantity(
      String productId, int quantity) async {
    final items = List<LocalBasketItem>.from(await load());
    if (quantity <= 0) {
      items.removeWhere((i) => i.productId == productId);
    } else {
      final index = items.indexWhere((i) => i.productId == productId);
      if (index >= 0) {
        items[index] = items[index].copyWith(quantity: quantity);
      }
    }
    await save(items);
    return List.unmodifiable(items);
  }

  Future<List<LocalBasketItem>> removeItem(String productId) async {
    final items = List<LocalBasketItem>.from(await load());
    items.removeWhere((i) => i.productId == productId);
    await save(items);
    return List.unmodifiable(items);
  }

  Future<void> clear() async {
    _memoryCache = [];
    try {
      await _storage?.delete(key: storageKey);
    } catch (_) {}
  }
}

final localBasketStorageProvider = Provider<LocalBasketStorage>((ref) {
  return LocalBasketStorage(storage: const FlutterSecureStorage());
});
