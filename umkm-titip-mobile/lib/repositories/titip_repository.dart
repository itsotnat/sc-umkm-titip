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
    required int jumlahRetur,
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
}
