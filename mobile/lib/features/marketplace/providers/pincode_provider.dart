import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';

class PincodeDeliveryInfo {
  final bool isServiceable;
  final String pincode;
  final String? city;
  final String? state;
  final int? deliveryDaysMin;
  final int? deliveryDaysMax;
  final String? expectedDeliveryText;
  final bool expressAvailable;
  final String? deliveryFee;
  final String? message;

  const PincodeDeliveryInfo({
    required this.isServiceable,
    required this.pincode,
    this.city,
    this.state,
    this.deliveryDaysMin,
    this.deliveryDaysMax,
    this.expectedDeliveryText,
    this.expressAvailable = false,
    this.deliveryFee,
    this.message,
  });

  factory PincodeDeliveryInfo.fromJson(Map<String, dynamic> json) {
    return PincodeDeliveryInfo(
      isServiceable: json['is_serviceable'] == true,
      pincode: json['pincode']?.toString() ?? '',
      city: json['city'] as String?,
      state: json['state'] as String?,
      deliveryDaysMin: json['delivery_days_min'] as int?,
      deliveryDaysMax: json['delivery_days_max'] as int?,
      expectedDeliveryText: json['expected_delivery_text'] as String?,
      expressAvailable: json['express_available'] == true,
      deliveryFee: json['delivery_fee']?.toString(),
      message: json['message'] as String?,
    );
  }

  String get locationLabel {
    if (city != null && city!.isNotEmpty) {
      return '$city $pincode';
    }
    return pincode;
  }
}

/// Currently selected 6-digit delivery PIN code across the application
final currentPincodeProvider = StateProvider<String>((ref) => '110001');

/// Live delivery serviceability & ETA provider querying backend master table
final deliveryCheckProvider =
    FutureProvider.family<PincodeDeliveryInfo, String>((ref, pin) async {
  final clean = pin.trim();
  if (!RegExp(r'^\d{6}$').hasMatch(clean)) {
    return PincodeDeliveryInfo(
      isServiceable: false,
      pincode: clean,
      message: 'Please enter a valid 6-digit PIN code.',
    );
  }

  try {
    final dio = ref.watch(dioProvider);
    final res = await dio
        .get('/marketplace/pincode/check', queryParameters: {'pincode': clean});

    if (res.statusCode == 200 && res.data is Map) {
      return PincodeDeliveryInfo.fromJson(
          Map<String, dynamic>.from(res.data as Map));
    }
  } catch (_) {}

  // Delivery availability must come from the backend, never a guessed PIN prefix.
  return PincodeDeliveryInfo(
    isServiceable: false,
    pincode: clean,
    message: 'Delivery availability could not be verified. Please try again.',
  );
});
