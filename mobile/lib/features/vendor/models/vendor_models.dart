/// Data models for the Vendor feature.
///
/// Plain Dart classes with factory [fromJson] constructors and [toJson]
/// methods — no code generation required.
library vendor_models;

class VendorProfile {
  final String id;
  final String userId;
  final String businessName;
  final String vendorType;
  final String? gstNumber;
  final String? licenseNumber;
  final String? bankName;
  final String? accountNumber;
  final String? ifscCode;
  final String? accountHolderName;
  final String? upiId;
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
  final double commissionRate;

  const VendorProfile({
    required this.id,
    required this.userId,
    required this.businessName,
    required this.vendorType,
    this.gstNumber,
    this.licenseNumber,
    this.bankName,
    this.accountNumber,
    this.ifscCode,
    this.accountHolderName,
    this.upiId,
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
    this.commissionRate = 5.0,
  });

  factory VendorProfile.fromJson(Map<String, dynamic> json) {
    return VendorProfile(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      businessName: json['business_name'] as String,
      vendorType: json['vendor_type'] as String,
      gstNumber: json['gst_number'] as String?,
      licenseNumber: json['license_number'] as String?,
      bankName: json['bank_name'] as String?,
      accountNumber: json['account_number'] as String?,
      ifscCode: json['ifsc_code'] as String?,
      accountHolderName: json['account_holder_name'] as String?,
      upiId: json['upi_id'] as String?,
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
      commissionRate: (json['commission_rate'] as num?)?.toDouble() ?? 5.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'business_name': businessName,
      'vendor_type': vendorType,
      'gst_number': gstNumber,
      'license_number': licenseNumber,
      'bank_name': bankName,
      'account_number': accountNumber,
      'ifsc_code': ifscCode,
      'account_holder_name': accountHolderName,
      'upi_id': upiId,
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
      'commission_rate': commissionRate,
    };
  }
}

class VendorLowStockItem {
  final String id;
  final String title;
  final int availableQuantity;
  final double price;
  final bool isOutOfStock;

  const VendorLowStockItem({
    required this.id,
    required this.title,
    required this.availableQuantity,
    required this.price,
    required this.isOutOfStock,
  });

  factory VendorLowStockItem.fromJson(Map<String, dynamic> json) {
    return VendorLowStockItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      availableQuantity: (json['available_quantity'] as num?)?.toInt() ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      isOutOfStock: json['is_out_of_stock'] as bool? ?? false,
    );
  }
}

class VendorPayoutItem {
  final String id;
  final double amount;
  final double grossAmount;
  final double commissionAmount;
  final String status;
  final String? paymentReference;
  final String? bankName;
  final String? accountNumber;
  final String? remarks;
  final String? processedAt;
  final String createdAt;

  const VendorPayoutItem({
    required this.id,
    required this.amount,
    this.grossAmount = 0.0,
    this.commissionAmount = 0.0,
    required this.status,
    this.paymentReference,
    this.bankName,
    this.accountNumber,
    this.remarks,
    this.processedAt,
    required this.createdAt,
  });

  factory VendorPayoutItem.fromJson(Map<String, dynamic> json) {
    return VendorPayoutItem(
      id: json['id'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      grossAmount: (json['gross_amount'] as num?)?.toDouble() ?? 0.0,
      commissionAmount: (json['commission_amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'pending',
      paymentReference: json['payment_reference'] as String?,
      bankName: json['bank_name'] as String?,
      accountNumber: json['account_number'] as String?,
      remarks: json['remarks'] as String?,
      processedAt: json['processed_at'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class VendorDashboard {
  final double totalRevenue;
  final int totalOrders;
  final double rating;
  final int pendingOrders;
  final int completedOrders;
  final List<VendorOrder> recentOrders;
  final double grossSales;
  final double commissionRate;
  final double commissionAmount;
  final double netPayable;
  final double totalSettled;
  final double pendingSettlement;
  final int lowStockCount;
  final List<VendorLowStockItem> lowStockItems;
  final List<VendorPayoutItem> recentPayouts;

  const VendorDashboard({
    this.totalRevenue = 0.0,
    this.totalOrders = 0,
    this.rating = 0.0,
    this.pendingOrders = 0,
    this.completedOrders = 0,
    this.recentOrders = const [],
    this.grossSales = 0.0,
    this.commissionRate = 5.0,
    this.commissionAmount = 0.0,
    this.netPayable = 0.0,
    this.totalSettled = 0.0,
    this.pendingSettlement = 0.0,
    this.lowStockCount = 0,
    this.lowStockItems = const [],
    this.recentPayouts = const [],
  });

  factory VendorDashboard.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] as Map<String, dynamic>?;
    final settlements = json['settlements'] as Map<String, dynamic>?;

    final lowStockRaw = json['low_stock_items'] as List<dynamic>?;
    final payoutsRaw = (settlements?['recent_payouts'] ?? json['recent_payouts']) as List<dynamic>?;

    return VendorDashboard(
      totalRevenue: (stats?['total_revenue'] ?? json['total_revenue'] as num?)?.toDouble() ?? 0.0,
      totalOrders: (stats?['total_orders'] ?? json['total_orders'] as num?)?.toInt() ?? 0,
      rating: (stats?['rating_avg'] ?? json['rating'] as num?)?.toDouble() ?? 0.0,
      pendingOrders: (json['pending_orders'] as num?)?.toInt() ?? 0,
      completedOrders: (json['completed_orders'] as num?)?.toInt() ?? 0,
      recentOrders: ((json['recent_orders'] as List<dynamic>?) ?? [])
          .map((e) => VendorOrder.fromJson(e as Map<String, dynamic>))
          .toList(),
      grossSales: (settlements?['gross_sales'] ?? json['gross_sales'] as num?)?.toDouble() ?? 0.0,
      commissionRate: (settlements?['commission_rate'] ?? json['commission_rate'] as num?)?.toDouble() ?? 5.0,
      commissionAmount: (settlements?['commission_amount'] ?? json['commission_amount'] as num?)?.toDouble() ?? 0.0,
      netPayable: (settlements?['net_payable'] ?? json['net_payable'] as num?)?.toDouble() ?? 0.0,
      totalSettled: (settlements?['total_settled'] ?? json['total_settled'] as num?)?.toDouble() ?? 0.0,
      pendingSettlement: (settlements?['pending_settlement'] ?? json['pending_settlement'] as num?)?.toDouble() ?? 0.0,
      lowStockCount: (json['low_stock_count'] as num?)?.toInt() ?? 0,
      lowStockItems: (lowStockRaw ?? [])
          .map((e) => VendorLowStockItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      recentPayouts: (payoutsRaw ?? [])
          .map((e) => VendorPayoutItem.fromJson(e as Map<String, dynamic>))
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
