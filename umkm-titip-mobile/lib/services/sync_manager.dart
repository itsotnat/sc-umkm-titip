import 'package:connectivity_plus/connectivity_plus.dart';

import '../db/app_database.dart';
import '../repositories/titip_repository.dart';
import 'api_client.dart';

/// Sync Layer: memantau koneksi internet, mengirim data berstatus `pending`
/// ke backend saat online, lalu menandainya `synced`, sesuai dokumen SAD
/// Bagian 3 dan 6.
class SyncManager {
  SyncManager._internal();
  static final SyncManager instance = SyncManager._internal();

  final TitipRepository _titipRepository = TitipRepository();
  bool _isSyncing = false;

  Future<bool> get isOnline async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  /// Dipanggil saat aplikasi dibuka/di-resume, atau lewat pull-to-refresh.
  /// Mengembalikan true bila sinkronisasi berhasil dijalankan (bukan berarti semua item sukses).
  Future<bool> syncPendingTitip() async {
    if (_isSyncing) return false;
    if (!await isOnline) return false;

    _isSyncing = true;
    try {
      final pending = await _titipRepository.getPendingSync();
      if (pending.isEmpty) return true;

      final response = await ApiClient.instance.dio.post('/titip/sync', data: {
        'items': pending.map((t) => t.toMap()).toList(),
      });

      final data = response.data['data'];
      final syncedIds = List<String>.from(data['synced_ids'] ?? const []);
      await _titipRepository.markSynced(syncedIds);
      return true;
    } catch (_) {
      // Gagal sinkron (timeout, error 5xx, dsb): data tetap tersimpan lokal
      // berstatus pending dan akan dicoba ulang otomatis pada sinkronisasi
      // berikutnya, sesuai dokumen SDD Bagian 6. Pengguna tidak kehilangan data.
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> updateLastSyncTime() async {
    final db = await AppDatabase.instance.database;
    await db.update('auth_session', {'last_sync_at': DateTime.now().toIso8601String()}, where: 'id = 1');
  }
}
