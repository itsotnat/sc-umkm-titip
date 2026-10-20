import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import 'api_client.dart';
import 'pending_delete_store.dart';
import 'reminder_service.dart';
import 'secure_storage_service.dart';

/// Sync Layer (dokumen SAD Bagian 3 dan 6): mengirim semua data berstatus
/// `pending` (produk, outlet, pemesan, pesanan, titip) dan penghapusan yang
/// tertunda ke endpoint `/sync/push`, lalu menandainya `synced`.
///
/// Dipicu otomatis saat: aplikasi dibuka kembali (resume), koneksi internet
/// kembali, setelah ada perubahan lokal yang gagal terkirim, serta manual
/// lewat tombol "Sinkron sekarang". Semua operasi di server idempoten, jadi
/// aman dikirim ulang kapan pun.
class SyncManager extends ChangeNotifier with WidgetsBindingObserver {
  SyncManager._internal();
  static final SyncManager instance = SyncManager._internal();

  static const _tables = ['produk', 'outlet', 'pemesan', 'pesanan', 'transaksi_titip'];

  bool _isSyncing = false;
  bool _started = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _debounce;

  bool get isSyncing => _isSyncing;

  /// Jumlah perubahan lokal yang belum terkonfirmasi server (termasuk hapusan).
  int pendingCount = 0;
  bool isOffline = false;
  DateTime? lastSyncAt;

  /// Alasan penolakan/kegagalan terakhir (null bila sinkronisasi terakhir mulus).
  String? lastError;

  /// Pesan bila penarikan data dari server (saat login/Muat ulang) ada yang gagal.
  String? pullError;

  void setPullError(List<String> gagal) {
    pullError = gagal.isEmpty ? null : 'Data ${gagal.join(', ')} gagal dimuat dari server.';
    notifyListeners();
  }

  Future<bool> get isOnline async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  /// Mulai memantau resume aplikasi dan perubahan koneksi (dipanggil setelah login).
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _connectivitySub = Connectivity().onConnectivityChanged.listen((result) {
      final offline = result.contains(ConnectivityResult.none);
      if (offline != isOffline) {
        isOffline = offline;
        notifyListeners();
      }
      if (!offline) requestSync();
    });
    refreshPending();
    requestSync(delay: const Duration(milliseconds: 500));
  }

  /// Berhenti memantau (dipanggil saat logout atau sesi berakhir).
  void stop() {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _debounce?.cancel();
    ReminderService.instance.batalkanSemua();
    pendingCount = 0;
    lastError = null;
    pullError = null;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) requestSync();
  }

  /// Menjadwalkan sinkronisasi sebentar lagi (digabung bila dipanggil beruntun).
  void requestSync({Duration delay = const Duration(seconds: 2)}) {
    // Data lokal berubah / app dibuka: susun ulang pengingat (pesanan jatuh tempo, retur belum diinput).
    ReminderService.instance.requestRefresh();
    _debounce?.cancel();
    _debounce = Timer(delay, () => syncAll());
  }

  Future<int> countPending() async {
    final db = await AppDatabase.instance.database;
    var total = await PendingDeleteStore.count();
    for (final table in _tables) {
      final rows = await db.rawQuery("SELECT COUNT(*) AS c FROM $table WHERE sync_status = 'pending'");
      total += (rows.first['c'] as int?) ?? 0;
    }
    return total;
  }

  Future<void> refreshPending() async {
    pendingCount = await countPending();
    notifyListeners();
  }

  /// Mengirim semua data pending. Mengembalikan true bila permintaan ke
  /// server berhasil dijalankan (bukan berarti setiap item diterima; item
  /// yang ditolak tetap `pending` dan alasannya ada di [lastError]).
  Future<bool> syncAll() async {
    if (_isSyncing) return false;

    final token = await SecureStorageService.readToken();
    if (token == null || token.isEmpty) return false;

    if (!await isOnline) {
      isOffline = true;
      await refreshPending();
      return false;
    }
    isOffline = false;

    _isSyncing = true;
    notifyListeners();
    try {
      final db = await AppDatabase.instance.database;
      final snapshot = <String, Map<String, String?>>{}; // entitas -> id -> updated_at saat dikirim
      final payload = await _buildPayload(db, snapshot);

      if (payload.isEmpty) {
        lastError = null;
        lastSyncAt = DateTime.now();
        return true;
      }

      final response = await ApiClient.instance.dio.post('/sync/push', data: payload);
      final data = (response.data['data'] as Map).cast<String, dynamic>();
      final problems = await _applyResult(db, data, snapshot);

      lastError = problems.isEmpty ? null : problems.first;
      lastSyncAt = DateTime.now();
      if (lastError == null) await _saveLastSync();
      return true;
    } on DioException catch (e) {
      // Offline/timeout/5xx: data tetap pending, dicoba lagi di pemicu berikutnya.
      // (401 ditangani interceptor ApiClient -> sesi berakhir.)
      lastError = ApiClient.messageFromError(e);
      return false;
    } catch (_) {
      lastError = 'Sinkronisasi gagal. Data tetap aman di HP dan akan dicoba lagi.';
      return false;
    } finally {
      _isSyncing = false;
      await refreshPending();
    }
  }

  Future<Map<String, dynamic>> _buildPayload(Database db, Map<String, Map<String, String?>> snapshot) async {
    final payload = <String, dynamic>{};

    Future<List<Map<String, Object?>>> pending(String table) async {
      final rows = await db.query(table, where: "sync_status = 'pending'");
      snapshot[table] = {for (final r in rows) r['id'] as String: r['updated_at'] as String?};
      return rows;
    }

    final produk = await pending('produk');
    if (produk.isNotEmpty) {
      payload['produk'] = [
        for (final r in produk)
          {'id': r['id'], 'nama_produk': r['nama_produk'], 'hpp': r['hpp'], 'harga_jual': r['harga_jual']}
      ];
    }

    final outlet = await pending('outlet');
    if (outlet.isNotEmpty) {
      payload['outlet'] = [
        for (final r in outlet)
          {'id': r['id'], 'nama_outlet': r['nama_outlet'], 'alamat': r['alamat'], 'no_whatsapp': r['no_whatsapp']}
      ];
    }

    final pemesan = await pending('pemesan');
    if (pemesan.isNotEmpty) {
      payload['pemesan'] = [
        for (final r in pemesan) {'id': r['id'], 'nama_pemesan': r['nama_pemesan'], 'no_whatsapp': r['no_whatsapp']}
      ];
    }

    final pesanan = await pending('pesanan');
    if (pesanan.isNotEmpty) {
      final list = <Map<String, dynamic>>[];
      for (final r in pesanan) {
        final items = await db.query('pesanan_detail', where: 'pesanan_id = ?', whereArgs: [r['id']]);
        list.add({
          'id': r['id'],
          'pemesan_id': r['pemesan_id'],
          'tanggal_pesan': _dateOnly(r['tanggal_pesan']),
          'tanggal_jatuh_tempo': _dateOnly(r['tanggal_jatuh_tempo']),
          'status_selesai': r['status_selesai'] == 1,
          'status_lunas': r['status_lunas'] == 1,
          'catatan': r['catatan'],
          'items': [
            for (final d in items) {'produk_id': d['produk_id'], 'jumlah': d['jumlah']}
          ],
        });
      }
      payload['pesanan'] = list;
    }

    final titip = await pending('transaksi_titip');
    if (titip.isNotEmpty) {
      payload['titip'] = [
        for (final r in titip)
          {
            'id': r['id'],
            'outlet_id': r['outlet_id'],
            'produk_id': r['produk_id'],
            'tanggal': _dateOnly(r['tanggal']),
            'jumlah_kirim': r['jumlah_kirim'],
            'jumlah_retur': r['jumlah_retur'],
          }
      ];
    }

    final deleted = await PendingDeleteStore.all();
    if (deleted.isNotEmpty) payload['deleted'] = deleted;

    return payload;
  }

  String? _dateOnly(Object? value) {
    final s = value?.toString();
    if (s == null || s.length < 10) return s;
    return s.substring(0, 10);
  }

  /// Menandai item yang diterima server sebagai `synced`, menghapus antrean
  /// hapus yang sudah diproses, dan mengumpulkan alasan penolakan.
  Future<List<String>> _applyResult(
    Database db,
    Map<String, dynamic> data,
    Map<String, Map<String, String?>> snapshot,
  ) async {
    final problems = <String>[];
    const keyToTable = {
      'produk': 'produk',
      'outlet': 'outlet',
      'pemesan': 'pemesan',
      'pesanan': 'pesanan',
      'titip': 'transaksi_titip',
    };

    for (final entry in keyToTable.entries) {
      final result = data[entry.key];
      if (result is! Map) continue;
      final table = entry.value;
      final sent = snapshot[table] ?? const {};

      final batch = db.batch();
      for (final id in List<String>.from(result['synced_ids'] ?? const [])) {
        // Hanya tandai synced bila barisnya belum berubah lagi sejak dikirim,
        // supaya edit yang terjadi selama request berjalan tidak ikut "hilang".
        final sentAt = sent[id];
        if (table == 'pemesan' || sentAt == null) {
          batch.update(table, {'sync_status': 'synced'}, where: 'id = ?', whereArgs: [id]);
        } else {
          batch.update(table, {'sync_status': 'synced'}, where: 'id = ? AND updated_at = ?', whereArgs: [id, sentAt]);
        }
      }
      await batch.commit(noResult: true);

      for (final f in List<dynamic>.from(result['failed'] ?? const [])) {
        final reason = (f is Map ? f['reason'] : null)?.toString();
        if (reason != null && reason.isNotEmpty) problems.add('${_label(entry.key)}: $reason');
      }
    }

    final deleted = data['deleted'];
    if (deleted is Map) {
      for (final entity in PendingDeleteStore.entities) {
        await PendingDeleteStore.remove(entity, List<String>.from(deleted[entity] ?? const []));
      }
    }
    return problems;
  }

  String _label(String key) => switch (key) {
        'produk' => 'Produk',
        'outlet' => 'Outlet',
        'pemesan' => 'Pemesan',
        'pesanan' => 'Pesanan',
        _ => 'Titip',
      };

  Future<void> _saveLastSync() async {
    final db = await AppDatabase.instance.database;
    await db.update('auth_session', {'last_sync_at': DateTime.now().toIso8601String()}, where: 'id = 1');
  }
}
