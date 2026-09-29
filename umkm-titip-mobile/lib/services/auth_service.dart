import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import '../repositories/outlet_repository.dart';
import '../repositories/pesanan_repository.dart';
import '../repositories/produk_repository.dart';
import 'api_client.dart';
import 'secure_storage_service.dart';

class AuthService {
  final Dio _dio = ApiClient.instance.dio;

  Future<Map<String, dynamic>> register({
    required String namaUsaha,
    required String namaPemilik,
    required String email,
    required String password,
  }) async {
    final response = await _dio.post('/auth/register', data: {
      'nama_usaha': namaUsaha,
      'nama_pemilik': namaPemilik,
      'email': email,
      'password': password,
    });
    return _persistSession(response.data['data']);
  }

  Future<Map<String, dynamic>> login({required String email, required String password}) async {
    final response = await _dio.post('/auth/login', data: {'email': email, 'password': password});
    return _persistSession(response.data['data']);
  }

  Future<Map<String, dynamic>> _persistSession(Map<String, dynamic> data) async {
    final token = data['token'] as String;
    final user = data['user'] as Map<String, dynamic>;
    await SecureStorageService.saveToken(token);

    final db = await AppDatabase.instance.database;
    await db.insert('auth_session', {
      'id': 1,
      'user_id': user['id'],
      'nama_usaha': user['nama_usaha'],
      'nama_pemilik': user['nama_pemilik'],
      'email': user['email'],
      'last_sync_at': null,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // Tarik ulang seluruh data master dari server setiap kali berhasil
    // login/register, supaya data tetap ada walau sebelumnya sempat logout
    // (yang mengosongkan database lokal lewat AppDatabase.clearAll()).
    await _pullMasterData();

    return data;
  }

  /// Sesuai dokumen SAD Bagian 3 (Sync Layer, pull saat login). Kalau gagal
  /// (mis. baru login lalu langsung offline), dibiarkan saja: data lokal
  /// tetap seperti sebelumnya dan bisa dicoba lagi lewat pull-to-refresh
  /// di masing-masing layar.
  Future<void> _pullMasterData() async {
    try {
      final results = await Future.wait([
        _dio.get('/produk'),
        _dio.get('/outlet'),
        _dio.get('/pemesan'),
        _dio.get('/pesanan'),
      ]);
      await ProdukRepository().replaceFromServer(results[0].data['data'] as List<dynamic>);
      await OutletRepository().replaceFromServer(results[1].data['data'] as List<dynamic>);
      await PemesanRepository().replaceFromServer(results[2].data['data'] as List<dynamic>);
      await PesananRepository().replaceFromServer(results[3].data['data'] as List<dynamic>);
    } catch (_) {
      // Lihat catatan di atas.
    }
  }

  Future<bool> isLoggedIn() async {
    final token = await SecureStorageService.readToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> logout() async {
    await SecureStorageService.clearToken();
    await AppDatabase.instance.clearAll();
  }
}
