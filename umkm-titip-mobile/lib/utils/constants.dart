/// Ganti sesuai environment: alamat backend yang sedang dipakai.
/// - Default sekarang: backend production di VPS (api-backend.umkm-titip.web.id),
///   sudah aktif dan bisa diakses dari device fisik maupun emulator.
/// - Kalau mau testing ke backend lokal di komputer sendiri:
///   - Emulator Android: `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1`
///   - Device fisik via USB: jalankan `adb reverse tcp:3000 tcp:3000` dulu, lalu
///     `flutter run --dart-define=API_BASE_URL=http://127.0.0.1:3000/api/v1`
class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api-backend.umkm-titip.web.id/api/v1',
  );
}
