import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';

/// Antrean penghapusan yang belum sempat dikirim ke server (saat offline).
/// Baris yang dihapus di HP sudah tidak ada lagi di tabel aslinya, jadi
/// id-nya dicatat di sini sampai server mengonfirmasi penghapusan.
class PendingDeleteStore {
  static const entities = ['pesanan', 'pemesan', 'outlet', 'produk'];

  static Future<void> enqueue(String entity, String id) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'pending_delete',
      {'entity': entity, 'id': id},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Hasilnya dikelompokkan per entitas, siap dipakai sebagai `deleted` di /sync/push.
  static Future<Map<String, List<String>>> all() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('pending_delete');
    final result = <String, List<String>>{};
    for (final row in rows) {
      (result[row['entity'] as String] ??= []).add(row['id'] as String);
    }
    return result;
  }

  static Future<void> remove(String entity, Iterable<String> ids) async {
    if (ids.isEmpty) return;
    final db = await AppDatabase.instance.database;
    final batch = db.batch();
    for (final id in ids) {
      batch.delete('pending_delete', where: 'entity = ? AND id = ?', whereArgs: [entity, id]);
    }
    await batch.commit(noResult: true);
  }

  static Future<int> count() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM pending_delete');
    return (rows.first['c'] as int?) ?? 0;
  }
}
