import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../models/pemesan.dart';
import '../models/pesanan.dart';
import '../models/pesanan_detail.dart';

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

  /// Membuat pesanan header + detail dalam satu transaksi lokal (atomic),
  /// sesuai dokumen SDD Bagian 3 (Flow Tambah Pesanan).
  Future<Pesanan> create({
    required String pemesanId,
    required DateTime tanggalJatuhTempo,
    required List<({String produkId, int jumlah})> items,
    String? catatan,
  }) async {
    final db = await AppDatabase.instance.database;
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

  Future<void> updateStatus(String id, {bool? statusSelesai, bool? statusLunas}) async {
    final db = await AppDatabase.instance.database;
    final values = <String, dynamic>{'sync_status': 'pending', 'updated_at': DateTime.now().toIso8601String()};
    if (statusSelesai != null) values['status_selesai'] = statusSelesai ? 1 : 0;
    if (statusLunas != null) values['status_lunas'] = statusLunas ? 1 : 0;
    await db.update('pesanan', values, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> delete(String id) async {
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      await txn.delete('pesanan_detail', where: 'pesanan_id = ?', whereArgs: [id]);
      await txn.delete('pesanan', where: 'id = ?', whereArgs: [id]);
    });
  }
}

class PemesanRepository {
  final _uuid = const Uuid();

  Future<List<Pemesan>> getAll() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('pemesan', orderBy: 'nama_pemesan ASC');
    return rows.map(Pemesan.fromMap).toList();
  }

  Future<Pemesan> create({required String namaPemesan, String? noWhatsapp}) async {
    final pemesan = Pemesan(id: _uuid.v4(), namaPemesan: namaPemesan, noWhatsapp: noWhatsapp);
    final db = await AppDatabase.instance.database;
    await db.insert('pemesan', pemesan.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    return pemesan;
  }
}
