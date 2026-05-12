import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';

class ChatService {
  final _supabase = Supabase.instance.client;
  final _api = ApiService();

  Stream<List<Map<String, dynamic>>> messagesStream(String conversationId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at');
  }

  Future<String> getOrCreateConversation(String patientId, String doctorId) async {
    final existing = await _supabase
        .from('conversations')
        .select('id')
        .eq('patient_id', patientId)
        .eq('doctor_id', doctorId)
        .maybeSingle();

    if (existing != null) return existing['id'] as String;

    final result = await _supabase
        .from('conversations')
        .insert({
          'patient_id': patientId,
          'doctor_id': doctorId,
          'ai_active': true,
          'intake_complete': false,
        })
        .select('id')
        .single();

    return result['id'] as String;
  }

  Future<Map<String, dynamic>?> getConversation(String conversationId) async {
    final res = await _supabase
        .from('conversations')
        .select('*')
        .eq('id', conversationId)
        .single();
    return res;
  }

  Future<void> insertMessage(String conversationId, String content, String role) async {
    await _supabase.from('messages').insert({
      'conversation_id': conversationId,
      'sender_role': role,
      'content': content,
    });
  }

  Future<Map<String, dynamic>> sendAndRespond({
    required String conversationId,
    required String message,
    required String doctorId,
  }) async {
    await insertMessage(conversationId, message, 'patient');

    final result = await _api.aiRespond(
      conversationId: conversationId,
      message: message,
      doctorId: doctorId,
    );

    final response = result['response'] as String?;
    final isRedFlag = result['is_red_flag'] as bool? ?? false;
    final isComplete = result['intake_complete'] as bool? ?? false;

    if (response != null && response.isNotEmpty) {
      await insertMessage(conversationId, response, 'ai');
    }

    return {'is_red_flag': isRedFlag, 'intake_complete': isComplete};
  }

  Future<void> setAiActive(String conversationId, bool active) async {
    await _supabase
        .from('conversations')
        .update({'ai_active': active})
        .eq('id', conversationId);
  }

  Future<void> generateSoap({
    required String conversationId,
    required String doctorId,
    required Map<String, dynamic> triageData,
  }) async {
    await _api.generateSoap(
      conversationId: conversationId,
      doctorId: doctorId,
      triageData: triageData,
    );
  }
}
