import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../models/pemesan.dart';
import '../models/pesanan.dart';
import '../models/pesanan_detail.dart';
import '../services/api_client.dart';

/// Sama seperti ProdukRepository/OutletRepository: pesanan dikirim ke server
/// dulu (butuh koneksi), baru dicache lokal dengan id resmi dari server,
/// supaya aman saat `clearAll()` dipanggil ketika logout.
class PesananRepository {
  final _uuid = const Uuid();

  Future<List<Pesanan>> getAll({String? filterStatus}) async {
    final db = await AppDatabase.instance.database;
    String? where;
    if (filterStatus == 'selesai') {
      where = 'status_selesai = 1';
    } else if (filterStatus == 'belum_selesai') {
      where = 'status_selesai = 0';
    }

    final headers = await db.query('pesanan', where: where, orderBy: 'tanggal_jatuh_tempo ASC');
    final result = <Pesanan>[];
    for (final header in headers) {
      final pemesanRow = await db.query('pemesan', where: 'id = ?', whereArgs: [header['pemesan_id']]);
      final itemRows = await db.query('pesanan_detail', where: 'pesanan_id = ?', whereArgs: [header['id']]);
      final items = itemRows.map(PesananDetail.fromMap).toList();
      final map = Map<String, dynamic>.from(header);
      if (pemesanRow.isNotEmpty) {
        map['nama_pemesan'] = pemesanRow.first['nama_pemesan'];
      }
      result.add(Pesanan.fromMap(map, items: items));
    }
    return result;
  }

  /// Membuat pesanan header + detail. Dikirim ke server dulu (transaksi
  /// atomik di backend, lihat pesanan.service.js), baru dicache lokal
  /// dengan id resmi dari server. Kalau gagal (offline), tetap disimpan
  /// lokal transaksi atomik sesuai dokumen SDD Bagian 3, tapi berstatus
  /// `pending` (belum ada endpoint retry-push khusus pesanan untuk kasus ini).
  Future<Pesanan> create({
    required String pemesanId,
    required DateTime tanggalJatuhTempo,
    required List<({String produkId, int jumlah})> items,
    String? catatan,
  }) async {
    final db = await AppDatabase.instance.database;
    final tanggalStr = tanggalJatuhTempo.toIso8601String().substring(0, 10);

    try {
      final response = await ApiClient.instance.dio.post('/pesanan', data: {
        'pemesan_id': pemesanId,
        'tanggal_jatuh_tempo': tanggalStr,
        'catatan': catatan,
        'items': items.map((i) => {'produk_id': i.produkId, 'jumlah': i.jumlah}).toList(),
      });
      final data = response.data['data'];
      final id = data['id'] as String;
      final pesanan = Pesanan(
        id: id,
        pemesanId: pemesanId,
        tanggalPesan: DateTime.tryParse(data['tanggal_pesan']?.toString() ?? '') ?? DateTime.now(),
        tanggalJatuhTempo: tanggalJatuhTempo,
        catatan: catatan,
        syncStatus: 'synced',
        updatedAt: DateTime.tryParse(data['updated_at']?.toString() ?? '') ?? DateTime.now(),
      );

      await db.transaction((txn) async {
        await txn.insert('pesanan', pesanan.toMap());
        for (final item in items) {
          await txn.insert('pesanan_detail', {
            'id': _uuid.v4(),
            'pesanan_id': id,
            'produk_id': item.produkId,
            'jumlah': item.jumlah,
          });
        }
      });
      return pesanan;
    } catch (_) {
      final id = _uuid.v4();
      final pesanan = Pesanan(
        id: id,
        pemesanId: pemesanId,
        tanggalPesan: DateTime.now(),
        tanggalJatuhTempo: tanggalJatuhTempo,
        catatan: catatan,
      );

      await db.transaction((txn) async {
        await txn.insert('pesanan', pesanan.toMap());
        for (final item in items) {
          await txn.insert('pesanan_detail', {
            'id': _uuid.v4(),
            'pesanan_id': id,
            'produk_id': item.produkId,
            'jumlah': item.jumlah,
          });
        }
      });
      return pesanan;
    }
  }

  Future<void> updateStatus(String id, {bool? statusSelesai, bool? statusLunas}) async {
    final db = await AppDatabase.instance.database;
    try {
      final response = await ApiClient.instance.dio.patch('/pesanan/$id/status', data: {
        if (statusSelesai != null) 'status_selesai': statusSelesai,
        if (statusLunas != null) 'status_lunas': statusLunas,
      });
      final data = response.data['data'];
      final values = <String, dynamic>{
        'sync_status': 'synced',
        'updated_at': data['updated_at']?.toString() ?? DateTime.now().toIso8601String(),
      };
      if (statusSelesai != null) values['status_selesai'] = statusSelesai ? 1 : 0;
      if (statusLunas != null) values['status_lunas'] = statusLunas ? 1 : 0;
      await db.update('pesanan', values, where: 'id = ?', whereArgs: [id]);
    } catch (_) {
      final values = <String, dynamic>{'sync_status': 'pending', 'updated_at': DateTime.now().toIso8601String()};
      if (statusSelesai != null) values['status_selesai'] = statusSelesai ? 1 : 0;
      if (statusLunas != null) values['status_lunas'] = statusLunas ? 1 : 0;
      await db.update('pesanan', values, where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<void> delete(String id) async {
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      await txn.delete('pesanan_detail', where: 'pesanan_id = ?', whereArgs: [id]);
      await txn.delete('pesanan', where: 'id = ?', whereArgs: [id]);
    });
    try {
      await ApiClient.instance.dio.delete('/pesanan/$id');
    } catch (_) {
      // Best-effort, sama seperti ProdukRepository.delete.
    }
  }

  /// Mengambil daftar pesanan (+ detail item) dari server dan menimpa data
  /// lokal (dipakai saat login, supaya data tidak kosong walau sebelumnya
  /// sempat logout yang mengosongkan DB lokal).
  Future<void> replaceFromServer(List<dynamic> serverItems) async {
    final db = await AppDatabase.instance.database;
    final batch = db.batch();
    for (final item in serverItems) {
      final pesanan = Pesanan(
        id: item['id'],
        pemesanId: item['pemesan_id'],
        tanggalPesan: DateTime.tryParse(item['tanggal_pesan']?.toString() ?? '') ?? DateTime.now(),
        tanggalJatuhTempo: DateTime.tryParse(item['tanggal_jatuh_tempo']?.toString() ?? '') ?? DateTime.now(),
        statusSelesai: item['status_selesai'] == true,
        statusLunas: item['status_lunas'] == true,
        catatan: item['catatan'],
        syncStatus: 'synced',
        updatedAt: DateTime.tryParse(item['updated_at']?.toString() ?? '') ?? DateTime.now(),
      );
      batch.insert('pesanan', pesanan.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

      final detailItems = (item['items'] as List<dynamic>? ?? const []);
      for (final detail in detailItems) {
        batch.insert(
          'pesanan_detail',
          {
            'id': detail['id'],
            'pesanan_id': item['id'],
            'produk_id': detail['produk_id'],
            'jumlah': detail['jumlah'],
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
    await batch.commit(noResult: true);
  }
}

class PemesanRepository {
  final _uuid = const Uuid();

  Future<List<Pemesan>> getAll() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('pemesan', orderBy: 'nama_pemesan ASC');
    return rows.map(Pemesan.fromMap).toList();
  }

  /// Dikirim ke server dulu supaya id yang dipakai konsisten dengan id yang
  /// dirujuk oleh Pesanan (foreign key di backend), baru dicache lokal.
  Future<Pemesan> create({required String namaPemesan, String? noWhatsapp}) async {
    final db = await AppDatabase.instance.database;
    try {
      final response = await ApiClient.instance.dio.post('/pemesan', data: {
        'nama_pemesan': namaPemesan,
        'no_whatsapp': noWhatsapp,
      });
      final data = response.data['data'];
      final pemesan = Pemesan(
        id: data['id'],
        namaPemesan: data['nama_pemesan'],
        noWhatsapp: data['no_whatsapp'],
        syncStatus: 'synced',
      );
      await db.insert('pemesan', pemesan.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      return pemesan;
    } catch (_) {
      final pemesan = Pemesan(id: _uuid.v4(), namaPemesan: namaPemesan, noWhatsapp: noWhatsapp);
      await db.insert('pemesan', pemesan.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      return pemesan;
    }
  }

  /// Mengambil daftar pemesan dari server dan menimpa data lokal (dipakai saat login).
  Future<void> replaceFromServer(List<dynamic> serverItems) async {
    final db = await AppDatabase.instance.database;
    final batch = db.batch();
    for (final item in serverItems) {
      final pemesan = Pemesan(
        id: item['id'],
        namaPemesan: item['nama_pemesan'],
        noWhatsapp: item['no_whatsapp'],
        syncStatus: 'synced',
      );
      batch.insert('pemesan', pemesan.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }
}
