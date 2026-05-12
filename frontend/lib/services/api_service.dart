import 'package:dio/dio.dart';

class ApiService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'http://localhost:8000/api/v1',
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 3),
  ));

  // Example:
  // Future<Response> getDoctors() async {
  //   try {
  //     return await _dio.get('/doctors');
  //   } catch (e) {
  //     rethrow;
  //   }
  // }
}
