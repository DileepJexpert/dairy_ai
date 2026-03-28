/// Data models for the Vendor feature.
///
/// Plain Dart classes with factory [fromJson] constructors and [toJson]
/// methods — no code generation required.

class VendorProfile {
  final String id;
  final String userId;
  final String businessName;
  final String vendorType;
  final String? gstNumber;
  final String? address;
  final String? district;
  final String? state;
  final String? pincode;
  final double? lat;
  final double? lng;
  final String? phone;
  final List<dynamic> productsServices;
  final double rating;
  final int totalOrders;
  final double totalRevenue;

  const VendorProfile({
    required this.id,
    required this.userId,
    required this.businessName,
    required this.vendorType,
    this.gstNumber,
    this.address,
    this.district,
    this.state,
    this.pincode,
    this.lat,
    this.lng,
    this.phone,
    this.productsServices = const [],
    this.rating = 0.0,
    this.totalOrders = 0,
    this.totalRevenue = 0.0,
  });

  factory VendorProfile.fromJson(Map<String, dynamic> json) {
    return VendorProfile(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      businessName: json['business_name'] as String,
      vendorType: json['vendor_type'] as String,
      gstNumber: json['gst_number'] as String?,
      address: json['address'] as String?,
      district: json['district'] as String?,
      state: json['state'] as String?,
      pincode: json['pincode'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      phone: json['phone'] as String?,
      productsServices: (json['products_services'] as List<dynamic>?) ?? [],
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalOrders: (json['total_orders'] as num?)?.toInt() ?? 0,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'business_name': businessName,
      'vendor_type': vendorType,
      'gst_number': gstNumber,
      'address': address,
      'district': district,
      'state': state,
      'pincode': pincode,
      'lat': lat,
      'lng': lng,
      'phone': phone,
      'products_services': productsServices,
      'rating': rating,
      'total_orders': totalOrders,
      'total_revenue': totalRevenue,
    };
  }
}

class VendorDashboard {
  final double totalRevenue;
  final int totalOrders;
  final double rating;
  final int pendingOrders;
  final int completedOrders;
  final List<VendorOrder> recentOrders;

  const VendorDashboard({
    this.totalRevenue = 0.0,
    this.totalOrders = 0,
    this.rating = 0.0,
    this.pendingOrders = 0,
    this.completedOrders = 0,
    this.recentOrders = const [],
  });

  factory VendorDashboard.fromJson(Map<String, dynamic> json) {
    return VendorDashboard(
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
      totalOrders: (json['total_orders'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      pendingOrders: (json['pending_orders'] as num?)?.toInt() ?? 0,
      completedOrders: (json['completed_orders'] as num?)?.toInt() ?? 0,
      recentOrders: ((json['recent_orders'] as List<dynamic>?) ?? [])
          .map((e) => VendorOrder.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class VendorOrder {
  final String id;
  final String farmerName;
  final String description;
  final double amount;
  final String status;
  final String createdAt;

  const VendorOrder({
    required this.id,
    required this.farmerName,
    required this.description,
    required this.amount,
    required this.status,
    required this.createdAt,
  });

  factory VendorOrder.fromJson(Map<String, dynamic> json) {
    return VendorOrder(
      id: json['id'] as String,
      farmerName: json['farmer_name'] as String? ?? 'Unknown',
      description: json['description'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

/// Available vendor type options for dropdowns and display.
class VendorTypes {
  VendorTypes._();

  static const Map<String, String> options = {
    'milk_buyer': 'Milk Buyer',
    'feed_supplier': 'Feed Supplier',
    'medicine_supplier': 'Medicine Supplier',
    'equipment_supplier': 'Equipment Supplier',
    'ai_technician': 'AI Technician',
    'other': 'Other',
  };

  static String label(String key) => options[key] ?? key;
}
