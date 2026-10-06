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
        onError: (error, handler) {
          // Token kedaluwarsa/tidak valid: beri tahu AuthProvider (kecuali pada
          // endpoint login/daftar/reset, yang memang bisa membalas 401/400 biasa).
          final path = error.requestOptions.path;
          final publik = _publicPaths.any(path.endsWith);
          if (error.response?.statusCode == 401 && !publik) {
            String? code;
            final data = error.response?.data;
            if (data is Map && data['error'] is Map) {
              code = data['error']['code']?.toString();
            }
            onUnauthorized?.call(code);
          }
          handler.next(error);
        },
      ),
    );
  }

  static const _publicPaths = ['/auth/login', '/auth/register', '/auth/forgot-password', '/auth/reset-password'];

  /// Dipanggil saat server membalas 401 pada endpoint yang butuh login.
  /// [code] = kode error server, mis. SESSION_REPLACED bila akun dipakai login di perangkat lain.
  static Future<void> Function(String? code)? onUnauthorized;

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
