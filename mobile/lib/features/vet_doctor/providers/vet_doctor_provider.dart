import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/core/constants.dart';
import 'package:dairy_ai/features/vet_farmer/models/vet_farmer_models.dart';
import 'package:dairy_ai/features/vet_doctor/models/vet_doctor_models.dart';

// ---------------------------------------------------------------------------
// Dio provider for vet-doctor feature.
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
// Vet dashboard stats.
// ---------------------------------------------------------------------------
final vetDashboardProvider =
    FutureProvider.autoDispose<VetDashboardStats>((ref) async {
  final dio = ref.watch(_dioProvider);
  final response = await dio.get('/vet-profiles/me/dashboard');
  final body = response.data as Map<String, dynamic>;
  if (body['success'] == true) {
    return VetDashboardStats.fromJson(body['data'] as Map<String, dynamic>);
  }
  throw Exception(body['message'] ?? 'Failed to load dashboard');
});

// ---------------------------------------------------------------------------
// Pending consultation queue.
// ---------------------------------------------------------------------------
final vetQueueProvider =
    FutureProvider.autoDispose<List<ConsultationQueueItem>>((ref) async {
  final dio = ref.watch(_dioProvider);
  final response = await dio.get('/consultations',
      queryParameters: {'status': 'requested', 'role': 'vet'});
  final body = response.data as Map<String, dynamic>;
  if (body['success'] == true) {
    return (body['data'] as List<dynamic>)
        .map(
            (e) => ConsultationQueueItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
  throw Exception(body['message'] ?? 'Failed to load queue');
});

// ---------------------------------------------------------------------------
// Active (in-progress) consultations for the vet.
// ---------------------------------------------------------------------------
final activeConsultationsProvider =
    FutureProvider.autoDispose<List<ConsultationQueueItem>>((ref) async {
  final dio = ref.watch(_dioProvider);
  final response = await dio.get('/consultations',
      queryParameters: {'status': 'in_progress', 'role': 'vet'});
  final body = response.data as Map<String, dynamic>;
  if (body['success'] == true) {
    return (body['data'] as List<dynamic>)
        .map(
            (e) => ConsultationQueueItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
  throw Exception(body['message'] ?? 'Failed to load active consultations');
});

// ---------------------------------------------------------------------------
// Vet consultation state (for chat / consultation view).
// ---------------------------------------------------------------------------
class VetConsultationState {
  final bool isLoading;
  final ConsultationQueueItem? consultation;
  final List<ChatMessage> messages;
  final String? error;

  const VetConsultationState({
    this.isLoading = false,
    this.consultation,
    this.messages = const [],
    this.error,
  });

  VetConsultationState copyWith({
    bool? isLoading,
    ConsultationQueueItem? consultation,
    List<ChatMessage>? messages,
    String? error,
  }) =>
      VetConsultationState(
        isLoading: isLoading ?? this.isLoading,
        consultation: consultation ?? this.consultation,
        messages: messages ?? this.messages,
        error: error,
      );
}

class VetConsultationNotifier extends StateNotifier<VetConsultationState> {
  final Dio _dio;

  VetConsultationNotifier(this._dio) : super(const VetConsultationState());

  /// Load consultation details and messages.
  Future<void> loadConsultation(int consultationId) async {
    state = const VetConsultationState(isLoading: true);
    try {
      final response = await _dio.get('/consultations/$consultationId');
      final body = response.data as Map<String, dynamic>;
      if (body['success'] == true) {
        final consultation = ConsultationQueueItem.fromJson(
            body['data'] as Map<String, dynamic>);

        final msgResponse =
            await _dio.get('/consultations/$consultationId/messages');
        final msgBody = msgResponse.data as Map<String, dynamic>;
        List<ChatMessage> messages = [];
        if (msgBody['success'] == true) {
          messages = (msgBody['data'] as List<dynamic>)
              .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
              .toList();
        }

        state = VetConsultationState(
          consultation: consultation,
          messages: messages,
        );
      } else {
        state = VetConsultationState(
            error: body['message'] as String? ?? 'Failed to load');
      }
    } on DioException catch (e) {
      state = VetConsultationState(
        error: e.response?.data?['message'] as String? ?? 'Network error',
      );
    } catch (e) {
      state = VetConsultationState(error: e.toString());
    }
  }

  /// Send a message as the vet.
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
    } catch (_) {}
  }

  /// Refresh messages.
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
}

final vetConsultationProvider = StateNotifierProvider.autoDispose<
    VetConsultationNotifier, VetConsultationState>((ref) {
  return VetConsultationNotifier(ref.watch(_dioProvider));
});

// ---------------------------------------------------------------------------
// Action: Accept a consultation request.
// ---------------------------------------------------------------------------
Future<void> acceptConsultation(Ref ref, {required int consultationId}) async {
  final dio = ref.read(_dioProvider);
  final response = await dio.patch(
    '/consultations/$consultationId',
    data: {'status': 'accepted'},
  );
  final body = response.data as Map<String, dynamic>;
  if (body['success'] != true) {
    throw Exception(body['message'] ?? 'Failed to accept consultation');
  }
  ref.invalidate(vetQueueProvider);
  ref.invalidate(activeConsultationsProvider);
  ref.invalidate(vetDashboardProvider);
}

// ---------------------------------------------------------------------------
// Action: Start a consultation (move to in_progress).
// ---------------------------------------------------------------------------
Future<void> startConsultation(Ref ref, {required int consultationId}) async {
  final dio = ref.read(_dioProvider);
  final response = await dio.patch(
    '/consultations/$consultationId/start',
    data: {'started_at': DateTime.now().toIso8601String()},
  );
  final body = response.data as Map<String, dynamic>;
  if (body['success'] != true) {
    throw Exception(body['message'] ?? 'Failed to start consultation');
  }
  ref.invalidate(vetQueueProvider);
  ref.invalidate(activeConsultationsProvider);
  ref.invalidate(vetDashboardProvider);
}

// ---------------------------------------------------------------------------
// Action: End a consultation.
// ---------------------------------------------------------------------------
Future<void> endConsultation(
  Ref ref, {
  required int consultationId,
  String? vetDiagnosis,
}) async {
  final dio = ref.read(_dioProvider);
  final response = await dio.patch(
    '/consultations/$consultationId/end',
    data: {
      'ended_at': DateTime.now().toIso8601String(),
      if (vetDiagnosis != null) 'vet_diagnosis': vetDiagnosis,
    },
  );
  final body = response.data as Map<String, dynamic>;
  if (body['success'] != true) {
    throw Exception(body['message'] ?? 'Failed to end consultation');
  }
  ref.invalidate(vetQueueProvider);
  ref.invalidate(activeConsultationsProvider);
  ref.invalidate(vetDashboardProvider);
}

// ---------------------------------------------------------------------------
// Action: Submit a prescription.
// ---------------------------------------------------------------------------
Future<Prescription> submitPrescription(
  Ref ref, {
  required PrescriptionPayload payload,
}) async {
  final dio = ref.read(_dioProvider);
  final response = await dio.post('/prescriptions', data: payload.toJson());
  final body = response.data as Map<String, dynamic>;
  if (body['success'] != true) {
    throw Exception(body['message'] ?? 'Failed to submit prescription');
  }
  return Prescription.fromJson(body['data'] as Map<String, dynamic>);
}

// ---------------------------------------------------------------------------
// Action: Toggle vet availability.
// ---------------------------------------------------------------------------
Future<void> toggleVetAvailability(
  Ref ref, {
  required bool isAvailable,
}) async {
  final dio = ref.read(_dioProvider);
  final response = await dio.patch(
    '/vet-profiles/me',
    data: {'is_available': isAvailable},
  );
  final body = response.data as Map<String, dynamic>;
  if (body['success'] != true) {
    throw Exception(body['message'] ?? 'Failed to update availability');
  }
  ref.invalidate(vetDashboardProvider);
}
