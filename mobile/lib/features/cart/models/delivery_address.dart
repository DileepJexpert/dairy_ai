class DeliveryAddress {
  const DeliveryAddress({
    required this.id,
    required this.recipientName,
    required this.phone,
    required this.addressLine1,
    required this.villageOrCity,
    required this.district,
    required this.state,
    required this.postalCode,
    required this.isDefault,
    this.addressLine2,
    this.landmark,
  });

  final String id,
      recipientName,
      phone,
      addressLine1,
      villageOrCity,
      district,
      state,
      postalCode;
  final String? addressLine2, landmark;
  final bool isDefault;

  factory DeliveryAddress.fromJson(Map<String, dynamic> json) =>
      DeliveryAddress(
        id: json['id'].toString(),
        recipientName: json['recipient_name'].toString(),
        phone: json['phone'].toString(),
        addressLine1: json['address_line1'].toString(),
        addressLine2: json['address_line2']?.toString(),
        landmark: json['landmark']?.toString(),
        villageOrCity: json['village_or_city'].toString(),
        district: json['district'].toString(),
        state: json['state'].toString(),
        postalCode: json['postal_code'].toString(),
        isDefault: json['is_default'] as bool? ?? false,
      );

  String get summary =>
      '$addressLine1, $villageOrCity, $district - $postalCode';
}
