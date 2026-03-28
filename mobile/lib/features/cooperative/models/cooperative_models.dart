/// Data models for the Cooperative feature.
///
/// Plain Dart classes with factory [fromJson] constructors and [toJson]
/// methods — no code generation required.

class CooperativeProfile {
  final String id;
  final String userId;
  final String name;
  final String registrationNumber;
  final String cooperativeType;
  final String? address;
  final String? district;
  final String? state;
  final String? pincode;
  final int totalMembers;
  final double totalMilkCollected;
  final double totalPayouts;

  const CooperativeProfile({
    required this.id,
    required this.userId,
    required this.name,
    required this.registrationNumber,
    required this.cooperativeType,
    this.address,
    this.district,
    this.state,
    this.pincode,
    this.totalMembers = 0,
    this.totalMilkCollected = 0.0,
    this.totalPayouts = 0.0,
  });

  factory CooperativeProfile.fromJson(Map<String, dynamic> json) {
    return CooperativeProfile(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      registrationNumber: json['registration_number'] as String,
      cooperativeType: json['cooperative_type'] as String,
      address: json['address'] as String?,
      district: json['district'] as String?,
      state: json['state'] as String?,
      pincode: json['pincode'] as String?,
      totalMembers: (json['total_members'] as num?)?.toInt() ?? 0,
      totalMilkCollected:
          (json['total_milk_collected'] as num?)?.toDouble() ?? 0.0,
      totalPayouts: (json['total_payouts'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'registration_number': registrationNumber,
      'cooperative_type': cooperativeType,
      'address': address,
      'district': district,
      'state': state,
      'pincode': pincode,
      'total_members': totalMembers,
      'total_milk_collected': totalMilkCollected,
      'total_payouts': totalPayouts,
    };
  }
}

class CooperativeDashboard {
  final int totalMembers;
  final double totalMilkCollected;
  final double totalPayouts;
  final int activeCenters;
  final double todayCollection;
  final double avgFatPercent;
  final List<CollectionCenter> recentCenters;

  const CooperativeDashboard({
    this.totalMembers = 0,
    this.totalMilkCollected = 0.0,
    this.totalPayouts = 0.0,
    this.activeCenters = 0,
    this.todayCollection = 0.0,
    this.avgFatPercent = 0.0,
    this.recentCenters = const [],
  });

  factory CooperativeDashboard.fromJson(Map<String, dynamic> json) {
    return CooperativeDashboard(
      totalMembers: (json['total_members'] as num?)?.toInt() ?? 0,
      totalMilkCollected:
          (json['total_milk_collected'] as num?)?.toDouble() ?? 0.0,
      totalPayouts: (json['total_payouts'] as num?)?.toDouble() ?? 0.0,
      activeCenters: (json['active_centers'] as num?)?.toInt() ?? 0,
      todayCollection:
          (json['today_collection'] as num?)?.toDouble() ?? 0.0,
      avgFatPercent: (json['avg_fat_percent'] as num?)?.toDouble() ?? 0.0,
      recentCenters: ((json['recent_centers'] as List<dynamic>?) ?? [])
          .map((e) => CollectionCenter.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CollectionCenter {
  final String id;
  final String name;
  final String village;
  final int memberCount;
  final double todayLitres;
  final bool isActive;

  const CollectionCenter({
    required this.id,
    required this.name,
    required this.village,
    this.memberCount = 0,
    this.todayLitres = 0.0,
    this.isActive = true,
  });

  factory CollectionCenter.fromJson(Map<String, dynamic> json) {
    return CollectionCenter(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      village: json['village'] as String? ?? '',
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
      todayLitres: (json['today_litres'] as num?)?.toDouble() ?? 0.0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

/// Available cooperative type options for dropdowns and display.
class CooperativeTypes {
  CooperativeTypes._();

  static const Map<String, String> options = {
    'milk_collection': 'Milk Collection',
    'dairy_processing': 'Dairy Processing',
    'multi_purpose': 'Multi-Purpose',
    'marketing': 'Marketing',
  };

  static String label(String key) => options[key] ?? key;
}
