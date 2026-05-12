import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/api_service.dart';

class AuthService {
  final _supabase = Supabase.instance.client;
  final _apiService = ApiService();

  // Check if email exists (using backend Bloom filter)
  Future<bool> checkEmailExists(String email, {bool isRegistration = false}) async {
    try {
      final response = await _apiService.checkEmail(email);
      return response.data['exists'] as bool;
    } catch (e) {
      // If the check fails (e.g. backend down), return a safe fallback:
      // For registration, assume it doesn't exist so they can try to sign up.
      // For login, assume it does exist so they can try to sign in.
      return !isRegistration;
    }
  }

  // Login
  Future<AuthResponse> signIn(String email, String password) async {
    // Optimization: Check bloom filter first
    final exists = await checkEmailExists(email);
    if (!exists) {
      throw Exception('User not found');
    }
    
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Register Patient
  Future<AuthResponse> signUpPatient({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    // Check if user already exists
    final exists = await checkEmailExists(email, isRegistration: true);
    if (exists) {
      throw Exception('Email already registered');
    }

    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName, 'phone': phone, 'role': 'patient'},
    );

    if (response.user != null) {
      await _supabase.from('profiles').insert({
        'id': response.user!.id,
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'role': 'patient',
      });
    }

    return response;
  }

  // Register Doctor
  Future<AuthResponse> signUpDoctor({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String specialization,
    required String city,
    required String consultationType,
    required int experience,
    required int fee,
    required String bio,
    required String pmdcNumber,
  }) async {
    // Check if user already exists
    final exists = await checkEmailExists(email, isRegistration: true);
    if (exists) {
      throw Exception('Email already registered');
    }

    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName, 'phone': phone, 'role': 'doctor'},
    );

    if (response.user != null) {
      // 1. Create Profile
      await _supabase.from('profiles').insert({
        'id': response.user!.id,
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'role': 'doctor',
      });

      // 2. Create Doctor entry
      await _supabase.from('doctors').insert({
        'id': response.user!.id,
        'specialization': specialization,
        'city': city,
        'consultation_type': consultationType,
        'experience_years': experience,
        'consultation_fee': fee,
        'bio': bio,
        'pmdc_number': pmdcNumber,
        'verification_status': 'pending',
      });
    }

    return response;
  }

  // Sign Out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // Current User
  User? get currentUser => _supabase.auth.currentUser;
}
