import 'package:dio/dio.dart';

import '../utils/constants.dart';
import 'secure_storage_service.dart';

/// Klien HTTP tunggal ke backend. Menyisipkan header Authorization otomatis
/// dari token yang tersimpan, sesuai kontrak di dokumen REST API Spec Bagian 1.
class ApiClient {
  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await SecureStorageService.readToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._internal();
  late final Dio _dio;

  Dio get dio => _dio;

  /// Mengekstrak pesan error dari format standar { success:false, error:{code,message} }.
  static String messageFromError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['error'] != null && data['error']['message'] != null) {
        return data['error']['message'].toString();
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError) {
        return 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.';
      }
    }
    return 'Terjadi kesalahan. Silakan coba lagi.';
  }
}
