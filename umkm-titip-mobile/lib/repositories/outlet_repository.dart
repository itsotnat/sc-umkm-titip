import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../models/outlet.dart';
import '../services/api_client.dart';

class OutletRepository {
  final _uuid = const Uuid();

  Future<List<Outlet>> getAll() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('outlet', orderBy: 'nama_outlet ASC');
    return rows.map(Outlet.fromMap).toList();
  }

  Future<Outlet> create({required String namaOutlet, String? alamat, String? noWhatsapp}) async {
    final outlet = Outlet(id: _uuid.v4(), namaOutlet: namaOutlet, alamat: alamat, noWhatsapp: noWhatsapp);
    final db = await AppDatabase.instance.database;
    await db.insert('outlet', outlet.toMap());
    return outlet;
  }

  Future<void> update(Outlet outlet) async {
    final db = await AppDatabase.instance.database;
    await db.update('outlet', outlet.toMap(), where: 'id = ?', whereArgs: [outlet.id]);
  }

  Future<void> delete(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('outlet', where: 'id = ?', whereArgs: [id]);
    try {
      await ApiClient.instance.dio.delete('/outlet/$id');
    } catch (_) {
      // Lihat catatan yang sama di ProdukRepository.delete.
    }
  }

  Future<void> replaceFromServer(List<dynamic> serverItems) async {
    final db = await AppDatabase.instance.database;
    final batch = db.batch();
    for (final item in serverItems) {
      final outlet = Outlet(
        id: item['id'],
        namaOutlet: item['nama_outlet'],
        alamat: item['alamat'],
        noWhatsapp: item['no_whatsapp'],
        syncStatus: 'synced',
        updatedAt: DateTime.tryParse(item['updated_at']?.toString() ?? '') ?? DateTime.now(),
      );
      batch.insert('outlet', outlet.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }
}
