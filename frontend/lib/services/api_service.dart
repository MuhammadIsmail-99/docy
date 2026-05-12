import 'package:dio/dio.dart';

class ApiService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'http://localhost:8000/api/v1',
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 3),
  ));

  Future<Response> embedDoctor(Map<String, dynamic> data) async {
    try {
      return await _dio.post('/ai/embed-doctor', data: data);
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> checkEmail(String email) async {
    try {
      return await _dio.post('/auth/check-email', data: {'email': email});
    } catch (e) {
      rethrow;
    }
  }
}
