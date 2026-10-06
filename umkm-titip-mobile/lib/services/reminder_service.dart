import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../db/app_database.dart';

/// Pengingat lokal di bar notifikasi HP (tanpa internet, tanpa server):
///  - 07:00 : pesanan yang jatuh tempo hari ini / besok dan belum selesai.
///  - 18:00 : catatan titip yang retur-nya belum diinput.
///
/// Notifikasi lokal berisi teks tetap, jadi jadwal 7 hari ke depan disusun ulang
/// setiap data berubah, aplikasi dibuka, atau saklar diubah (lihat [jadwalkanUlang]).
/// Pesanan yang sudah selesai / retur yang sudah diisi otomatis tidak lagi diingatkan.
class ReminderService {
  ReminderService._internal();
  static final ReminderService instance = ReminderService._internal();

  static const _kPesanan = 'reminder_pesanan_aktif';
  static const _kRetur = 'reminder_retur_aktif';
  static const _idPesananDasar = 100; // 100..106
  static const _idReturDasar = 200; // 200..202
  static const _jamPesanan = 7;
  static const _jamRetur = 18;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _siap = false;
  Timer? _debounce;

  Future<void> _init() async {
    if (_siap) return;
    tzdata.initializeTimeZones();
    // Pengingat memakai zona waktu HP (WIB/WITA/WIT). Nama singkat dari sistem dipetakan ke zona IANA.
    final zona = switch (DateTime.now().timeZoneName) {
      'WITA' => 'Asia/Makassar',
      'WIT' => 'Asia/Jayapura',
      _ => 'Asia/Jakarta',
    };
    tz.setLocalLocation(tz.getLocation(zona));
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    );
    _siap = true;
  }

  // ---------------------------------------------------------------- saklar

  Future<bool> pesananAktif() async => (await SharedPreferences.getInstance()).getBool(_kPesanan) ?? true;
  Future<bool> returAktif() async => (await SharedPreferences.getInstance()).getBool(_kRetur) ?? true;

  Future<void> setPesananAktif(bool v) async {
    await (await SharedPreferences.getInstance()).setBool(_kPesanan, v);
    if (v) await mintaIzin();
    await jadwalkanUlang();
  }

  Future<void> setReturAktif(bool v) async {
    await (await SharedPreferences.getInstance()).setBool(_kRetur, v);
    if (v) await mintaIzin();
    await jadwalkanUlang();
  }

  /// Android 13+ meminta izin notifikasi lewat dialog sistem. Mengembalikan true bila diizinkan.
  Future<bool> mintaIzin() async {
    try {
      await _init();
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? true;
    } catch (e) {
      debugPrint('[reminder] izin notifikasi gagal: $e');
      return false;
    }
  }

  // --------------------------------------------------------------- jadwal

  /// Disusun ulang sebentar lagi (digabung bila dipanggil beruntun, mis. banyak edit cepat).
  void requestRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), () => jadwalkanUlang());
  }

  /// Dipanggil saat logout: hapus semua pengingat milik akun sebelumnya.
  Future<void> batalkanSemua() async {
    _debounce?.cancel();
    try {
      await _init();
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('[reminder] batalkan gagal: $e');
    }
  }

  static const _detail = NotificationDetails(
    android: AndroidNotificationDetails(
      'pengingat_umkm_titip',
      'Pengingat UMKM Titip',
      channelDescription: 'Pengingat pesanan jatuh tempo dan retur yang belum diinput',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  String _kunci(tz.TZDateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> jadwalkanUlang() async {
    try {
      await _init();
      await _plugin.cancelAll();

      final db = await AppDatabase.instance.database;
      final sekarang = tz.TZDateTime.now(tz.local);
      final hariIni = tz.TZDateTime(tz.local, sekarang.year, sekarang.month, sekarang.day);

      if (await pesananAktif()) {
        final rows = await db.rawQuery('''
          SELECT ps.tanggal_jatuh_tempo AS tempo, pm.nama_pemesan AS nama
          FROM pesanan ps LEFT JOIN pemesan pm ON pm.id = ps.pemesan_id
          WHERE ps.status_selesai = 0
        ''');
        // tanggal (yyyy-MM-dd) -> daftar nama pemesan
        final perTanggal = <String, List<String>>{};
        for (final r in rows) {
          final t = (r['tempo'] as String?)?.substring(0, 10);
          if (t == null) continue;
          perTanggal.putIfAbsent(t, () => []).add((r['nama'] as String?) ?? 'pemesan');
        }

        for (var i = 0; i < 7; i++) {
          final hari = tz.TZDateTime(tz.local, hariIni.year, hariIni.month, hariIni.day + i);
          final besok = tz.TZDateTime(tz.local, hariIni.year, hariIni.month, hariIni.day + i + 1);
          final waktu = tz.TZDateTime(tz.local, hari.year, hari.month, hari.day, _jamPesanan);
          if (!waktu.isAfter(sekarang)) continue;
          final hariIniList = perTanggal[_kunci(hari)] ?? const <String>[];
          final besokList = perTanggal[_kunci(besok)] ?? const <String>[];
          if (hariIniList.isEmpty && besokList.isEmpty) continue;

          final bagian = <String>[];
          if (hariIniList.isNotEmpty) bagian.add('hari ini: ${_ringkasNama(hariIniList)}');
          if (besokList.isNotEmpty) bagian.add('besok: ${_ringkasNama(besokList)}');
          await _plugin.zonedSchedule(
            id: _idPesananDasar + i,
            title: 'Pesanan jatuh tempo',
            body: bagian.join(' · '),
            scheduledDate: waktu,
            notificationDetails: _detail,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
        }
      }

      if (await returAktif()) {
        final hitung = await db.rawQuery(
          'SELECT COUNT(*) AS c FROM transaksi_titip WHERE jumlah_retur IS NULL AND jumlah_kirim > 0 AND tanggal <= ?',
          [_kunci(hariIni)],
        );
        final belum = (hitung.first['c'] as int?) ?? 0;
        if (belum > 0) {
          for (var i = 0; i < 3; i++) {
            final waktu = tz.TZDateTime(tz.local, hariIni.year, hariIni.month, hariIni.day + i, _jamRetur);
            if (!waktu.isAfter(sekarang)) continue;
            await _plugin.zonedSchedule(
              id: _idReturDasar + i,
              title: 'Retur belum diinput',
              body: 'Ada $belum catatan titip yang retur-nya belum diisi. Ketuk untuk melengkapi.',
              scheduledDate: waktu,
              notificationDetails: _detail,
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            );
          }
        }
      }
    } catch (e) {
      // Pengingat hanya pelengkap: kegagalan di sini tidak boleh mengganggu aplikasi.
      debugPrint('[reminder] jadwal gagal: $e');
    }
  }

  String _ringkasNama(List<String> nama) {
    if (nama.length <= 2) return nama.join(', ');
    return '${nama.take(2).join(', ')} +${nama.length - 2} lainnya';
  }
}
