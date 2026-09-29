import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../models/produk.dart';
import '../services/api_client.dart';

/// Repository produk. Tambah/edit dikirim langsung ke server (data master,
/// butuh koneksi internet), lalu hasil dari server (termasuk id resmi)
/// disimpan sebagai cache lokal supaya tetap bisa dibaca offline. Kalau
/// gagal kirim (mis. tidak ada internet), tetap disimpan lokal berstatus
/// `pending` supaya input tidak hilang, walau baru benar-benar aman dari
/// `clearAll()` saat logout setelah berhasil tersinkron ke server.
class ProdukRepository {
  final _uuid = const Uuid();

  Future<List<Produk>> getAll() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('produk', orderBy: 'nama_produk ASC');
    return rows.map(Produk.fromMap).toList();
  }

  Future<Produk> create({required String namaProduk, required double hpp, required double hargaJual}) async {
    final db = await AppDatabase.instance.database;
    try {
      final response = await ApiClient.instance.dio.post('/produk', data: {
        'nama_produk': namaProduk,
        'hpp': hpp,
        'harga_jual': hargaJual,
      });
      final data = response.data['data'];
      final produk = Produk(
        id: data['id'],
        namaProduk: data['nama_produk'],
        hpp: (data['hpp'] as num).toDouble(),
        hargaJual: (data['harga_jual'] as num).toDouble(),
        syncStatus: 'synced',
        updatedAt: DateTime.tryParse(data['updated_at']?.toString() ?? '') ?? DateTime.now(),
      );
      await db.insert('produk', produk.toMap());
      return produk;
    } catch (_) {
      final produk = Produk(id: _uuid.v4(), namaProduk: namaProduk, hpp: hpp, hargaJual: hargaJual);
      await db.insert('produk', produk.toMap());
      return produk;
    }
  }

  Future<void> update(Produk produk) async {
    final db = await AppDatabase.instance.database;
    try {
      final response = await ApiClient.instance.dio.put('/produk/${produk.id}', data: {
        'nama_produk': produk.namaProduk,
        'hpp': produk.hpp,
        'harga_jual': produk.hargaJual,
      });
      final data = response.data['data'];
      final synced = Produk(
        id: data['id'],
        namaProduk: data['nama_produk'],
        hpp: (data['hpp'] as num).toDouble(),
        hargaJual: (data['harga_jual'] as num).toDouble(),
        syncStatus: 'synced',
        updatedAt: DateTime.tryParse(data['updated_at']?.toString() ?? '') ?? DateTime.now(),
      );
      await db.update('produk', synced.toMap(), where: 'id = ?', whereArgs: [synced.id]);
    } catch (_) {
      await db.update(
        'produk',
        produk.copyWith(syncStatus: 'pending').toMap(),
        where: 'id = ?',
        whereArgs: [produk.id],
      );
    }
  }

  Future<void> delete(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('produk', where: 'id = ?', whereArgs: [id]);
    // Best-effort: hapus juga di server bila online. Kegagalan tidak menghalangi hapus lokal.
    try {
      await ApiClient.instance.dio.delete('/produk/$id');
    } catch (_) {
      // Tidak apa-apa jika sedang offline; server tidak akan tahu, tapi ini
      // dianggap batas MVP karena penghapusan jarang terjadi dan bisa
      // diselaraskan manual bila diperlukan.
    }
  }

  /// Mengambil daftar produk dari server dan menimpa data lokal (dipakai saat login/pull sync).
  Future<void> replaceFromServer(List<dynamic> serverItems) async {
    final db = await AppDatabase.instance.database;
    final batch = db.batch();
    for (final item in serverItems) {
      final produk = Produk(
        id: item['id'],
        namaProduk: item['nama_produk'],
        hpp: (item['hpp'] as num).toDouble(),
        hargaJual: (item['harga_jual'] as num).toDouble(),
        syncStatus: 'synced',
        updatedAt: DateTime.tryParse(item['updated_at']?.toString() ?? '') ?? DateTime.now(),
      );
      batch.insert('produk', produk.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }
}
