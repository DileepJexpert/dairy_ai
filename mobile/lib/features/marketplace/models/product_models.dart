enum ProductCategory { equipment, feedNutrition }

class ProductVariant {
  const ProductVariant({
    required this.id,
    required this.sku,
    required this.packSize,
    required this.price,
    this.compareAtPrice,
    this.stockQuantity = 0,
    this.inStock = true,
    this.weightGrams,
  });

  final String id;
  final String sku;
  final String packSize;
  final double price;
  final double? compareAtPrice;
  final int stockQuantity;
  final bool inStock;
  final int? weightGrams;

  factory ProductVariant.fromJson(Map<String, dynamic> json) => ProductVariant(
        id: json['id']?.toString() ?? '',
        sku: json['sku']?.toString() ?? '',
        packSize: json['pack_size']?.toString() ?? '',
        price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
        compareAtPrice: json['compare_at_price'] != null
            ? double.tryParse(json['compare_at_price'].toString())
            : null,
        stockQuantity: json['stock_quantity'] is int
            ? json['stock_quantity']
            : int.tryParse(json['stock_quantity']?.toString() ?? '0') ?? 0,
        inStock: json['in_stock'] ?? true,
        weightGrams: json['weight_grams'] != null
            ? int.tryParse(json['weight_grams'].toString())
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'sku': sku,
        'pack_size': packSize,
        'price': price,
        'compare_at_price': compareAtPrice,
        'stock_quantity': stockQuantity,
        'in_stock': inStock,
        'weight_grams': weightGrams,
      };
}

/// Explicit Product Family model grouping multiple sellable pack variants
/// under a unified brand, taxonomy classification, and core description.
class ProductFamily {
  const ProductFamily({
    required this.id,
    required this.title,
    required this.brand,
    required this.department,
    this.taxonomyNodeId,
    this.taxonomyPath,
    required this.description,
    this.primaryImage,
    this.media = const [],
    this.variants = const [],
    this.isOrganic = false,
    this.purityGrade,
    this.fssaiLicense,
  });

  final String id;
  final String title;
  final String brand;
  final String department;
  final String? taxonomyNodeId;
  final String? taxonomyPath;
  final String description;
  final String? primaryImage;
  final List<String> media;
  final List<ProductVariant> variants;
  final bool isOrganic;
  final String? purityGrade;
  final String? fssaiLicense;

  double get startingPrice {
    if (variants.isEmpty) return 0.0;
    return variants.map((v) => v.price).reduce((a, b) => a < b ? a : b);
  }

  double get maxPrice {
    if (variants.isEmpty) return 0.0;
    return variants.map((v) => v.price).reduce((a, b) => a > b ? a : b);
  }

  int get totalStock {
    if (variants.isEmpty) return 0;
    return variants.map((v) => v.stockQuantity).reduce((a, b) => a + b);
  }

  bool get hasStock => variants.any((v) => v.inStock && v.stockQuantity > 0);

  ProductFamily copyWith({
    String? id,
    String? title,
    String? brand,
    String? department,
    String? taxonomyNodeId,
    String? taxonomyPath,
    String? description,
    String? primaryImage,
    List<String>? media,
    List<ProductVariant>? variants,
    bool? isOrganic,
    String? purityGrade,
    String? fssaiLicense,
  }) {
    return ProductFamily(
      id: id ?? this.id,
      title: title ?? this.title,
      brand: brand ?? this.brand,
      department: department ?? this.department,
      taxonomyNodeId: taxonomyNodeId ?? this.taxonomyNodeId,
      taxonomyPath: taxonomyPath ?? this.taxonomyPath,
      description: description ?? this.description,
      primaryImage: primaryImage ?? this.primaryImage,
      media: media ?? this.media,
      variants: variants ?? this.variants,
      isOrganic: isOrganic ?? this.isOrganic,
      purityGrade: purityGrade ?? this.purityGrade,
      fssaiLicense: fssaiLicense ?? this.fssaiLicense,
    );
  }

  factory ProductFamily.fromJson(Map<String, dynamic> json) => ProductFamily(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        brand: json['brand']?.toString() ?? 'Milterra',
        department: json['department']?.toString() ?? 'Dairy Foods',
        taxonomyNodeId: json['taxonomy_node_id']?.toString(),
        taxonomyPath: json['taxonomy_path']?.toString(),
        description: json['description']?.toString() ?? '',
        primaryImage: json['primary_image']?.toString(),
        media: (json['media'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        variants: (json['variants'] as List<dynamic>?)
                ?.map((e) => ProductVariant.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        isOrganic: json['is_organic'] ?? false,
        purityGrade: json['purity_grade']?.toString(),
        fssaiLicense: json['fssai_license']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'brand': brand,
        'department': department,
        'taxonomy_node_id': taxonomyNodeId,
        'taxonomy_path': taxonomyPath,
        'description': description,
        'primary_image': primaryImage,
        'media': media,
        'variants': variants.map((v) => v.toJson()).toList(),
        'is_organic': isOrganic,
        'purity_grade': purityGrade,
        'fssai_license': fssaiLicense,
      };
}

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
      this.taxonomy,
      this.taxonomyEnabled = false,
      this.specifications = const {},
      this.inStock = false,
      this.availableQuantity = 0,
      this.minOrderQuantity = 1,
      this.media = const [],
      this.vendor,
      this.isRentable = false,
      this.rentalRatePerHour,
      this.rentalRatePerAcre,
      this.variants = const []});
  final String id, vendorId, title, unit;
  final ProductCategory category;
  final double price;
  final String? brand, packSize, description;
  final Map<String, dynamic>? taxonomy;
  final bool taxonomyEnabled;
  final Map<String, dynamic> specifications;
  final bool inStock, isRentable;
  final int availableQuantity, minOrderQuantity;
  final List<String> media;
  final Map<String, dynamic>? vendor;
  final double? rentalRatePerHour;
  final dynamic rentalRatePerAcre;
  final List<ProductVariant> variants;

  Product copyWith({
    String? id,
    String? vendorId,
    String? title,
    ProductCategory? category,
    double? price,
    String? unit,
    String? brand,
    String? packSize,
    String? description,
    Map<String, dynamic>? taxonomy,
    bool? taxonomyEnabled,
    Map<String, dynamic>? specifications,
    bool? inStock,
    int? availableQuantity,
    int? minOrderQuantity,
    List<String>? media,
    Map<String, dynamic>? vendor,
    bool? isRentable,
    double? rentalRatePerHour,
    dynamic rentalRatePerAcre,
    List<ProductVariant>? variants,
  }) =>
      Product(
        id: id ?? this.id,
        vendorId: vendorId ?? this.vendorId,
        title: title ?? this.title,
        category: category ?? this.category,
        price: price ?? this.price,
        unit: unit ?? this.unit,
        brand: brand ?? this.brand,
        packSize: packSize ?? this.packSize,
        description: description ?? this.description,
        taxonomy: taxonomy ?? this.taxonomy,
        taxonomyEnabled: taxonomyEnabled ?? this.taxonomyEnabled,
        specifications: specifications ?? this.specifications,
        inStock: inStock ?? this.inStock,
        availableQuantity: availableQuantity ?? this.availableQuantity,
        minOrderQuantity: minOrderQuantity ?? this.minOrderQuantity,
        media: media ?? this.media,
        vendor: vendor ?? this.vendor,
        isRentable: isRentable ?? this.isRentable,
        rentalRatePerHour: rentalRatePerHour ?? this.rentalRatePerHour,
        rentalRatePerAcre: rentalRatePerAcre ?? this.rentalRatePerAcre,
        variants: variants ?? this.variants,
      );

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
      taxonomyEnabled: j.containsKey('taxonomy'),
      taxonomy: j['taxonomy'] == null
          ? null
          : Map<String, dynamic>.from(j['taxonomy']),
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
      rentalRatePerAcre: j['rental_rate_per_acre'],
      variants: (j['variants'] as List? ?? [])
          .map((v) => ProductVariant.fromJson(Map<String, dynamic>.from(v as Map)))
          .toList());
}

/// Rich default multi-department catalogue serving Retail Consumers & Dairy Farmers
const defaultMilterraProducts = <Product>[
  // ---- 1. Retail Dairy Foods (Household Consumers) ----
  Product(
    id: 'mil-ghee-500',
    vendorId: 'vendor-milterra-dairy',
    title: 'MILTERRA A2 Desi Cow Ghee',
    category: ProductCategory.feedNutrition,
    price: 799,
    unit: 'jar',
    brand: 'MILTERRA',
    packSize: '500 ml',
    description:
        'Traditional A2 Bilona cultured cow ghee from grass-fed Gir and Sahiwal cows. Lab-certified 100% pure.',
    taxonomy: {
      'department_name': 'Dairy Foods',
      'category_name': 'Cow ghee',
      'department_id': 'dairy-foods',
      'category_id': 'cow-ghee'
    },
    inStock: true,
    availableQuantity: 45,
    minOrderQuantity: 1,
    specifications: {
      'Source': 'A2 Gir Cow Milk',
      'Process': 'Traditional Bilona',
      'Shelf Life': '12 Months',
      'Diet Type': 'Vegetarian'
    },
  ),
  Product(
    id: 'mil-ghee-1000',
    vendorId: 'vendor-milterra-dairy',
    title: 'MILTERRA A2 Desi Cow Ghee',
    category: ProductCategory.feedNutrition,
    price: 1499,
    unit: 'jar',
    brand: 'MILTERRA',
    packSize: '1 litre',
    description:
        'Everyday traditional A2 bilona ghee for authentic Indian cooking, ayurvedic wellness, and immunity.',
    taxonomy: {
      'department_name': 'Dairy Foods',
      'category_name': 'Cow ghee',
      'department_id': 'dairy-foods',
      'category_id': 'cow-ghee'
    },
    inStock: true,
    availableQuantity: 30,
    minOrderQuantity: 1,
    specifications: {
      'Source': 'A2 Gir Cow Milk',
      'Process': 'Traditional Bilona',
      'Shelf Life': '12 Months',
      'Diet Type': 'Vegetarian'
    },
  ),
  Product(
    id: 'mil-buff-500',
    vendorId: 'vendor-milterra-dairy',
    title: 'MILTERRA Rich Buffalo Ghee',
    category: ProductCategory.feedNutrition,
    price: 699,
    unit: 'jar',
    brand: 'MILTERRA',
    packSize: '500 ml',
    description:
        'Full-bodied, granular Murrah buffalo ghee with a naturally rich aroma. Perfect for sweets, rotis, and dal tadka.',
    taxonomy: {
      'department_name': 'Dairy Foods',
      'category_name': 'Buffalo ghee',
      'department_id': 'dairy-foods',
      'category_id': 'buffalo-ghee'
    },
    inStock: true,
    availableQuantity: 28,
    minOrderQuantity: 1,
    specifications: {
      'Source': 'Murrah Buffalo Milk',
      'Texture': 'Danedaar / Granular',
      'Shelf Life': '12 Months'
    },
  ),
  Product(
    id: 'mil-paneer-200',
    vendorId: 'vendor-milterra-dairy',
    title: 'MILTERRA Fresh Malai Paneer',
    category: ProductCategory.feedNutrition,
    price: 160,
    unit: 'block',
    brand: 'MILTERRA',
    packSize: '200 g',
    description:
        'Vacuum-sealed fresh malai paneer crafted from whole farm milk. Soft, non-rubbery texture packed with 18g protein.',
    taxonomy: {
      'department_name': 'Dairy Foods',
      'category_name': 'Paneer',
      'department_id': 'dairy-foods',
      'category_id': 'paneer'
    },
    inStock: true,
    availableQuantity: 50,
    minOrderQuantity: 1,
    specifications: {
      'Protein': '18g per 100g',
      'Fat': '22%',
      'Shelf Life': '15 Days refrigerated'
    },
  ),
  Product(
    id: 'mil-paneer-500',
    vendorId: 'vendor-milterra-dairy',
    title: 'MILTERRA Fresh Malai Paneer',
    category: ProductCategory.feedNutrition,
    price: 380,
    unit: 'block',
    brand: 'MILTERRA',
    packSize: '500 g',
    description:
        'Family block of creamy fresh malai paneer. 100% natural without artificial coagulants or starch.',
    taxonomy: {
      'department_name': 'Dairy Foods',
      'category_name': 'Paneer',
      'department_id': 'dairy-foods',
      'category_id': 'paneer'
    },
    inStock: true,
    availableQuantity: 35,
    minOrderQuantity: 1,
    specifications: {
      'Protein': '18g per 100g',
      'Fat': '22%',
      'Shelf Life': '15 Days refrigerated'
    },
  ),
  Product(
    id: 'mil-butter-250',
    vendorId: 'vendor-milterra-dairy',
    title: 'MILTERRA Cultured White Butter (Makhan)',
    category: ProductCategory.feedNutrition,
    price: 240,
    unit: 'tub',
    brand: 'MILTERRA',
    packSize: '250 g',
    description:
        'Traditional home-churned unsalted white butter (safed makhan). Fresh, cultured, and free from preservatives.',
    taxonomy: {
      'department_name': 'Dairy Foods',
      'category_name': 'Other products',
      'department_id': 'dairy-foods',
      'category_id': 'dairy-foods'
    },
    inStock: true,
    availableQuantity: 20,
    minOrderQuantity: 1,
    specifications: {
      'Salt': 'Unsalted',
      'Type': 'Cultured Cream Butter',
      'Storage': 'Keep Chilled'
    },
  ),

  // ---- 2. MILTERRA Earth: Living Soil & Farm By-Products (Coming Soon) ----
  Product(
    id: 'mil-earth-vermi-5kg',
    vendorId: 'vendor-milterra-earth',
    title: 'MILTERRA Earth Premium Vermicompost',
    category: ProductCategory.feedNutrition,
    price: 299,
    unit: 'bag',
    brand: 'MILTERRA Earth',
    packSize: '5 kg',
    description:
        'Pure organic vermicompost produced by Eisenia fetida earthworms feeding on aged indigenous cow dung and organic farm biomass. Enriched with billions of living beneficial soil microbes, bio-humus, and essential macro & micro-nutrients to restore living soil health.',
    taxonomy: {
      'department_name': 'MILTERRA Earth',
      'category_name': 'MILTERRA Earth',
      'subcategory_name': 'Vermicompost',
      'brand_line': 'Living Soil • Farm Composts • Natural Carbon',
      'tagline': 'From Farm Waste to Living Soil',
      'status': 'Coming Soon',
      'concept': false,
      'is_earth': true,
      'department_id': 'milterra-earth',
      'category_id': 'milterra-earth',
      'usage_description':
          'Ideal for home gardens, potted houseplants, kitchen terrace greens, and organic farm beds. Mix 20-30% into potting soil or apply 100-200g around root zones monthly.',
      'traceability':
          'Sourced from Certified Dairy AI Partner Farms • Batch-Tested Organic Carbon (Min 16%) • 100% Weed-Seed & Pathogen Free',
    },
    media: [
      'assets/store/earth-vermicompost.jpg',
      'assets/store/farm-pasture.jpg',
    ],
    inStock: false,
    availableQuantity: 0,
    minOrderQuantity: 1,
    specifications: {
      'Category': 'Living Soil & Organic Fertilizer',
      'Source': 'Aged Indigenous Desi Cow Dung & Biomass',
      'Process': 'Aerobic Vermicomposting (Eisenia fetida)',
      'Organic Carbon': '16.5% Minimum',
      'Moisture Content': '18% - 22% Optimal',
      'Odor': 'Natural earthy forest aroma (100% Odorless)',
      'Traceability': 'Certified Dairy AI Farm Network · Batch Verified',
    },
  ),
  Product(
    id: 'mil-earth-manure-10kg',
    vendorId: 'vendor-milterra-earth',
    title: 'MILTERRA Earth Cow-Dung Farm Manure',
    category: ProductCategory.feedNutrition,
    price: 249,
    unit: 'bag',
    brand: 'MILTERRA Earth',
    packSize: '10 kg',
    description:
        'Naturally composted, aged and solarized cattle farm manure. Screened for smooth uniform texture without stones or weeds. Replenishes soil organic matter, stimulates subterranean microbial colonies, and improves soil moisture retention.',
    taxonomy: {
      'department_name': 'MILTERRA Earth',
      'category_name': 'MILTERRA Earth',
      'subcategory_name': 'Farm Manure',
      'brand_line': 'Living Soil • Farm Composts • Natural Carbon',
      'tagline': 'From Farm Waste to Living Soil',
      'status': 'Coming Soon',
      'concept': false,
      'is_earth': true,
      'department_id': 'milterra-earth',
      'category_id': 'milterra-earth',
      'usage_description':
          'Top-dress lawn grass, agricultural field beds, fruit trees, and flowering shrubs. Blend with topsoil before new planting cycles.',
      'traceability':
          'Aged 120+ Days • Solarized & Screened • Traceable Cooperative Origin',
    },
    media: [
      'assets/store/earth-manure.jpg',
      'assets/store/farm-pasture.jpg',
    ],
    inStock: false,
    availableQuantity: 0,
    minOrderQuantity: 1,
    specifications: {
      'Category': 'Aged Farm Manure',
      'Curing Period': '120+ Days Controlled Windrow Aging',
      'Screen Size': 'Fine 4mm rotary sieve mesh',
      'Pathogen Status': 'Heat Solarized (Pathogen Free)',
      'Recommended Use': 'Soil Preparation & Seasonal Top-Dressing',
      'Traceability': 'Dairy AI Cooperative Cluster Traceable',
    },
  ),
  Product(
    id: 'mil-earth-compost-5kg',
    vendorId: 'vendor-milterra-earth',
    title: 'MILTERRA Earth Enriched Organic Compost',
    category: ProductCategory.feedNutrition,
    price: 349,
    unit: 'bag',
    brand: 'MILTERRA Earth',
    packSize: '5 kg',
    description:
        'High-grade aerated organic compost blend enriched with natural neem cake, rock phosphate, and beneficial Trichoderma cultures. Protects root systems and supplies slow-release balanced organic nutrients.',
    taxonomy: {
      'department_name': 'MILTERRA Earth',
      'category_name': 'MILTERRA Earth',
      'subcategory_name': 'Enriched Compost',
      'brand_line': 'Living Soil • Farm Composts • Natural Carbon',
      'tagline': 'From Farm Waste to Living Soil',
      'status': 'Coming Soon',
      'concept': false,
      'is_earth': true,
      'department_id': 'milterra-earth',
      'category_id': 'milterra-earth',
      'usage_description':
          'Excellent for flowering plants, balcony containers, and kitchen vegetables. Apply 50g per 10-inch pot every 3 weeks.',
      'traceability':
          '100% Pathogen-Free • Aerobically Composted • Certified Organic Carbon',
    },
    media: [
      'assets/store/earth-vermicompost.jpg',
    ],
    inStock: false,
    availableQuantity: 0,
    minOrderQuantity: 1,
    specifications: {
      'Category': 'Enriched Microbial Compost',
      'Enrichments': 'Cold-Pressed Neem Cake + Rock Phosphate',
      'Bio-Culture': 'Trichoderma viride inoculated',
      'Form': 'Granular moist humus',
      'Safety': 'Safe for pets, earthworms, and indoor plants',
      'Traceability': 'Batch Tested Organic Lab Certified',
    },
  ),
  Product(
    id: 'mil-earth-cakes-12',
    vendorId: 'vendor-milterra-earth',
    title: 'MILTERRA Earth Dried Cow-Dung Compost Cakes',
    category: ProductCategory.feedNutrition,
    price: 199,
    unit: 'box',
    brand: 'MILTERRA Earth',
    packSize: 'Pack of 12 Cakes',
    description:
        'Traditional sun-dried circular cow-dung cakes hand-crafted from indigenous Desi cow dung. Used for organic havan, traditional smoke fumigation for natural insect repellence, or soaked to create liquid compost starter tea.',
    taxonomy: {
      'department_name': 'MILTERRA Earth',
      'category_name': 'MILTERRA Earth',
      'subcategory_name': 'Compost Cakes',
      'brand_line': 'Living Soil • Farm Composts • Natural Carbon',
      'tagline': 'From Farm Waste to Living Soil',
      'status': 'Coming Soon',
      'concept': false,
      'is_earth': true,
      'department_id': 'milterra-earth',
      'category_id': 'milterra-earth',
      'usage_description':
          'Use for traditional rituals, smoke purification, or crumble 1 cake into 5 liters of water with jaggery to brew rich microbial compost tea.',
      'traceability':
          'Gir & Sahiwal Desi Cow Sourced • Sun-Cured on Clean Slates • 0% Chemicals',
    },
    media: [
      'assets/store/earth-cakes.jpg',
    ],
    inStock: false,
    availableQuantity: 0,
    minOrderQuantity: 1,
    specifications: {
      'Category': 'Sun-Dried Cow Dung Cakes',
      'Cattle Breed': 'Indigenous Desi Gir & Sahiwal Cows',
      'Drying Method': '100% Natural Solar Sun-Cured',
      'Quantity': '12 Uniform Disc Cakes',
      'Shelf Life': '24 Months in dry conditions',
      'Traceability': 'Direct Indigenous Gaushala & Dairy Cluster',
    },
  ),
  Product(
    id: 'mil-earth-starter-1kg',
    vendorId: 'vendor-milterra-earth',
    title: 'MILTERRA Earth Compost Starter',
    category: ProductCategory.feedNutrition,
    price: 249,
    unit: 'pack',
    brand: 'MILTERRA Earth',
    packSize: '1 kg',
    description:
        'Potent microbial bio-culture accelerator formulated to speed up composting of kitchen waste, dry leaves, and garden trimmings. Rapidly breaks down cellulose and suppresses unpleasant odors.',
    taxonomy: {
      'department_name': 'MILTERRA Earth',
      'category_name': 'MILTERRA Earth',
      'subcategory_name': 'Compost Starter',
      'brand_line': 'Living Soil • Farm Composts • Natural Carbon',
      'tagline': 'From Farm Waste to Living Soil',
      'status': 'Coming Soon',
      'concept': false,
      'is_earth': true,
      'department_id': 'milterra-earth',
      'category_id': 'milterra-earth',
      'usage_description':
          'Sprinkle 2-3 tablespoons across every 5kg layer of home compost bin waste. Water lightly to activate active microbial enzymes.',
      'traceability':
          'Beneficial Bacteria & Fungi Strains • Laboratory Certified Culture • Non-GMO',
    },
    media: [
      'assets/store/earth-vermicompost.jpg',
    ],
    inStock: false,
    availableQuantity: 0,
    minOrderQuantity: 1,
    specifications: {
      'Category': 'Bio-Inoculant & Compost Accelerator',
      'Microbial Count': '1 x 10^8 CFU/g active colonies',
      'Strains': 'Lactobacillus, Yeast, Actinomycetes & Cellulolytic Fungi',
      'Decomposition Speed': 'Accelerates breakdown by 3x - 4x',
      'Odor Neutralizer': 'Natural bio-enzyme suppression',
      'Traceability': 'Dairy AI Bio-Lab Formulated',
    },
  ),
  Product(
    id: 'mil-earth-soil-5kg',
    vendorId: 'vendor-milterra-earth',
    title: 'MILTERRA Earth Garden Soil Mix',
    category: ProductCategory.feedNutrition,
    price: 329,
    unit: 'bag',
    brand: 'MILTERRA Earth',
    packSize: '5 kg',
    description:
        'Ready-to-use premium potting soil mix combining red loamy soil, matured vermicompost, cocopeat fibers, and slow-release organic bio-fertilizers. Perfect porosity and aeration for vibrant indoor and outdoor plants.',
    taxonomy: {
      'department_name': 'MILTERRA Earth',
      'category_name': 'MILTERRA Earth',
      'subcategory_name': 'Garden Soil Mix',
      'brand_line': 'Living Soil • Farm Composts • Natural Carbon',
      'tagline': 'From Farm Waste to Living Soil',
      'status': 'Coming Soon',
      'concept': false,
      'is_earth': true,
      'department_id': 'milterra-earth',
      'category_id': 'milterra-earth',
      'usage_description':
          'Direct planting mix for potted ornamental plants, indoor ferns, flowering pots, and balcony vegetable planters. No additional soil mixing required.',
      'traceability':
          'pH Balanced (6.5 - 7.2) • Porous Aeration Matrix • Dairy Farm Bio-Humus',
    },
    media: [
      'assets/store/earth-soil-mix.jpg',
      'assets/store/earth-manure.jpg',
    ],
    inStock: false,
    availableQuantity: 0,
    minOrderQuantity: 1,
    specifications: {
      'Category': 'Ready-to-Use Potting Soil Mix',
      'Composition': 'Red Loam (40%) + Vermicompost (30%) + Cocopeat (20%) + Bio-Humus (10%)',
      'pH Range': '6.5 to 7.2 (Optimal Nutrient Uptake)',
      'Aeration & Drainage': 'High Porosity (Prevents Root Rot)',
      'Form': 'Pre-conditioned loose airy matrix',
      'Traceability': 'Dairy AI Partner Farm Compounded',
    },
  ),

  // ---- 3. Farmer Hub: Cattle Nutrition Solutions (Concepts) ----
  Product(
    id: 'mil-mineral-supp',
    vendorId: 'vendor-agri-nutrition',
    title: 'MILTERRA Mineral Supplement',
    category: ProductCategory.feedNutrition,
    price: 0,
    unit: 'bucket',
    brand: 'MILTERRA',
    packSize: '5 kg bucket',
    description:
        'Natural Nutrition for Healthy Livestock. Advanced mineral formulation enriched with amino-acid chelated trace minerals (Zinc, Copper, Manganese, Chromium, Cobalt) + Live Yeast Probiotics to strengthen immunity and optimize conception rates.',
    taxonomy: {
      'department_name': 'Farm Essentials',
      'category_name': 'Supplements',
      'subcategory_name': 'Supplements',
      'brand_line': 'Feeds • Supplements • Calcium STC • Health & Productivity',
      'tagline': 'Natural Nutrition for Healthy Livestock',
      'status': 'Concept Preview',
      'concept': true,
      'department_id': 'farm-essentials',
      'category_id': 'animal-nutrition'
    },
    media: [
      'assets/store/minera-360-jar.jpg',
      'assets/store/minera-360-vitamin.jpg',
      'assets/store/nutrition-lineup.jpg',
    ],
    inStock: false,
    availableQuantity: 0,
    minOrderQuantity: 1,
    specifications: {
      'Concept Status': 'Concept Preview (In Development)',
      'Brand Line': 'Feeds • Supplements • Calcium STC • Health & Productivity',
      'Formulation': 'Chelated Trace Minerals + Live Probiotic Yeast',
      'Target Animals': 'Milking Dairy Cows & Buffaloes',
      'Key Benefits': 'Natural Nutrition, Conception Rates & Hoof Strength',
      'Stage': 'Daily Herd Nutrition & Maintenance',
    },
  ),
  Product(
    id: 'feed-janam-42',
    vendorId: 'vendor-agri-nutrition',
    title: 'MILTERRA JANAM·42 Transition & Calving Nutrition Course',
    category: ProductCategory.feedNutrition,
    price: 0,
    unit: 'course pack',
    brand: 'MILTERRA',
    packSize: '42-day transition kit',
    description:
        'Stage-based 42-day transition nutrition course engineered for high-yielding dairy cattle (21 days pre-calving to 21 days post-calving). Formulated to balance negative DCAD, prevent metabolic disorders, and prime the rumen for peak lactation.',
    taxonomy: {
      'department_name': 'Farm Essentials',
      'category_name': 'Stage-Based Nutrition Courses',
      'subcategory_name': 'Stage-Based Nutrition Courses',
      'brand_line': 'Feeds • Supplements • Calcium STC • Health & Productivity',
      'tagline': 'Stage-Based Nutrition for Transition Cows',
      'status': 'Concept Preview',
      'concept': true,
      'department_id': 'farm-essentials',
      'category_id': 'animal-nutrition'
    },
    media: [
      'assets/store/feed-janam-42.jpg',
      'assets/store/nutrition-lineup.jpg',
    ],
    inStock: false,
    availableQuantity: 0,
    minOrderQuantity: 1,
    specifications: {
      'Concept Status': 'Concept Preview (In Development)',
      'Brand Line': 'Feeds • Supplements • Calcium STC • Health & Productivity',
      'Program': '42-Day Multi-Phase Feeding Protocol',
      'Phase 1 (-21 Days)': 'Anionic salts, liver tonics & pre-calving mineral balancers',
      'Phase 2 (+21 Days)': 'High-potency calcium drench, bypass fats & glucogenic precursors',
      'Validation Status': 'Field Trial & Farmer Feedback Phase',
    },
  ),
  Product(
    id: 'feed-pellet-50',
    vendorId: 'vendor-agri-nutrition',
    title: 'MILTERRA Bovine Gold Cattle Feed Pellets (20% Protein)',
    category: ProductCategory.feedNutrition,
    price: 0,
    unit: 'bag',
    brand: 'MILTERRA',
    packSize: '50 kg bag',
    description:
        'Scientifically balanced compound cattle feed formulated with 20% crude protein, bypass fat, and fortified minerals. Formulated to support daily milk production and maintain body condition score.',
    taxonomy: {
      'department_name': 'Farm Essentials',
      'category_name': 'Pashu Aahar / Cattle Feed',
      'subcategory_name': 'Pashu Aahar / Cattle Feed',
      'brand_line': 'Feeds • Supplements • Calcium STC • Health & Productivity',
      'tagline': 'Natural Nutrition for Healthy Livestock',
      'status': 'In Development',
      'concept': true,
      'department_id': 'farm-essentials',
      'category_id': 'animal-nutrition'
    },
    media: [
      'assets/store/feed-bovine-gold.jpg',
      'assets/store/calci-feed-combo.jpg',
    ],
    inStock: false,
    availableQuantity: 0,
    minOrderQuantity: 1,
    specifications: {
      'Concept Status': 'In Development (Formulation Preview)',
      'Brand Line': 'Feeds • Supplements • Calcium STC • Health & Productivity',
      'Crude Protein': 'Min 20%',
      'Crude Fat': 'Min 3.5%',
      'Crude Fibre': 'Max 10%',
      'Form': 'Steam-Conditioned Pellets',
    },
  ),
  Product(
    id: 'feed-calcium-5l',
    vendorId: 'vendor-agri-nutrition',
    title: 'MILTERRA Cal-Gold Liquid Calcium & Phosphorus Drench',
    category: ProductCategory.feedNutrition,
    price: 0,
    unit: 'jar',
    brand: 'MILTERRA',
    packSize: '5 litres',
    description:
        'High-potency bio-available liquid calcium and phosphorus drench fortified with Vitamin D3, B12, and bioactive herbs (Shatavari & Jivanti) to rapidly replenish calcium post-calving.',
    taxonomy: {
      'department_name': 'Farm Essentials',
      'category_name': 'Supplements',
      'subcategory_name': 'Supplements',
      'brand_line': 'Feeds • Supplements • Calcium STC • Health & Productivity',
      'tagline': 'Natural Nutrition for Healthy Livestock',
      'status': 'Concept Preview',
      'concept': true,
      'department_id': 'farm-essentials',
      'category_id': 'animal-nutrition'
    },
    media: [
      'assets/store/calci-feed-combo.jpg',
      'assets/store/nutrition-lineup.jpg',
    ],
    inStock: false,
    availableQuantity: 0,
    minOrderQuantity: 1,
    specifications: {
      'Concept Status': 'Concept Preview (In Development)',
      'Brand Line': 'Feeds • Supplements • Calcium STC • Health & Productivity',
      'Calcium': '3500 mg / 100ml',
      'Phosphorus': '1750 mg / 100ml',
      'Vitamin D3': '16,000 IU',
    },
  ),
  Product(
    id: 'feed-bypass-fat',
    vendorId: 'vendor-agri-nutrition',
    title: 'MILTERRA Lacto-Energy Rumen Bypass Fat Powder (84% Fat)',
    category: ProductCategory.feedNutrition,
    price: 0,
    unit: 'pack',
    brand: 'MILTERRA',
    packSize: '1 kg',
    description:
        'Fractionated palm fatty acid powder bypassing rumen fermentation for direct intestinal absorption. Prevents negative energy balance in early lactation.',
    taxonomy: {
      'department_name': 'Farm Essentials',
      'category_name': 'Supplements',
      'subcategory_name': 'Supplements',
      'brand_line': 'Feeds • Supplements • Calcium STC • Health & Productivity',
      'tagline': 'Natural Nutrition for Healthy Livestock',
      'status': 'Concept Preview',
      'concept': true,
      'department_id': 'farm-essentials',
      'category_id': 'animal-nutrition'
    },
    media: [
      'assets/store/feed-bypass-fat.jpg',
      'assets/store/nutrition-lineup.jpg',
    ],
    inStock: false,
    availableQuantity: 0,
    minOrderQuantity: 1,
    specifications: {
      'Concept Status': 'Concept Preview (In Development)',
      'Brand Line': 'Feeds • Supplements • Calcium STC • Health & Productivity',
      'Fat Content': '84% Fractionated',
      'Melting Point': '54°C',
    },
  ),
  Product(
    id: 'feed-calci-pro-1l',
    vendorId: 'vendor-agri-nutrition',
    title: 'MILTERRA CALCI-PRO Fast Ionic Calcium & Phosphorus Gel',
    category: ProductCategory.feedNutrition,
    price: 0,
    unit: 'bottle',
    brand: 'MILTERRA',
    packSize: '1 Litre',
    description:
        'Fast-acting ionic calcium and phosphorus formulation fortified with Vitamin D3. Formulated to prevent postpartum milk fever and support bone density.',
    taxonomy: {
      'department_name': 'Farm Essentials',
      'category_name': 'Supplements',
      'subcategory_name': 'Supplements',
      'brand_line': 'Feeds • Supplements • Calcium STC • Health & Productivity',
      'tagline': 'Natural Nutrition for Healthy Livestock',
      'status': 'Concept Preview',
      'concept': true,
      'department_id': 'farm-essentials',
      'category_id': 'animal-nutrition'
    },
    media: [
      'assets/store/calci-feed-combo.jpg',
    ],
    inStock: false,
    availableQuantity: 0,
    minOrderQuantity: 1,
    specifications: {
      'Concept Status': 'Concept Preview (In Development)',
      'Brand Line': 'Feeds • Supplements • Calcium STC • Health & Productivity',
      'Ionic Calcium': '6600 mg',
      'Phosphorus': '3400 mg',
      'Vitamin D3': '8,000 IU',
      'Indication': 'Parturition & Milk Fever Prevention'
    },
  ),
  Product(
    id: 'feed-minera-360-1kg',
    vendorId: 'vendor-agri-nutrition',
    title: 'MILTERRA MINERA-360 Micro-Chelated Minerals with Chromium & Live Yeast',
    category: ProductCategory.feedNutrition,
    price: 0,
    unit: 'pack',
    brand: 'MILTERRA',
    packSize: '1 kg',
    description:
        'Complete 360-degree organic chelated trace mineral premix with active Saccharomyces cerevisiae yeast culture. Enhances fertility, conception rate, and hoof strength.',
    taxonomy: {
      'department_name': 'Farm Essentials',
      'category_name': 'Supplements',
      'subcategory_name': 'Supplements',
      'brand_line': 'Feeds • Supplements • Calcium STC • Health & Productivity',
      'tagline': 'Natural Nutrition for Healthy Livestock',
      'status': 'Concept Preview',
      'concept': true,
      'department_id': 'farm-essentials',
      'category_id': 'animal-nutrition'
    },
    media: [
      'assets/store/minera-360-jar.jpg',
      'assets/store/minera-360-vitamin.jpg',
    ],
    inStock: false,
    availableQuantity: 0,
    minOrderQuantity: 1,
    specifications: {
      'Concept Status': 'Concept Preview (In Development)',
      'Brand Line': 'Feeds • Supplements • Calcium STC • Health & Productivity',
      'Chelated Zinc & Copper': 'Yes (Amino Acid Bound)',
      'Chromium': 'Reduces Heat Stress',
      'Live Yeast': '10 Billion CFU/g',
    },
  ),
  Product(
    id: 'feed-lacta-pro-5kg',
    vendorId: 'vendor-agri-nutrition',
    title: 'MILTERRA LACTA-PRO Herbal Galactagogue & Milk Yield Booster',
    category: ProductCategory.feedNutrition,
    price: 0,
    unit: 'bucket',
    brand: 'MILTERRA',
    packSize: '5 kg',
    description:
        'Time-tested Ayurvedic galactagogue formulated with Shatavari, Leptadenia reticulata (Jivanti), and fenugreek. Naturally stimulates mammary alveoli for peak sustained lactation.',
    taxonomy: {
      'department_name': 'Farm Essentials',
      'category_name': 'Supplements',
      'subcategory_name': 'Supplements',
      'brand_line': 'Feeds • Supplements • Calcium STC • Health & Productivity',
      'tagline': 'Natural Nutrition for Healthy Livestock',
      'status': 'Concept Preview',
      'concept': true,
      'department_id': 'farm-essentials',
      'category_id': 'animal-nutrition'
    },
    media: [
      'assets/store/nutrition-lineup.jpg',
    ],
    inStock: false,
    availableQuantity: 0,
    minOrderQuantity: 1,
    specifications: {
      'Concept Status': 'Concept Preview (In Development)',
      'Brand Line': 'Feeds • Supplements • Calcium STC • Health & Productivity',
      'Herbal Actives': 'Shatavari, Jivanti, Vidarikand',
      'Action': 'Prolactin receptor stimulation',
      'Form': 'Palatable granules',
    },
  ),
  Product(
    id: 'feed-rumen-pro-500g',
    vendorId: 'vendor-agri-nutrition',
    title: 'MILTERRA RUMEN-PRO Rumen Buffer & Acidosis Stabilizer',
    category: ProductCategory.feedNutrition,
    price: 0,
    unit: 'pack',
    brand: 'MILTERRA',
    packSize: '500 g',
    description:
        'Dual-action rumen buffer (Sodium bicarbonate + Magnesium oxide) combined with fungal prebiotic enzymes. Prevents subacute rumen acidosis (SARA) and restores healthy cud chewing.',
    taxonomy: {
      'department_name': 'Farm Essentials',
      'category_name': 'Supplements',
      'subcategory_name': 'Supplements',
      'brand_line': 'Feeds • Supplements • Calcium STC • Health & Productivity',
      'tagline': 'Natural Nutrition for Healthy Livestock',
      'status': 'Concept Preview',
      'concept': true,
      'department_id': 'farm-essentials',
      'category_id': 'animal-nutrition'
    },
    media: [
      'assets/store/nutrition-lineup.jpg',
    ],
    inStock: false,
    availableQuantity: 0,
    minOrderQuantity: 1,
    specifications: {
      'Concept Status': 'Concept Preview (In Development)',
      'Brand Line': 'Feeds • Supplements • Calcium STC • Health & Productivity',
      'Buffers': 'Sodium Bicarbonate + MgO',
      'Enzymes': 'Cellulase & Xylanase',
      'pH Target': 'Stabilizes 6.2 - 6.8',
    },
  ),
  Product(
    id: 'feed-heat-guard-1kg',
    vendorId: 'vendor-agri-nutrition',
    title: 'MILTERRA HEAT-GUARD Anti-Stress Electrolyte & Cellular Osmolyte',
    category: ProductCategory.feedNutrition,
    price: 0,
    unit: 'pack',
    brand: 'MILTERRA',
    packSize: '1 kg',
    description:
        'Advanced electrolyte and betaine osmolyte complex engineered to protect dairy cattle from thermal heat stress, panting, and seasonal milk depression.',
    taxonomy: {
      'department_name': 'Farm Essentials',
      'category_name': 'Supplements',
      'subcategory_name': 'Supplements',
      'brand_line': 'Feeds • Supplements • Calcium STC • Health & Productivity',
      'tagline': 'Natural Nutrition for Healthy Livestock',
      'status': 'Concept Preview',
      'concept': true,
      'department_id': 'farm-essentials',
      'category_id': 'animal-nutrition'
    },
    media: [
      'assets/store/nutrition-lineup.jpg',
    ],
    inStock: false,
    availableQuantity: 0,
    minOrderQuantity: 1,
    specifications: {
      'Concept Status': 'Concept Preview (In Development)',
      'Brand Line': 'Feeds • Supplements • Calcium STC • Health & Productivity',
      'Active Ingredients': 'Natural Betaine, Potassium, Sodium, Vitamin C',
      'Effect': 'Prevents drop in dry matter intake',
    },
  ),

  // ---- 3. Farm Machinery & Dairy Equipment ----
  Product(
    id: 'eq-milk-single',
    vendorId: 'vendor-farm-machinery',
    title: 'MILTERRA Eco-Milker Single Bucket Milking Machine (SS 304)',
    category: ProductCategory.equipment,
    price: 24999,
    unit: 'unit',
    brand: 'MILTERRA',
    packSize: '25 L Bucket',
    description:
        'Heavy-duty electric milking system with 0.75 HP oil-free vacuum pump, pneumatic pulsator (60/40 ratio), and food-grade SS 304 25L can. Milks 10-12 cows per hour with zero teat stress.',
    taxonomy: {
      'department_name': 'Farm Essentials',
      'category_name': 'Equipment',
      'department_id': 'farm-essentials',
      'category_id': 'equipment'
    },
    inStock: true,
    availableQuantity: 15,
    minOrderQuantity: 1,
    isRentable: true,
    rentalRatePerHour: 250,
    specifications: {
      'Motor': '0.75 HP Single Phase 220V',
      'Bucket': '25L Stainless Steel 304',
      'Milking Capacity': '10-12 animals/hr',
      'Pulsation Ratio': '60:40'
    },
  ),
  Product(
    id: 'eq-analyzer-dig',
    vendorId: 'vendor-farm-machinery',
    title: 'MILTERRA UltraScan Digital Ultrasonic Milk Fat & SNF Analyzer',
    category: ProductCategory.equipment,
    price: 32500,
    unit: 'unit',
    brand: 'MILTERRA',
    packSize: 'Complete Kit',
    description:
        'High-precision ultrasonic milk analyzer delivering rapid 30-second testing of Fat (0.01% - 25%), SNF (3% - 15%), Density, Protein, and Added Water percentage. RS232 & USB connectivity.',
    taxonomy: {
      'department_name': 'Farm Essentials',
      'category_name': 'Equipment',
      'department_id': 'farm-essentials',
      'category_id': 'equipment'
    },
    inStock: true,
    availableQuantity: 12,
    minOrderQuantity: 1,
    specifications: {
      'Measuring Speed': '30 Seconds/sample',
      'Fat Range': '0.01% to 25%',
      'SNF Range': '3% to 15%',
      'Power': '12V DC / 220V AC with battery backup'
    },
  ),
  Product(
    id: 'eq-chaff-2hp',
    vendorId: 'vendor-farm-machinery',
    title: 'MILTERRA AgroCut 2 HP Heavy-Duty Electric Chaff Cutter',
    category: ProductCategory.equipment,
    price: 18900,
    unit: 'unit',
    brand: 'MILTERRA',
    packSize: '2 HP Motor',
    description:
        'Motorized fodder cutter with dual hardened high-carbon steel blades. Handles green fodder, dry straw, sugarcane tops, and maize stalks up to 800 kg/hour.',
    taxonomy: {
      'department_name': 'Farm Essentials',
      'category_name': 'Equipment',
      'department_id': 'farm-essentials',
      'category_id': 'equipment'
    },
    inStock: true,
    availableQuantity: 10,
    minOrderQuantity: 1,
    isRentable: true,
    rentalRatePerHour: 200,
    specifications: {
      'Capacity': '600 - 800 kg/hr',
      'Motor Power': '2 HP Copper Motor',
      'Blades': 'High-Carbon Tool Steel',
      'Cut Length': '10mm - 25mm'
    },
  ),
  Product(
    id: 'eq-can-40l',
    vendorId: 'vendor-farm-machinery',
    title: 'MILTERRA Heavy-Gauge SS 304 Seamless Milk Can (40 Litres)',
    category: ProductCategory.equipment,
    price: 3200,
    unit: 'can',
    brand: 'MILTERRA',
    packSize: '40 Litre',
    description:
        'Jointless, seamless deep-drawn stainless steel 304 milk transport can with ergonomic handles and airtight rubber-gasket lock lid. Mirror-finish polish.',
    taxonomy: {
      'department_name': 'Farm Essentials',
      'category_name': 'Equipment',
      'department_id': 'farm-essentials',
      'category_id': 'equipment'
    },
    inStock: true,
    availableQuantity: 50,
    minOrderQuantity: 1,
    specifications: {
      'Material': 'SS 304 Food Grade',
      'Capacity': '40 Litres',
      'Lid': 'Mushroom seal locking lid',
      'Thickness': '1.2 mm heavy gauge'
    },
  ),
  Product(
    id: 'eq-mat-rubber',
    vendorId: 'vendor-farm-machinery',
    title: 'MILTERRA Orthopedic High-Grip Interlocking Cow Rubber Mat (25mm)',
    category: ProductCategory.equipment,
    price: 2450,
    unit: 'mat',
    brand: 'MILTERRA',
    packSize: '6 x 4 ft (25mm)',
    description:
        'Heavy-duty vulcanized natural rubber comfort mat for cow sheds. Bubble-top anti-slip surface with drainage grooves prevents foot rot, lameness, and udder infection.',
    taxonomy: {
      'department_name': 'Farm Essentials',
      'category_name': 'Equipment',
      'department_id': 'farm-essentials',
      'category_id': 'equipment'
    },
    inStock: true,
    availableQuantity: 70,
    minOrderQuantity: 1,
    specifications: {
      'Dimensions': '6 ft x 4 ft (1.8m x 1.2m)',
      'Thickness': '25 mm',
      'Material': 'Heavy-Duty Vulcanized Rubber',
      'Surface': 'Anti-skid textured'
    },
  ),
];

/// Seed list of authentic Milterra Product Families linking SKU pack variants
const List<ProductFamily> defaultMilterraProductFamilies = [
  ProductFamily(
    id: 'fam-ghee-gir',
    title: 'Milterra Pure A2 Gir Cow Bilona Ghee',
    brand: 'Milterra Pure',
    department: 'Dairy Foods',
    taxonomyNodeId: 'cat-desi-ghee',
    taxonomyPath: 'Dairy Foods / Desi Ghee',
    description:
        'Slow-simmered Vedic A2 cultured Gir cow bilona ghee from free-grazing grass-fed indigenous cows. Clarified over gentle firewood embers.',
    primaryImage: 'assets/store/cow-ghee.png',
    isOrganic: true,
    purityGrade: 'Grade A+ (99.4% Purity Verified)',
    fssaiLicense: '10019021004312',
    variants: [
      ProductVariant(
        id: 'ghee-gir-500ml',
        sku: 'MIL-GHEE-GIR-500',
        packSize: '500 ml',
        price: 780,
        compareAtPrice: 950,
        stockQuantity: 120,
        inStock: true,
        weightGrams: 460,
      ),
      ProductVariant(
        id: 'ghee-gir-1l',
        sku: 'MIL-GHEE-GIR-1000',
        packSize: '1 L',
        price: 1450,
        compareAtPrice: 1850,
        stockQuantity: 85,
        inStock: true,
        weightGrams: 915,
      ),
      ProductVariant(
        id: 'ghee-gir-5l',
        sku: 'MIL-GHEE-GIR-5000',
        packSize: '5 L',
        price: 6950,
        compareAtPrice: 8500,
        stockQuantity: 25,
        inStock: true,
        weightGrams: 4575,
      ),
    ],
  ),
  ProductFamily(
    id: 'fam-ghee-buffalo',
    title: 'Milterra Traditional Cultured Buffalo Bilona Ghee',
    brand: 'Milterra Pure',
    department: 'Dairy Foods',
    taxonomyNodeId: 'cat-desi-ghee',
    taxonomyPath: 'Dairy Foods / Desi Ghee',
    description:
        'Thick, rich granular white bilona ghee made from whole cultured Murrah buffalo milk. Unadulterated and lab certified.',
    primaryImage: 'assets/store/buffalo-ghee.png',
    isOrganic: true,
    purityGrade: 'Grade A+ (99.2% Purity Verified)',
    fssaiLicense: '10019021004312',
    variants: [
      ProductVariant(
        id: 'ghee-buff-500ml',
        sku: 'MIL-GHEE-BUF-500',
        packSize: '500 ml',
        price: 640,
        compareAtPrice: 790,
        stockQuantity: 150,
        inStock: true,
        weightGrams: 465,
      ),
      ProductVariant(
        id: 'ghee-buff-1l',
        sku: 'MIL-GHEE-BUF-1000',
        packSize: '1 L',
        price: 1200,
        compareAtPrice: 1480,
        stockQuantity: 100,
        inStock: true,
        weightGrams: 920,
      ),
      ProductVariant(
        id: 'ghee-buff-5l',
        sku: 'MIL-GHEE-BUF-5000',
        packSize: '5 L',
        price: 5600,
        compareAtPrice: 6800,
        stockQuantity: 30,
        inStock: true,
        weightGrams: 4600,
      ),
    ],
  ),
  ProductFamily(
    id: 'fam-paneer-artisan',
    title: 'Milterra Farm Kitchen Fresh Malai Paneer',
    brand: 'Milterra Pure',
    department: 'Dairy Foods',
    taxonomyNodeId: 'cat-paneer',
    taxonomyPath: 'Dairy Foods / Fresh Paneer',
    description:
        'Soft, spongy, protein-rich artisanal cottage cheese coagulated with natural lemon. No starch, preservatives, or chemical emulsifiers.',
    primaryImage: 'assets/store/paneer.png',
    isOrganic: true,
    purityGrade: 'Farm Fresh (18g Natural Protein)',
    fssaiLicense: '10019021004312',
    variants: [
      ProductVariant(
        id: 'paneer-200g',
        sku: 'MIL-PAN-200',
        packSize: '200 g',
        price: 110,
        compareAtPrice: 130,
        stockQuantity: 80,
        inStock: true,
        weightGrams: 200,
      ),
      ProductVariant(
        id: 'paneer-500g',
        sku: 'MIL-PAN-500',
        packSize: '500 g',
        price: 260,
        compareAtPrice: 310,
        stockQuantity: 95,
        inStock: true,
        weightGrams: 500,
      ),
      ProductVariant(
        id: 'paneer-1kg',
        sku: 'MIL-PAN-1000',
        packSize: '1 kg',
        price: 500,
        compareAtPrice: 590,
        stockQuantity: 40,
        inStock: true,
        weightGrams: 1000,
      ),
    ],
  ),
  ProductFamily(
    id: 'fam-calci-boost',
    title: 'MILTERRA CALCI-BOOST Ionic Calcium & Phosphorus Gel',
    brand: 'Milterra Agri',
    department: 'Animal Nutrition',
    taxonomyNodeId: 'cat-animal-nutrition',
    taxonomyPath: 'Farm Essentials / Animal Nutrition',
    description:
        'Fast-acting ionic calcium and phosphorus formulation fortified with Vitamin D3. Prevents postpartum milk fever and strengthens bone density.',
    primaryImage: 'assets/store/calci-feed-combo.jpg',
    media: [
      'assets/store/calci-feed-combo.jpg',
      'assets/store/nutrition-lineup.jpg',
    ],
    isOrganic: false,
    variants: [
      ProductVariant(
        id: 'feed-calci-boost-1l',
        sku: 'MIL-FEED-CAL-1L',
        packSize: '1 L',
        price: 340,
        compareAtPrice: 390,
        stockQuantity: 75,
        inStock: true,
        weightGrams: 1200,
      ),
      ProductVariant(
        id: 'feed-calci-boost-5l',
        sku: 'MIL-FEED-CAL-5L',
        packSize: '5 L',
        price: 1550,
        compareAtPrice: 1750,
        stockQuantity: 30,
        inStock: true,
        weightGrams: 6000,
      ),
    ],
  ),
  ProductFamily(
    id: 'fam-milking-machine',
    title: 'Milterra Single Bucket Portable Milking Machine',
    brand: 'Milterra Tech',
    department: 'Farm Machinery',
    taxonomyNodeId: 'cat-machinery',
    taxonomyPath: 'Farm Essentials / Equipment',
    description:
        'Oil-lubricated high-efficiency vacuum pump with stainless steel 304 25L bucket and silicone milking liners for gentle extraction.',
    primaryImage: null,
    isOrganic: false,
    variants: [
      ProductVariant(
        id: 'eq-milker-single',
        sku: 'MIL-EQ-MILK-1B',
        packSize: 'Single Bucket (25L)',
        price: 28500,
        compareAtPrice: 32000,
        stockQuantity: 15,
        inStock: true,
        weightGrams: 35000,
      ),
      ProductVariant(
        id: 'eq-milker-double',
        sku: 'MIL-EQ-MILK-2B',
        packSize: 'Double Bucket (2x25L)',
        price: 42000,
        compareAtPrice: 48000,
        stockQuantity: 8,
        inStock: true,
        weightGrams: 55000,
      ),
    ],
  ),
];

