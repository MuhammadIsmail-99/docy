import 'package:dio/dio.dart';
import '../core/config/app_config.dart';

class ApiService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.fastApiUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));

  // ── AI ──────────────────────────────────────────────
  Future<void> embedDoctor(Map<String, dynamic> data) async {
    await _dio.post('/ai/embed-doctor', data: data);
  }

  Future<List<dynamic>> searchDoctors({
    required String query,
    bool availableOnly = false,
    String? city,
  }) async {
    final response = await _dio.post('/ai/search-doctors', data: {
      'query': query,
      'available_only': availableOnly,
      if (city != null) 'city': city,
    });
    return response.data as List<dynamic>;
  }

  Future<List<dynamic>> suggestSpecialties(String query) async {
    final response = await _dio.post('/ai/suggest-specialties', data: {'query': query});
    return response.data as List<dynamic>;
  }

  // ── SLOTS ────────────────────────────────────────────
  Future<Map<String, dynamic>?> getEarliestSlot(String doctorId) async {
    try {
      final response = await _dio.get('/slots/earliest', queryParameters: {'doctor_id': doctorId});
      return response.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<List<dynamic>> getAvailableSlots(String doctorId, {int count = 3}) async {
    final response = await _dio.get('/slots/available', queryParameters: {
      'doctor_id': doctorId,
      'count': count,
    });
    return response.data as List<dynamic>;
  }

  // ── CHAT ─────────────────────────────────────────────
  Future<Map<String, dynamic>> aiRespond({
    required String conversationId,
    required String message,
    required String doctorId,
  }) async {
    final response = await _dio.post('/chat/ai-respond', data: {
      'conversation_id': conversationId,
      'message': message,
      'doctor_id': doctorId,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> generateSoap({
    required String conversationId,
    required String doctorId,
    required Map<String, dynamic> triageData,
  }) async {
    final response = await _dio.post('/chat/generate-soap', data: {
      'conversation_id': conversationId,
      'doctor_id': doctorId,
      'triage_data': triageData,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> appChatbot({
    required String message,
    required List<Map<String, String>> history,
  }) async {
    final response = await _dio.post('/chat/app-chatbot', data: {
      'message': message,
      'history': history,
    });
    return response.data as Map<String, dynamic>;
  }

  // ── EMAIL ────────────────────────────────────────────
  Future<void> sendConfirmationEmail(String appointmentId) async {
    try {
      await _dio.post('/email/confirm-appointment', data: {'appointment_id': appointmentId});
    } catch (_) {}
  }

  // ── AUTH ─────────────────────────────────────────────
  Future<bool> checkEmail(String email) async {
    try {
      final response = await _dio.post('/auth/check-email', data: {'email': email});
      return response.data['exists'] as bool;
    } catch (_) {
      return false;
    }
  }
}
