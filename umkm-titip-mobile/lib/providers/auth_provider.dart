import 'package:flutter/foundation.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/sync_manager.dart';

enum AuthStatus { unknown, loggedIn, loggedOut }

class AuthProvider extends ChangeNotifier {
  AuthProvider() {
    // Server membalas 401 (token kedaluwarsa) di endpoint mana pun -> sesi berakhir.
    ApiClient.onUnauthorized = _handleSessionExpired;
  }

  final AuthService _authService = AuthService();

  /// True bila pengguna dikeluarkan karena token kedaluwarsa (bukan logout sendiri).
  bool sessionExpired = false;
  bool sessionReplaced = false; // true = akun dipakai login di perangkat lain

  AuthStatus status = AuthStatus.unknown;
  bool isLoading = false;
  String? errorMessage;
  String? namaUsaha;
  String? namaPemilik;
  String? email;

  /// Path relatif foto profil dari server (null = belum ada foto).
  String? fotoUrl;

  bool isUploadingFoto = false;

  Future<void> checkSession() async {
    final loggedIn = await _authService.isLoggedIn();
    if (loggedIn) {
      final local = await _authService.localProfile();
      if (local != null) _applyUser(local);
    }
    status = loggedIn ? AuthStatus.loggedIn : AuthStatus.loggedOut;
    notifyListeners();
    if (loggedIn) {
      // Segarkan di latar belakang; kalau offline/gagal, data lokal tetap dipakai.
      refreshProfile();
      SyncManager.instance.start();
    }
  }

  Future<void> _handleSessionExpired(String? code) async {
    if (status != AuthStatus.loggedIn) return;
    sessionReplaced = code == 'SESSION_REPLACED';
    await _authService.expireSession();
    SyncManager.instance.stop();
    sessionExpired = true;
    status = AuthStatus.loggedOut;
    notifyListeners();
  }

  void dismissSessionExpired() {
    sessionExpired = false;
    sessionReplaced = false;
    notifyListeners();
  }

  void _applyUser(Map<String, dynamic>? user) {
    if (user == null) return;
    namaUsaha = user['nama_usaha'] as String?;
    namaPemilik = user['nama_pemilik'] as String?;
    email = user['email'] as String?;
    fotoUrl = user['foto_url'] as String?;
  }

  Future<void> refreshProfile() async {
    try {
      _applyUser(await _authService.fetchProfile());
      notifyListeners();
    } catch (_) {
      // Offline atau token bermasalah: abaikan, pakai data lokal.
    }
  }

  /// Mengunggah foto baru. Mengembalikan null kalau sukses, atau pesan error.
  Future<String?> ubahFoto(String filePath) => _runFoto(() => _authService.uploadFoto(filePath));

  Future<String?> hapusFoto() => _runFoto(_authService.deleteFoto);

  Future<String?> _runFoto(Future<Map<String, dynamic>> Function() action) async {
    isUploadingFoto = true;
    notifyListeners();
    try {
      _applyUser(await action());
      return null;
    } catch (e) {
      return ApiClient.messageFromError(e);
    } finally {
      isUploadingFoto = false;
      notifyListeners();
    }
  }

  Future<void> kirimKodReset(String email) => _authService.forgotPassword(email);

  Future<void> resetPassword({required String email, required String code, required String newPassword}) =>
      _authService.resetPassword(email: email, code: code, newPassword: newPassword);

  Future<bool> login(String email, String password) => _run(() async {
        final data = await _authService.login(email: email, password: password);
        _applyUser(data['user'] as Map<String, dynamic>?);
      });

  Future<bool> register({
    required String namaUsaha,
    required String namaPemilik,
    required String email,
    required String password,
  }) =>
      _run(() async {
        final data = await _authService.register(
          namaUsaha: namaUsaha,
          namaPemilik: namaPemilik,
          email: email,
          password: password,
        );
        _applyUser(data['user'] as Map<String, dynamic>?);
      });

  Future<bool> _run(Future<void> Function() action) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
      status = AuthStatus.loggedIn;
      sessionExpired = false;
      sessionReplaced = false;
      SyncManager.instance.start();
      return true;
    } catch (e) {
      errorMessage = ApiClient.messageFromError(e);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    SyncManager.instance.stop();
    await _authService.logout();
    sessionExpired = false;
    namaUsaha = namaPemilik = email = fotoUrl = null;
    status = AuthStatus.loggedOut;
    notifyListeners();
  }
}
