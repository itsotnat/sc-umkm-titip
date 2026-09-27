import 'package:flutter/foundation.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';

enum AuthStatus { unknown, loggedIn, loggedOut }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AuthStatus status = AuthStatus.unknown;
  bool isLoading = false;
  String? errorMessage;
  String? namaUsaha;

  Future<void> checkSession() async {
    final loggedIn = await _authService.isLoggedIn();
    status = loggedIn ? AuthStatus.loggedIn : AuthStatus.loggedOut;
    notifyListeners();
  }

  Future<bool> login(String email, String password) => _run(() async {
        final data = await _authService.login(email: email, password: password);
        namaUsaha = data['user']?['nama_usaha'];
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
        this.namaUsaha = data['user']?['nama_usaha'];
      });

  Future<bool> _run(Future<void> Function() action) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
      status = AuthStatus.loggedIn;
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
    await _authService.logout();
    status = AuthStatus.loggedOut;
    notifyListeners();
  }
}
