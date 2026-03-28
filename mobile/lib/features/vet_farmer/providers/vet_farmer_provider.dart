import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/core/constants.dart';
import 'package:dairy_ai/features/vet_farmer/models/vet_farmer_models.dart';
import 'package:dairy_ai/features/health/models/health_models.dart';

// ---------------------------------------------------------------------------
// Dio provider (shared within the vet-farmer feature).
// ---------------------------------------------------------------------------
final _dioProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(
    baseUrl: AppConstants.baseUrl,
    connectTimeout: AppConstants.connectTimeout,
    receiveTimeout: AppConstants.receiveTimeout,
    headers: {'Content-Type': 'application/json'},
  ));
});

// ---------------------------------------------------------------------------
// Vet search filters.
// ---------------------------------------------------------------------------
class VetSearchFilters {
  final String? specialization;
  final String? language;
  final String? query;
  final double? lat;
  final double? lng;
  final double maxDistanceKm;
  final double? minFee;
  final double? maxFee;
  final String sortBy; // 'distance', 'fee_low', 'fee_high', 'rating'

  const VetSearchFilters({
    this.specialization,
    this.language,
    this.query,
    this.lat,
    this.lng,
    this.maxDistanceKm = 50.0,
    this.minFee,
    this.maxFee,
    this.sortBy = 'distance',
  });

  bool get hasLocation => lat != null && lng != null;

  VetSearchFilters copyWith({
    String? specialization,
    String? language,
    String? query,
    double? lat,
    double? lng,
    double? maxDistanceKm,
    double? minFee,
    double? maxFee,
    String? sortBy,
    bool clearLocation = false,
    bool clearFeeRange = false,
  }) =>
      VetSearchFilters(
        specialization: specialization ?? this.specialization,
        language: language ?? this.language,
        query: query ?? this.query,
        lat: clearLocation ? null : (lat ?? this.lat),
        lng: clearLocation ? null : (lng ?? this.lng),
        maxDistanceKm: maxDistanceKm ?? this.maxDistanceKm,
        minFee: clearFeeRange ? null : (minFee ?? this.minFee),
        maxFee: clearFeeRange ? null : (maxFee ?? this.maxFee),
        sortBy: sortBy ?? this.sortBy,
      );

  Map<String, dynamic> toQueryParams() => {
        if (specialization != null && specialization!.isNotEmpty)
          'specialization': specialization,
        if (language != null && language!.isNotEmpty) 'language': language,
        if (query != null && query!.isNotEmpty) 'q': query,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (lat != null && lng != null) 'max_distance_km': maxDistanceKm,
        if (minFee != null) 'min_fee': minFee,
        if (maxFee != null) 'max_fee': maxFee,
        'sort_by': sortBy,
        'available': true,
      };
}

// ---------------------------------------------------------------------------
// Search filters state.
// ---------------------------------------------------------------------------
class VetSearchFiltersNotifier extends StateNotifier<VetSearchFilters> {
  VetSearchFiltersNotifier() : super(const VetSearchFilters());

  void setSpecialization(String? value) =>
      state = state.copyWith(specialization: value);

  void setLanguage(String? value) => state = state.copyWith(language: value);

  void setQuery(String? value) => state = state.copyWith(query: value);

  void setLocation(double lat, double lng) =>
      state = state.copyWith(lat: lat, lng: lng);

  void clearLocation() => state = state.copyWith(clearLocation: true);

  void setMaxDistance(double km) => state = state.copyWith(maxDistanceKm: km);

  void setFeeRange(double? min, double? max) =>
      state = state.copyWith(
        minFee: min,
        maxFee: max,
        clearFeeRange: min == null && max == null,
      );

  void setSortBy(String sort) => state = state.copyWith(sortBy: sort);

  void clear() => state = const VetSearchFilters();
}

final vetSearchFiltersProvider =
    StateNotifierProvider.autoDispose<VetSearchFiltersNotifier, VetSearchFilters>(
        (ref) {
  return VetSearchFiltersNotifier();
});

// ---------------------------------------------------------------------------
// Vet search results — re-fetches when filters change.
// ---------------------------------------------------------------------------
final vetSearchProvider =
    FutureProvider.autoDispose<List<VetProfile>>((ref) async {
  final dio = ref.watch(_dioProvider);
  final filters = ref.watch(vetSearchFiltersProvider);
  final response = await dio.get(
    '/vets/search',
    queryParameters: filters.toQueryParams(),
  );
  final body = response.data as Map<String, dynamic>;
  if (body['success'] == true) {
    return (body['data'] as List<dynamic>)
        .map((e) => VetProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }
  throw Exception(body['message'] ?? 'Failed to load vets');
});

// ---------------------------------------------------------------------------
// Cattle list for consultation request (lightweight).
// ---------------------------------------------------------------------------
final farmerCattleListProvider =
    FutureProvider.autoDispose<List<CattleRef>>((ref) async {
  final dio = ref.watch(_dioProvider);
  final response = await dio.get('/cattle');
  final body = response.data as Map<String, dynamic>;
  if (body['success'] == true) {
    return (body['data'] as List<dynamic>)
        .map((e) => CattleRef.fromJson(e as Map<String, dynamic>))
        .toList();
  }
  throw Exception(body['message'] ?? 'Failed to load cattle');
});

// ---------------------------------------------------------------------------
// Triage for consultation — runs before farmer confirms request.
// ---------------------------------------------------------------------------
class ConsultationTriageState {
  final bool isLoading;
  final TriageResult? result;
  final String? error;

  const ConsultationTriageState({
    this.isLoading = false,
    this.result,
    this.error,
  });
}

class ConsultationTriageNotifier
    extends StateNotifier<ConsultationTriageState> {
  final Dio _dio;

  ConsultationTriageNotifier(this._dio)
      : super(const ConsultationTriageState());

  Future<void> runTriage({
    required int cattleId,
    required List<String> symptoms,
  }) async {
    state = const ConsultationTriageState(isLoading: true);
    try {
      final response = await _dio.post('/triage', data: {
        'cattle_id': cattleId,
        'symptoms': symptoms,
      });
      final body = response.data as Map<String, dynamic>;
      if (body['success'] == true) {
        state = ConsultationTriageState(
          result: TriageResult.fromJson(body['data'] as Map<String, dynamic>),
        );
      } else {
        state = ConsultationTriageState(
            error: body['message'] as String? ?? 'Triage failed');
      }
    } on DioException catch (e) {
      state = ConsultationTriageState(
        error: e.response?.data?['message'] as String? ??
            'Network error during triage',
      );
    } catch (e) {
      state = ConsultationTriageState(error: e.toString());
    }
  }

  void clear() => state = const ConsultationTriageState();
}

final consultationTriageProvider = StateNotifierProvider.autoDispose<
    ConsultationTriageNotifier, ConsultationTriageState>((ref) {
  return ConsultationTriageNotifier(ref.watch(_dioProvider));
});

// ---------------------------------------------------------------------------
// Consultation state (active consultation for chat screen).
// ---------------------------------------------------------------------------
class ConsultationState {
  final bool isLoading;
  final Consultation? consultation;
  final List<ChatMessage> messages;
  final String? error;

  const ConsultationState({
    this.isLoading = false,
    this.consultation,
    this.messages = const [],
    this.error,
  });

  ConsultationState copyWith({
    bool? isLoading,
    Consultation? consultation,
    List<ChatMessage>? messages,
    String? error,
  }) =>
      ConsultationState(
        isLoading: isLoading ?? this.isLoading,
        consultation: consultation ?? this.consultation,
        messages: messages ?? this.messages,
        error: error,
      );
}

class ConsultationNotifier extends StateNotifier<ConsultationState> {
  final Dio _dio;

  ConsultationNotifier(this._dio) : super(const ConsultationState());

  /// Load a consultation by ID including messages.
  Future<void> loadConsultation(int consultationId) async {
    state = const ConsultationState(isLoading: true);
    try {
      final response = await _dio.get('/consultations/$consultationId');
      final body = response.data as Map<String, dynamic>;
      if (body['success'] == true) {
        final consultation =
            Consultation.fromJson(body['data'] as Map<String, dynamic>);

        // Load chat messages.
        final msgResponse =
            await _dio.get('/consultations/$consultationId/messages');
        final msgBody = msgResponse.data as Map<String, dynamic>;
        List<ChatMessage> messages = [];
        if (msgBody['success'] == true) {
          messages = (msgBody['data'] as List<dynamic>)
              .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
              .toList();
        }

        state = ConsultationState(
          consultation: consultation,
          messages: messages,
        );
      } else {
        state = ConsultationState(
            error: body['message'] as String? ?? 'Failed to load consultation');
      }
    } on DioException catch (e) {
      state = ConsultationState(
        error: e.response?.data?['message'] as String? ?? 'Network error',
      );
    } catch (e) {
      state = ConsultationState(error: e.toString());
    }
  }

  /// Send a chat message.
  Future<void> sendMessage(String text) async {
    if (state.consultation == null) return;
    try {
      final response = await _dio.post(
        '/consultations/${state.consultation!.id}/messages',
        data: {'message': text},
      );
      final body = response.data as Map<String, dynamic>;
      if (body['success'] == true) {
        final msg =
            ChatMessage.fromJson(body['data'] as Map<String, dynamic>);
        state = state.copyWith(messages: [...state.messages, msg]);
      }
    } catch (_) {
      // Silently fail — message will appear on refresh.
    }
  }

  /// Refresh messages (poll).
  Future<void> refreshMessages() async {
    if (state.consultation == null) return;
    try {
      final response = await _dio
          .get('/consultations/${state.consultation!.id}/messages');
      final body = response.data as Map<String, dynamic>;
      if (body['success'] == true) {
        final messages = (body['data'] as List<dynamic>)
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList();
        state = state.copyWith(messages: messages);
      }
    } catch (_) {}
  }

  /// Rate the consultation.
  Future<void> rateConsultation(double rating) async {
    if (state.consultation == null) return;
    try {
      await _dio.patch(
        '/consultations/${state.consultation!.id}',
        data: {'rating': rating},
      );
    } catch (_) {}
  }
}

final consultationProvider =
    StateNotifierProvider.autoDispose<ConsultationNotifier, ConsultationState>(
        (ref) {
  return ConsultationNotifier(ref.watch(_dioProvider));
});

// ---------------------------------------------------------------------------
// Farmer's consultation list.
// ---------------------------------------------------------------------------
final farmerConsultationsProvider =
    FutureProvider.autoDispose<List<Consultation>>((ref) async {
  final dio = ref.watch(_dioProvider);
  final response = await dio.get('/consultations');
  final body = response.data as Map<String, dynamic>;
  if (body['success'] == true) {
    return (body['data'] as List<dynamic>)
        .map((e) => Consultation.fromJson(e as Map<String, dynamic>))
        .toList();
  }
  throw Exception(body['message'] ?? 'Failed to load consultations');
});

// ---------------------------------------------------------------------------
// Action: request a new consultation.
// ---------------------------------------------------------------------------
Future<Consultation> requestConsultation(
  Ref ref, {
  required ConsultationRequest request,
}) async {
  final dio = ref.read(_dioProvider);
  final response = await dio.post('/consultations', data: request.toJson());
  final body = response.data as Map<String, dynamic>;
  if (body['success'] != true) {
    throw Exception(body['message'] ?? 'Failed to request consultation');
  }
  final consultation =
      Consultation.fromJson(body['data'] as Map<String, dynamic>);

  ref.invalidate(farmerConsultationsProvider);
  return consultation;
}
