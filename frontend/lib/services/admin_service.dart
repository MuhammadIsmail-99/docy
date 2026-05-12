import 'package:supabase_flutter/supabase_flutter.dart';

class AdminService {
  final _supabase = Supabase.instance.client;

  // Get pending doctors
  Future<List<Map<String, dynamic>>> getPendingDoctors() async {
    final response = await _supabase
        .from('doctors')
        .select('*, profiles(full_name)')
        .eq('verification_status', 'pending');
    return List<Map<String, dynamic>>.from(response);
  }

  // Update verification status
  Future<void> updateVerificationStatus(String doctorId, String status) async {
    await _supabase
        .from('doctors')
        .update({'verification_status': status})
        .eq('id', doctorId);
  }
}
