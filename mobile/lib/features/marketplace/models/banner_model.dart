/// Model for dynamic storefront banner cards pushed from backend.
class StorefrontBanner {
  final String id;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final String? iconName;
  final String actionType; // 'category' | 'product' | 'url' | 'division'
  final String actionValue;
  final String bgColor;
  final String textColor;
  final int displayOrder;
  final bool isActive;

  const StorefrontBanner({
    required this.id,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.iconName,
    required this.actionType,
    required this.actionValue,
    this.bgColor = '#173f35',
    this.textColor = '#ffffff',
    this.displayOrder = 0,
    this.isActive = true,
  });

  factory StorefrontBanner.fromJson(Map<String, dynamic> json) {
    return StorefrontBanner(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      imageUrl: json['image_url'] as String?,
      iconName: json['icon_name'] as String?,
      actionType: json['action_type'] as String? ?? 'category',
      actionValue: json['action_value'] as String? ?? '',
      bgColor: json['bg_color'] as String? ?? '#173f35',
      textColor: json['text_color'] as String? ?? '#ffffff',
      displayOrder: json['display_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'image_url': imageUrl,
        'icon_name': iconName,
        'action_type': actionType,
        'action_value': actionValue,
        'bg_color': bgColor,
        'text_color': textColor,
        'display_order': displayOrder,
        'is_active': isActive,
      };

  /// Fallback defaults when backend API has no banners or network is unavailable
  static const List<StorefrontBanner> defaultBanners = [
    StorefrontBanner(
      id: 'default-ghee',
      title: 'Vedic Bilona Ghee',
      subtitle: 'Cultured A2 Gir Cow & Buffalo',
      actionType: 'category',
      actionValue: 'Vedic Bilona Ghee',
      bgColor: '#173f35',
      iconName: 'local_fire_department',
      displayOrder: 1,
    ),
    StorefrontBanner(
      id: 'default-milk',
      title: 'Fresh Milk & Dairy',
      subtitle: 'Chilled Raw Milk & Paneer',
      actionType: 'category',
      actionValue: 'Fresh Milk & Dairy',
      bgColor: '#173f35',
      iconName: 'water_drop',
      displayOrder: 2,
    ),
    StorefrontBanner(
      id: 'default-oil',
      title: 'Kachi Ghani Sarso Oil',
      subtitle: 'Cold-Pressed Wood-Churned',
      actionType: 'category',
      actionValue: 'Cold-Pressed Sarso (Mustard) Oil',
      bgColor: '#173f35',
      iconName: 'opacity',
      displayOrder: 3,
    ),
    StorefrontBanner(
      id: 'default-puja',
      title: 'Sacred Puja Essentials',
      subtitle: 'Pure Cow Dung Diyas & Hawan',
      actionType: 'category',
      actionValue: 'Puja & Hawan Samagri',
      bgColor: '#5a4a2a',
      iconName: 'wb_sunny',
      displayOrder: 4,
    ),
    StorefrontBanner(
      id: 'default-dhoop',
      title: 'Natural Agarbatti & Dhoop',
      subtitle: '100% Charcoal-Free Herbal',
      actionType: 'category',
      actionValue: 'Natural Agarbatti & Dhoop',
      bgColor: '#5a4a2a',
      iconName: 'grass',
      displayOrder: 5,
    ),
    StorefrontBanner(
      id: 'default-soil',
      title: 'Vermicompost & Living Soil',
      subtitle: 'Bio-Organic Soil Nutrition',
      actionType: 'category',
      actionValue: 'Vermicompost & Living Soil',
      bgColor: '#5a4a2a',
      iconName: 'yard',
      displayOrder: 6,
    ),
  ];
}
