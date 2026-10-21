import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/core/api_client.dart';
import 'package:dairy_ai/features/health/models/livestock_disease_model.dart';
import 'package:dairy_ai/features/health/models/health_models.dart';

// ---------------------------------------------------------------------------
// Dio provider — assumes a top-level dioProvider exists or we create one here
// for the health feature. In production this would come from a shared provider.
// ---------------------------------------------------------------------------
final _dioProvider = Provider<Dio>((ref) {
  return ref.watch(apiClientProvider);
});

// ---------------------------------------------------------------------------
// Cattle list provider (lightweight list for dropdowns).
// ---------------------------------------------------------------------------
final cattleListProvider =
    FutureProvider.autoDispose<List<CattleRef>>((ref) async {
  try {
    final dio = ref.watch(_dioProvider);
    final response = await dio.get('/cattle');
    final body = response.data as Map<String, dynamic>;
    if (body['success'] == true) {
      final items = (body['data'] as List<dynamic>)
          .map((e) => CattleRef.fromJson(e as Map<String, dynamic>))
          .toList();
      if (items.isNotEmpty) return items;
    }
  } catch (_) {
    // Return robust offline / unauthenticated demo fallback
  }
  return const [
    CattleRef(id: 1, name: 'Ganga (गाय)', tagId: 'MIL-0842'),
    CattleRef(id: 2, name: 'Gauri (गाय)', tagId: 'MIL-0911'),
    CattleRef(id: 3, name: 'Murrah (भैंस)', tagId: 'MIL-1024'),
    CattleRef(id: 4, name: 'Radha (गाय)', tagId: 'MIL-0765'),
  ];
});

// ---------------------------------------------------------------------------
// Demo data fallbacks for offline and unauthenticated states.
// ---------------------------------------------------------------------------
final _demoHealthRecords = [
  HealthRecord(
    id: 101,
    cattleId: 1,
    cattleName: 'Ganga (गाय)',
    cattleTagId: 'MIL-0842',
    date: DateTime.now().subtract(const Duration(days: 3)),
    type: HealthRecordType.checkup,
    symptoms: const ['Routine inspection', 'Normal rumination'],
    diagnosis: 'Healthy and active',
    treatment: 'Multivitamin supplement administered',
  ),
  HealthRecord(
    id: 102,
    cattleId: 2,
    cattleName: 'Gauri (गाय)',
    cattleTagId: 'MIL-0911',
    date: DateTime.now().subtract(const Duration(days: 14)),
    type: HealthRecordType.treatment,
    symptoms: const ['Mild fever', 'Reduced feed intake'],
    diagnosis: 'Mild indigestion / Bloat',
    treatment: 'Digestive tonic + carminative mixture given. Fully recovered.',
  ),
  HealthRecord(
    id: 103,
    cattleId: 3,
    cattleName: 'Murrah (भैंस)',
    cattleTagId: 'MIL-1024',
    date: DateTime.now().subtract(const Duration(days: 28)),
    type: HealthRecordType.checkup,
    symptoms: const ['Post-calving recovery check'],
    diagnosis: 'Normal uterine involution',
    treatment: 'Calcium & mineral bolus prescribed',
  ),
];

final _demoVaccinations = [
  Vaccination(
    id: 201,
    cattleId: 1,
    cattleName: 'Ganga (गाय)',
    cattleTagId: 'MIL-0842',
    vaccineName: 'FMD (खुरपका-मुँहपका)',
    dateGiven: DateTime.now().subtract(const Duration(days: 90)),
    nextDue: DateTime.now().add(const Duration(days: 20)),
    administeredBy: 'Dr. Rajesh Sharma',
  ),
  Vaccination(
    id: 202,
    cattleId: 2,
    cattleName: 'Gauri (गाय)',
    cattleTagId: 'MIL-0911',
    vaccineName: 'HS & BQ Combined (गलघोंटू-लंगड़ा)',
    dateGiven: DateTime.now().subtract(const Duration(days: 120)),
    nextDue: DateTime.now().add(const Duration(days: 15)),
    administeredBy: 'Government Vet Hospital',
  ),
  Vaccination(
    id: 203,
    cattleId: 3,
    cattleName: 'Murrah (भैंस)',
    cattleTagId: 'MIL-1024',
    vaccineName: 'Brucellosis (ब्रूसीलोसिस)',
    dateGiven: DateTime.now().subtract(const Duration(days: 180)),
    nextDue: DateTime.now().add(const Duration(days: 45)),
    administeredBy: 'Dr. Sunita Patil',
  ),
];

// ---------------------------------------------------------------------------
// Health records — per cattle (pass cattleId as family param).
// ---------------------------------------------------------------------------
final healthRecordsProvider = FutureProvider.autoDispose
    .family<List<HealthRecord>, int?>((ref, cattleId) async {
  try {
    final dio = ref.watch(_dioProvider);
    final path = cattleId != null
        ? '/health-records?cattle_id=$cattleId'
        : '/health-records';
    final response = await dio.get(path);
    final body = response.data as Map<String, dynamic>;
    if (body['success'] == true) {
      final items = (body['data'] as List<dynamic>)
          .map((e) => HealthRecord.fromJson(e as Map<String, dynamic>))
          .toList();
      if (items.isNotEmpty) return items;
    }
  } catch (_) {}
  if (cattleId != null) {
    return _demoHealthRecords.where((r) => r.cattleId == cattleId).toList();
  }
  return _demoHealthRecords;
});

// ---------------------------------------------------------------------------
// Active health issues — records without a completed treatment.
// ---------------------------------------------------------------------------
final activeHealthIssuesProvider =
    FutureProvider.autoDispose<List<HealthRecord>>((ref) async {
  try {
    final dio = ref.watch(_dioProvider);
    final response =
        await dio.get('/health-records', queryParameters: {'active': true});
    final body = response.data as Map<String, dynamic>;
    if (body['success'] == true) {
      return (body['data'] as List<dynamic>)
          .map((e) => HealthRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  } catch (_) {}
  return <HealthRecord>[];
});

// ---------------------------------------------------------------------------
// Vaccinations provider.
// ---------------------------------------------------------------------------
final vaccinationsProvider = FutureProvider.autoDispose
    .family<List<Vaccination>, int?>((ref, cattleId) async {
  try {
    final dio = ref.watch(_dioProvider);
    final path = cattleId != null
        ? '/vaccinations?cattle_id=$cattleId'
        : '/vaccinations';
    final response = await dio.get(path);
    final body = response.data as Map<String, dynamic>;
    if (body['success'] == true) {
      final items = (body['data'] as List<dynamic>)
          .map((e) => Vaccination.fromJson(e as Map<String, dynamic>))
          .toList();
      if (items.isNotEmpty) return items;
    }
  } catch (_) {}
  if (cattleId != null) {
    return _demoVaccinations.where((v) => v.cattleId == cattleId).toList();
  }
  return _demoVaccinations;
});

// ---------------------------------------------------------------------------
// Upcoming vaccinations (next 30 days + overdue).
// ---------------------------------------------------------------------------
final upcomingVaccinationsProvider =
    FutureProvider.autoDispose<List<Vaccination>>((ref) async {
  try {
    final dio = ref.watch(_dioProvider);
    final response = await dio.get('/vaccinations',
        queryParameters: {'upcoming': true});
    final body = response.data as Map<String, dynamic>;
    if (body['success'] == true) {
      final items = (body['data'] as List<dynamic>)
          .map((e) => Vaccination.fromJson(e as Map<String, dynamic>))
          .toList();
      if (items.isNotEmpty) return items;
    }
  } catch (_) {}
  return _demoVaccinations.where((v) => v.isUpcoming || v.isOverdue).toList();
});

// ---------------------------------------------------------------------------
// Sensor alerts provider.
// ---------------------------------------------------------------------------
final sensorAlertsProvider =
    FutureProvider.autoDispose<List<SensorAlert>>((ref) async {
  try {
    final dio = ref.watch(_dioProvider);
    final response =
        await dio.get('/iot/sensor-data', queryParameters: {'alerts': true});
    final body = response.data as Map<String, dynamic>;
    if (body['success'] == true) {
      return (body['data'] as List<dynamic>)
          .map((e) => SensorAlert.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  } catch (_) {}
  return <SensorAlert>[];
});

// ---------------------------------------------------------------------------
// Triage result — StateNotifier so we can trigger triage and hold the result.
// ---------------------------------------------------------------------------
class TriageState {
  final bool isLoading;
  final TriageResult? result;
  final String? error;

  const TriageState({this.isLoading = false, this.result, this.error});

  TriageState copyWith({
    bool? isLoading,
    TriageResult? result,
    String? error,
  }) =>
      TriageState(
        isLoading: isLoading ?? this.isLoading,
        result: result ?? this.result,
        error: error,
      );
}

class TriageNotifier extends StateNotifier<TriageState> {
  final Dio _dio;

  TriageNotifier(this._dio) : super(const TriageState());

  Future<void> runTriage({
    required int cattleId,
    required List<String> symptoms,
  }) async {
    state = const TriageState(isLoading: true);
    try {
      final response = await _dio.post('/triage', data: {
        'cattle_id': cattleId,
        'symptoms': symptoms,
      });
      final body = response.data as Map<String, dynamic>;
      if (body['success'] == true) {
        state = TriageState(
          result: TriageResult.fromJson(body['data'] as Map<String, dynamic>),
        );
      } else {
        state = TriageState(error: body['message'] as String? ?? 'Triage failed');
      }
    } on DioException catch (e) {
      state = TriageState(
          error: e.response?.data?['message'] as String? ??
              'Network error during triage');
    } catch (e) {
      state = TriageState(error: e.toString());
    }
  }

  void clear() => state = const TriageState();
}

final triageProvider =
    StateNotifierProvider.autoDispose<TriageNotifier, TriageState>((ref) {
  return TriageNotifier(ref.watch(_dioProvider));
});

// ---------------------------------------------------------------------------
// Action: add a health record and optionally trigger triage.
// ---------------------------------------------------------------------------
Future<HealthRecord> addHealthRecord(
  WidgetRef ref, {
  required int cattleId,
  required HealthRecordType type,
  required List<String> symptoms,
  String? diagnosis,
  String? treatment,
  String? photoUrl,
  bool triggerTriage = true,
}) async {
  final dio = ref.read(_dioProvider);
  final payload = {
    'cattle_id': cattleId,
    'date': DateTime.now().toIso8601String(),
    'type': type.name,
    'symptoms': symptoms,
    if (diagnosis != null) 'diagnosis': diagnosis,
    if (treatment != null) 'treatment': treatment,
    if (photoUrl != null) 'photo_url': photoUrl,
  };

  final response = await dio.post('/health-records', data: payload);
  final body = response.data as Map<String, dynamic>;
  if (body['success'] != true) {
    throw Exception(body['message'] ?? 'Failed to add health record');
  }

  final record =
      HealthRecord.fromJson(body['data'] as Map<String, dynamic>);

  // Trigger AI triage in background if symptoms are present.
  if (triggerTriage && symptoms.isNotEmpty) {
    ref
        .read(triageProvider.notifier)
        .runTriage(cattleId: cattleId, symptoms: symptoms);
  }

  // Invalidate caches.
  ref.invalidate(healthRecordsProvider);
  ref.invalidate(activeHealthIssuesProvider);

  return record;
}

// ---------------------------------------------------------------------------
// Action: add a vaccination.
// ---------------------------------------------------------------------------
Future<Vaccination> addVaccination(
  WidgetRef ref, {
  required int cattleId,
  required String vaccineName,
  required DateTime dateGiven,
  DateTime? nextDue,
  String? administeredBy,
}) async {
  final dio = ref.read(_dioProvider);
  final payload = {
    'cattle_id': cattleId,
    'vaccine_name': vaccineName,
    'date_given': dateGiven.toIso8601String(),
    if (nextDue != null) 'next_due': nextDue.toIso8601String(),
    if (administeredBy != null) 'administered_by': administeredBy,
  };

  final response = await dio.post('/vaccinations', data: payload);
  final body = response.data as Map<String, dynamic>;
  if (body['success'] != true) {
    throw Exception(body['message'] ?? 'Failed to add vaccination');
  }

  final vaccination =
      Vaccination.fromJson(body['data'] as Map<String, dynamic>);

  // Invalidate caches.
  ref.invalidate(vaccinationsProvider);
  ref.invalidate(upcomingVaccinationsProvider);

  return vaccination;
}

// ---------------------------------------------------------------------------
// Livestock Disease Directory Provider
// ---------------------------------------------------------------------------
final livestockDiseasesProvider =
    FutureProvider.autoDispose<List<LivestockDisease>>((ref) async {
  try {
    final dio = ref.watch(_dioProvider);
    final response = await dio.get('/health/diseases');
    final body = response.data as Map<String, dynamic>;
    if (body['success'] == true && body['data'] is List) {
      final items = (body['data'] as List<dynamic>)
          .map((e) => LivestockDisease.fromJson(e as Map<String, dynamic>))
          .toList();
      if (items.isNotEmpty) return items;
    }
  } catch (_) {
    // Offline or network error - gracefully fall back to local encyclopedia
  }
  return fallbackLivestockDiseases;
});
