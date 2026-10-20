import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import '../repositories/outlet_repository.dart';
import '../repositories/pesanan_repository.dart';
import '../repositories/produk_repository.dart';
import '../repositories/titip_repository.dart';
import 'api_client.dart';
import 'secure_storage_service.dart';
import 'sync_manager.dart';

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

    // Sesi lama berakhir (token kedaluwarsa) lalu login dengan akun yang SAMA:
    // data lokal yang belum tersinkron dipertahankan. Akun BERBEDA: data akun
    // sebelumnya dibuang supaya tidak tercampur.
    final lama = await db.query('auth_session', where: 'id = 1', limit: 1);
    if (lama.isNotEmpty && lama.first['user_id'] != user['id']) {
      await AppDatabase.instance.clearAll();
    }

    await db.insert('auth_session', {
      'id': 1,
      'user_id': user['id'],
      'nama_usaha': user['nama_usaha'],
      'nama_pemilik': user['nama_pemilik'],
      'email': user['email'],
      'foto_url': user['foto_url'],
      'last_sync_at': null,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // Kirim dulu data yang masih pending, sebelum ditimpa data dari server.
    await SyncManager.instance.syncAll();

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
    await _pullTitip();
  }

  /// Data titip harian (kirim dan retur) ikut ditarik lewat /sync/pull. Dipisah
  /// supaya kegagalan di sini tidak membatalkan data master yang sudah masuk.
  Future<void> _pullTitip() async {
    try {
      final res = await _dio.post('/sync/pull', data: <String, dynamic>{});
      final titip = (res.data['data']['titip'] as List<dynamic>?) ?? const [];
      await TitipRepository().replaceFromServer(titip);
    } catch (_) {
      // Dicoba lagi pada login berikutnya.
    }
  }

  /// Kode OTP 6 digit dikirim ke email. Server selalu membalas sukses, ada atau
  /// tidaknya email di database (anti-enumerasi).
  Future<void> forgotPassword(String email) async {
    await _dio.post('/auth/forgot-password', data: {'email': email});
  }

  Future<void> resetPassword({required String email, required String code, required String newPassword}) async {
    await _dio.post('/auth/reset-password', data: {'email': email, 'code': code, 'new_password': newPassword});
  }

  /// Profil lokal dari sesi login terakhir (bisa dipakai offline).
  Future<Map<String, dynamic>?> localProfile() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('auth_session', where: 'id = 1', limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  /// Ambil profil terbaru dari server lalu simpan ke sesi lokal.
  Future<Map<String, dynamic>> fetchProfile() async {
    final response = await _dio.get('/auth/me');
    return _saveUser(response.data['data']['user'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> updateProfile({
    required String namaUsaha,
    required String namaPemilik,
    String? noHp,
  }) async {
    final response = await _dio.patch('/auth/me', data: {
      'nama_usaha': namaUsaha,
      'nama_pemilik': namaPemilik,
      'no_hp': noHp,
    });
    return _saveUser(response.data['data']['user'] as Map<String, dynamic>);
  }

  /// Ganti password. Server membalas token baru: perangkat ini tetap masuk,
  /// perangkat lain otomatis keluar.
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    final response = await _dio.post('/auth/change-password', data: {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
    final token = response.data['data']['token'] as String?;
    if (token != null && token.isNotEmpty) await SecureStorageService.saveToken(token);
  }

  /// Minta server mengirim cadangan data (JSON) ke email akun sekarang.
  Future<void> kirimCadanganKeEmail() async {
    await _dio.post(
      '/backup/email',
      options: Options(sendTimeout: const Duration(seconds: 30), receiveTimeout: const Duration(seconds: 45)),
    );
  }

  Future<Map<String, dynamic>> uploadFoto(String filePath) async {
    final form = FormData.fromMap({'foto': await MultipartFile.fromFile(filePath)});
    final response = await _dio.post(
      '/auth/me/foto',
      data: form,
      options: Options(sendTimeout: const Duration(seconds: 30), receiveTimeout: const Duration(seconds: 30)),
    );
    return _saveUser(response.data['data']['user'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> deleteFoto() async {
    final response = await _dio.delete('/auth/me/foto');
    return _saveUser(response.data['data']['user'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> _saveUser(Map<String, dynamic> user) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'auth_session',
      {
        'nama_usaha': user['nama_usaha'],
        'nama_pemilik': user['nama_pemilik'],
        'email': user['email'],
        'foto_url': user['foto_url'],
      },
      where: 'id = 1',
    );
    return user;
  }

  Future<bool> isLoggedIn() async {
    final token = await SecureStorageService.readToken();
    return token != null && token.isNotEmpty;
  }

  /// Sesi habis (401): hanya token yang dihapus. Data lokal dipertahankan
  /// supaya perubahan yang belum tersinkron tidak hilang.
  Future<void> expireSession() => SecureStorageService.clearToken();

  Future<void> logout() async {
    await SecureStorageService.clearToken();
    await AppDatabase.instance.clearAll();
  }
}
