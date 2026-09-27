import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
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

    return data;
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
