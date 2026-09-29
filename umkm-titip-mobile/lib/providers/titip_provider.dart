import 'package:flutter/foundation.dart';

import '../models/produk.dart';
import '../models/transaksi_titip.dart';
import '../repositories/titip_repository.dart';
import '../services/sync_manager.dart';

/// State untuk Bottom Sheet Input Harian Titip: menggabungkan daftar produk
/// dengan transaksi titip (bila sudah ada) untuk outlet & tanggal terpilih,
/// sesuai dokumen UI/UX Design Bagian 5.
class TitipInputRow {
  final Produk produk;
  int jumlahKirim;

  /// NULL = retur belum diinput sama sekali (beda dari 0 = sudah
  /// dikonfirmasi habis terjual/tidak ada retur).
  int? jumlahRetur;
  String? existingId;

  TitipInputRow({required this.produk, this.jumlahKirim = 0, this.jumlahRetur, this.existingId});

  /// NULL bila retur belum diinput (belum bisa dihitung).
  int? get terjual => jumlahRetur == null ? null : jumlahKirim - jumlahRetur!;
  double? get nilaiTerjual => terjual == null ? null : terjual! * produk.hargaJual;
}

class TitipProvider extends ChangeNotifier {
  final TitipRepository _repository = TitipRepository();

  Future<void> loadUntukOutlet(String outletId, DateTime tanggal, List<Produk> produkList, List<TitipInputRow> target) async {
    final existing = await _repository.getByOutletDanTanggal(outletId, tanggal);
    target
      ..clear()
      ..addAll(produkList.map((produk) {
        final match = existing.where((t) => t.produkId == produk.id).toList();
        if (match.isNotEmpty) {
          final t = match.first;
          return TitipInputRow(produk: produk, jumlahKirim: t.jumlahKirim, jumlahRetur: t.jumlahRetur, existingId: t.id);
        }
        return TitipInputRow(produk: produk);
      }));
  }

  Future<void> simpan(String outletId, DateTime tanggal, List<TitipInputRow> rows) async {
    for (final row in rows) {
      if (row.jumlahKirim == 0 && row.jumlahRetur == null && row.existingId == null) continue;
      await _repository.upsert(
        outletId: outletId,
        produkId: row.produk.id,
        tanggal: tanggal,
        jumlahKirim: row.jumlahKirim,
        jumlahRetur: row.jumlahRetur,
        existingId: row.existingId,
      );
    }
    // Coba sinkron langsung bila online; bila gagal/offline, akan dicoba lagi nanti.
    await SyncManager.instance.syncPendingTitip();
  }
}
