import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../models/transaksi_titip.dart';

class TitipRepository {
  final _uuid = const Uuid();

  Future<List<TransaksiTitip>> getByOutletDanTanggal(String outletId, DateTime tanggal) async {
    final db = await AppDatabase.instance.database;
    final tanggalStr = tanggal.toIso8601String().substring(0, 10);
    final rows = await db.query(
      'transaksi_titip',
      where: 'outlet_id = ? AND tanggal = ?',
      whereArgs: [outletId, tanggalStr],
    );
    return rows.map(TransaksiTitip.fromMap).toList();
  }

  /// Upsert satu baris (satu produk) untuk outlet & tanggal tertentu.
  /// Dipanggil setiap kali tombol Simpan pada Bottom Sheet Input Harian ditekan.
  Future<void> upsert({
    required String outletId,
    required String produkId,
    required DateTime tanggal,
    required int jumlahKirim,
    int? jumlahRetur,
    String? existingId,
  }) async {
    final db = await AppDatabase.instance.database;
    final id = existingId ?? _uuid.v4();
    final transaksi = TransaksiTitip(
      id: id,
      outletId: outletId,
      produkId: produkId,
      tanggal: tanggal,
      jumlahKirim: jumlahKirim,
      jumlahRetur: jumlahRetur,
      syncStatus: 'pending',
    );
    await db.insert(
      'transaksi_titip',
      transaksi.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<TransaksiTitip>> getPendingSync() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('transaksi_titip', where: "sync_status = 'pending'");
    return rows.map(TransaksiTitip.fromMap).toList();
  }

  Future<void> markSynced(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await AppDatabase.instance.database;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.update(
      'transaksi_titip',
      {'sync_status': 'synced'},
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  /// Tanggal dari server (kolom `date` PostgreSQL) datang sebagai ISO 8601,
  /// mis. `2026-10-05T00:00:00.000Z` (server UTC) atau `2026-10-04T17:00:00.000Z`
  /// (server WIB). Dikonversi ke zona waktu perangkat lalu diambil tanggalnya,
  /// supaya tidak bergeser sehari. Format polos `2026-10-05` dipakai apa adanya.
  static String tanggalDariServer(dynamic nilai) {
    final teks = nilai.toString();
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(teks)) return teks;
    final waktu = DateTime.parse(teks).toLocal();
    final bulan = waktu.month.toString().padLeft(2, '0');
    final hari = waktu.day.toString().padLeft(2, '0');
    return '${waktu.year}-$bulan-$hari';
  }

  /// Dipanggil saat login: mengisi ulang data titip dari server (mis. setelah
  /// logout yang mengosongkan database lokal). Baris lokal yang masih `pending`
  /// tidak ditimpa.
  Future<void> replaceFromServer(List<dynamic> serverItems) async {
    final db = await AppDatabase.instance.database;
    final pending = await db.query('transaksi_titip', columns: ['id'], where: "sync_status = 'pending'");
    final pendingIds = pending.map((r) => r['id'] as String).toSet();
    final batch = db.batch();
    for (final item in serverItems) {
      final id = item['id'] as String;
      if (pendingIds.contains(id)) continue;
      batch.insert(
        'transaksi_titip',
        {
          'id': id,
          'outlet_id': item['outlet_id'],
          'produk_id': item['produk_id'],
          'tanggal': tanggalDariServer(item['tanggal']),
          'jumlah_kirim': item['jumlah_kirim'],
          'jumlah_retur': item['jumlah_retur'],
          'sync_status': 'synced',
          'updated_at': item['updated_at']?.toString() ?? DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }
}
