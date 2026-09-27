import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Penyimpanan token JWT secara aman di perangkat (dokumen SAD Bagian 7).
class SecureStorageService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';

  static Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);

  static Future<String?> readToken() => _storage.read(key: _tokenKey);

  static Future<void> clearToken() => _storage.delete(key: _tokenKey);
}
