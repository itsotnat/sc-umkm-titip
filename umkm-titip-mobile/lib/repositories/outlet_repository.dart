import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../models/outlet.dart';
import '../services/api_client.dart';
import '../services/pending_delete_store.dart';
import '../services/sync_manager.dart';

/// Sama seperti ProdukRepository: tambah/edit outlet dikirim ke server dulu
/// (data master, butuh koneksi), baru dicache lokal dengan id resmi dari
/// server, supaya aman saat `clearAll()` dipanggil ketika logout.
class OutletRepository {
  final _uuid = const Uuid();

  Future<List<Outlet>> getAll() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('outlet', orderBy: 'nama_outlet ASC');
    return rows.map(Outlet.fromMap).toList();
  }

  Future<Outlet> create({required String namaOutlet, String? alamat, String? noWhatsapp}) async {
    final db = await AppDatabase.instance.database;
    try {
      final response = await ApiClient.instance.dio.post('/outlet', data: {
        'nama_outlet': namaOutlet,
        'alamat': alamat,
        'no_whatsapp': noWhatsapp,
      });
      final data = response.data['data'];
      final outlet = Outlet(
        id: data['id'],
        namaOutlet: data['nama_outlet'],
        alamat: data['alamat'],
        noWhatsapp: data['no_whatsapp'],
        syncStatus: 'synced',
        updatedAt: DateTime.tryParse(data['updated_at']?.toString() ?? '') ?? DateTime.now(),
      );
      await db.insert('outlet', outlet.toMap());
      return outlet;
    } catch (_) {
      final outlet = Outlet(id: _uuid.v4(), namaOutlet: namaOutlet, alamat: alamat, noWhatsapp: noWhatsapp);
      await db.insert('outlet', outlet.toMap());
      SyncManager.instance.requestSync();
      return outlet;
    }
  }

  Future<void> update(Outlet outlet) async {
    final db = await AppDatabase.instance.database;
    try {
      final response = await ApiClient.instance.dio.put('/outlet/${outlet.id}', data: {
        'nama_outlet': outlet.namaOutlet,
        'alamat': outlet.alamat,
        'no_whatsapp': outlet.noWhatsapp,
      });
      final data = response.data['data'];
      final synced = Outlet(
        id: data['id'],
        namaOutlet: data['nama_outlet'],
        alamat: data['alamat'],
        noWhatsapp: data['no_whatsapp'],
        syncStatus: 'synced',
        updatedAt: DateTime.tryParse(data['updated_at']?.toString() ?? '') ?? DateTime.now(),
      );
      await db.update('outlet', synced.toMap(), where: 'id = ?', whereArgs: [synced.id]);
    } catch (_) {
      await db.update(
        'outlet',
        Outlet(
          id: outlet.id,
          namaOutlet: outlet.namaOutlet,
          alamat: outlet.alamat,
          noWhatsapp: outlet.noWhatsapp,
          syncStatus: 'pending',
        ).toMap(),
        where: 'id = ?',
        whereArgs: [outlet.id],
      );
      SyncManager.instance.requestSync();
    }
  }

  Future<void> delete(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('outlet', where: 'id = ?', whereArgs: [id]);
    try {
      await ApiClient.instance.dio.delete('/outlet/$id');
    } catch (_) {
      // Lihat catatan yang sama di ProdukRepository.delete.
      await PendingDeleteStore.enqueue('outlet', id);
      SyncManager.instance.requestSync();
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
