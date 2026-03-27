import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/core/constants.dart';
import 'package:dairy_ai/features/health/models/health_models.dart';

// ---------------------------------------------------------------------------
// Dio provider — assumes a top-level dioProvider exists or we create one here
// for the health feature. In production this would come from a shared provider.
// ---------------------------------------------------------------------------
final _dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: AppConstants.baseUrl,
    connectTimeout: AppConstants.connectTimeout,
    receiveTimeout: AppConstants.receiveTimeout,
    headers: {'Content-Type': 'application/json'},
  ));
  return dio;
});

// ---------------------------------------------------------------------------
// Cattle list provider (lightweight list for dropdowns).
// ---------------------------------------------------------------------------
final cattleListProvider =
    FutureProvider.autoDispose<List<CattleRef>>((ref) async {
  final dio = ref.watch(_dioProvider);
  final response = await dio.get('/cattle');
  final body = response.data as Map<String, dynamic>;
  if (body['success'] == true) {
    final items = (body['data'] as List<dynamic>)
        .map((e) => CattleRef.fromJson(e as Map<String, dynamic>))
        .toList();
    return items;
  }
  throw Exception(body['message'] ?? 'Failed to load cattle');
});

// ---------------------------------------------------------------------------
// Health records — per cattle (pass cattleId as family param).
// ---------------------------------------------------------------------------
final healthRecordsProvider = FutureProvider.autoDispose
    .family<List<HealthRecord>, int?>((ref, cattleId) async {
  final dio = ref.watch(_dioProvider);
  final path = cattleId != null
      ? '/health-records?cattle_id=$cattleId'
      : '/health-records';
  final response = await dio.get(path);
  final body = response.data as Map<String, dynamic>;
  if (body['success'] == true) {
    return (body['data'] as List<dynamic>)
        .map((e) => HealthRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }
  throw Exception(body['message'] ?? 'Failed to load health records');
});

// ---------------------------------------------------------------------------
// Active health issues — records without a completed treatment.
// ---------------------------------------------------------------------------
final activeHealthIssuesProvider =
    FutureProvider.autoDispose<List<HealthRecord>>((ref) async {
  final dio = ref.watch(_dioProvider);
  final response =
      await dio.get('/health-records', queryParameters: {'active': true});
  final body = response.data as Map<String, dynamic>;
  if (body['success'] == true) {
    return (body['data'] as List<dynamic>)
        .map((e) => HealthRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }
  throw Exception(body['message'] ?? 'Failed to load active issues');
});

// ---------------------------------------------------------------------------
// Vaccinations provider.
// ---------------------------------------------------------------------------
final vaccinationsProvider = FutureProvider.autoDispose
    .family<List<Vaccination>, int?>((ref, cattleId) async {
  final dio = ref.watch(_dioProvider);
  final path = cattleId != null
      ? '/vaccinations?cattle_id=$cattleId'
      : '/vaccinations';
  final response = await dio.get(path);
  final body = response.data as Map<String, dynamic>;
  if (body['success'] == true) {
    return (body['data'] as List<dynamic>)
        .map((e) => Vaccination.fromJson(e as Map<String, dynamic>))
        .toList();
  }
  throw Exception(body['message'] ?? 'Failed to load vaccinations');
});

// ---------------------------------------------------------------------------
// Upcoming vaccinations (next 30 days + overdue).
// ---------------------------------------------------------------------------
final upcomingVaccinationsProvider =
    FutureProvider.autoDispose<List<Vaccination>>((ref) async {
  final dio = ref.watch(_dioProvider);
  final response = await dio.get('/vaccinations',
      queryParameters: {'upcoming': true});
  final body = response.data as Map<String, dynamic>;
  if (body['success'] == true) {
    return (body['data'] as List<dynamic>)
        .map((e) => Vaccination.fromJson(e as Map<String, dynamic>))
        .toList();
  }
  throw Exception(body['message'] ?? 'Failed to load upcoming vaccinations');
});

// ---------------------------------------------------------------------------
// Sensor alerts provider.
// ---------------------------------------------------------------------------
final sensorAlertsProvider =
    FutureProvider.autoDispose<List<SensorAlert>>((ref) async {
  final dio = ref.watch(_dioProvider);
  final response =
      await dio.get('/iot/sensor-data', queryParameters: {'alerts': true});
  final body = response.data as Map<String, dynamic>;
  if (body['success'] == true) {
    return (body['data'] as List<dynamic>)
        .map((e) => SensorAlert.fromJson(e as Map<String, dynamic>))
        .toList();
  }
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
  Ref ref, {
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
  Ref ref, {
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
