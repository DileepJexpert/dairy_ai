import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dairy_ai/features/auth/providers/auth_provider.dart';

/// One collar anomaly (fever, high heart rate, activity drop...).
class CrisisAlert {
  final String alertType;
  final String message;
  final double? currentValue;
  final String createdAt;

  const CrisisAlert({
    required this.alertType,
    required this.message,
    this.currentValue,
    required this.createdAt,
  });

  factory CrisisAlert.fromJson(Map<String, dynamic> j) => CrisisAlert(
        alertType: '${j['alert_type'] ?? ''}',
        message: '${j['message'] ?? ''}',
        currentValue: (j['current_value'] as num?)?.toDouble(),
        createdAt: '${j['created_at'] ?? ''}',
      );
}

/// All active alerts for ONE of the signed-in farmer's own cattle.
class CattleCrisis {
  final String cattleId;
  final String tagId;
  final String cattleName;
  final String severity;
  final List<CrisisAlert> alerts;

  const CattleCrisis({
    required this.cattleId,
    required this.tagId,
    required this.cattleName,
    required this.severity,
    required this.alerts,
  });

  bool get isCritical => severity == 'CRITICAL';

  factory CattleCrisis.fromJson(Map<String, dynamic> j) => CattleCrisis(
        cattleId: '${j['cattle_id'] ?? ''}',
        tagId: '${j['tag_id'] ?? ''}',
        cattleName: '${j['cattle_name'] ?? j['tag_id'] ?? ''}',
        severity: '${j['severity'] ?? 'WARNING'}',
        alerts: ((j['alerts'] as List?) ?? const [])
            .map((e) => CrisisAlert.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class BreedingAlert {
  final String cattleId;
  final String tagId;
  final String cattleName;
  final String inseminatedOn;
  final int daysSinceAi;

  const BreedingAlert({
    required this.cattleId,
    required this.tagId,
    required this.cattleName,
    required this.inseminatedOn,
    required this.daysSinceAi,
  });

  factory BreedingAlert.fromJson(Map<String, dynamic> j) => BreedingAlert(
        cattleId: '${j['cattle_id'] ?? ''}',
        tagId: '${j['tag_id'] ?? ''}',
        cattleName: '${j['cattle_name'] ?? j['tag_id'] ?? ''}',
        inseminatedOn: '${j['inseminated_on'] ?? ''}',
        daysSinceAi: (j['days_since_ai'] as num?)?.toInt() ?? 0,
      );
}

class ActiveCrises {
  final List<CattleCrisis> crises;
  final List<BreedingAlert> breedingAlerts;

  const ActiveCrises({this.crises = const [], this.breedingAlerts = const []});
}

/// Real, per-farmer alerts from GET /farmers/me/active-crises.
/// Empty (never demo data) when the farmer has no cattle or no events.
final activeCrisesProvider = FutureProvider<ActiveCrises>((ref) async {
  final isAuthenticated = ref.watch(authProvider).maybeWhen(
        authenticated: (_) => true,
        orElse: () => false,
      );
  if (!isAuthenticated) return const ActiveCrises();

  try {
    final dio = ref.read(dioProvider);
    final response = await dio.get('/farmers/me/active-crises');
    final body = response.data as Map<String, dynamic>;
    final data = (body['data'] as Map?) ?? const {};
    return ActiveCrises(
      crises: ((data['crises'] as List?) ?? const [])
          .map((e) => CattleCrisis.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      breedingAlerts: ((data['breeding_alerts'] as List?) ?? const [])
          .map((e) => BreedingAlert.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  } catch (_) {
    return const ActiveCrises();
  }
});
