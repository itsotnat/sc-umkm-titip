/// Ganti sesuai environment: alamat backend yang sedang dipakai.
/// - Emulator Android: gunakan 10.0.2.2 untuk mengakses localhost komputer.
/// - Device fisik / production: gunakan domain https://umkmtitip.store/api/v1
class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api/v1',
  );
}
