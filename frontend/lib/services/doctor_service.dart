import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/doctor_model.dart';
import '../models/availability_model.dart';

class DoctorService {
  final _supabase = Supabase.instance.client;

  // Get doctor details
  Future<DoctorModel?> getDoctorProfile(String userId) async {
    final response = await _supabase
        .from('doctors')
        .select()
        .eq('id', userId)
        .single();
    return DoctorModel.fromJson(response);
  }

  // Update doctor profile
  Future<void> updateDoctorProfile(String userId, Map<String, dynamic> data) async {
    await _supabase.from('doctors').update(data).eq('id', userId);
  }

  // Get weekly availability
  Future<List<AvailabilityModel>> getAvailability(String userId) async {
    final response = await _supabase
        .from('weekly_availability')
        .select()
        .eq('doctor_id', userId);
    return (response as List).map((json) => AvailabilityModel.fromJson(json)).toList();
  }

  // Update availability
  Future<void> updateAvailability(String userId, List<AvailabilityModel> availability) async {
    // Delete existing
    await _supabase.from('weekly_availability').delete().eq('doctor_id', userId);
    
    // Insert new
    if (availability.isNotEmpty) {
      await _supabase.from('weekly_availability').insert(
        availability.map((a) => a.toJson()).toList()
      );
    }
  }

  // Toggle availability status
  Future<void> toggleAvailability(String userId, bool isAvailable) async {
    await _supabase.from('doctors').update({'is_available': isAvailable}).eq('id', userId);
  }
}
