enum ProductCategory { equipment, feedNutrition }

class Product {
  const Product(
      {required this.id,
      required this.vendorId,
      required this.title,
      required this.category,
      required this.price,
      required this.unit,
      this.brand,
      this.packSize,
      this.description,
      this.specifications = const {},
      this.inStock = false,
      this.availableQuantity = 0,
      this.minOrderQuantity = 1,
      this.media = const [],
      this.vendor,
      this.isRentable = false,
      this.rentalRatePerHour,
      this.rentalRatePerAcre});
  final String id, vendorId, title, unit;
  final ProductCategory category;
  final double price;
  final String? brand, packSize, description;
  final Map<String, dynamic> specifications;
  final bool inStock, isRentable;
  final int availableQuantity, minOrderQuantity;
  final List<String> media;
  final Map<String, dynamic>? vendor;
  final double? rentalRatePerHour;
  final dynamic rentalRatePerAcre;
  factory Product.fromJson(Map<String, dynamic> j) => Product(
      id: j['id'].toString(),
      vendorId: j['vendor_id'].toString(),
      title: j['title'] ?? '',
      category: j['category'] == 'EQUIPMENT'
          ? ProductCategory.equipment
          : ProductCategory.feedNutrition,
      price: double.parse(j['base_price'].toString()),
      unit: j['unit'] ?? '',
      brand: j['brand'],
      packSize: j['pack_size'],
      description: j['description'],
      specifications: Map<String, dynamic>.from(j['specifications'] ?? {}),
      inStock: j['in_stock'] ?? false,
      availableQuantity: j['available_quantity'] ?? 0,
      minOrderQuantity: j['min_order_quantity'] ?? 1,
      media:
          (j['media'] as List? ?? []).map((x) => x['url'].toString()).toList(),
      vendor:
          j['vendor'] is Map ? Map<String, dynamic>.from(j['vendor']) : null,
      isRentable: j['is_rentable'] ?? false,
      rentalRatePerHour: j['rental_rate_per_hour'] == null
          ? null
          : double.parse(j['rental_rate_per_hour'].toString()),
      rentalRatePerAcre: j['rental_rate_per_acre']);
}
