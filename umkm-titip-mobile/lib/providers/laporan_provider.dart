import 'package:flutter/foundation.dart';

import '../db/app_database.dart';
import '../services/calculation_service.dart';

class LaporanOutletRow {
  final String outletId;
  final String namaOutlet;
  final int totalKirim;
  final int totalRetur;
  final int totalTerjual;
  final double totalNilaiTerjual;
  final double totalUntungRugi;
  final double sellThroughRate;
  final String status;

  LaporanOutletRow({
    required this.outletId,
    required this.namaOutlet,
    required this.totalKirim,
    required this.totalRetur,
    required this.totalTerjual,
    required this.totalNilaiTerjual,
    required this.totalUntungRugi,
    required this.sellThroughRate,
    required this.status,
  });
}

/// Menghitung laporan Titip Outlet langsung dari data lokal (SQLite),
/// sesuai catatan di dokumen REST API Spec Bagian 7: versi MVP boleh
/// menghitung laporan langsung dari data lokal tanpa perlu API laporan.
class LaporanProvider extends ChangeNotifier {
  List<LaporanOutletRow> rows = [];
  bool isLoading = false;

  Future<void> hitungTitipOutlet(DateTime dari, DateTime sampai) async {
    isLoading = true;
    notifyListeners();

    final db = await AppDatabase.instance.database;
    final dariStr = dari.toIso8601String().substring(0, 10);
    final sampaiStr = sampai.toIso8601String().substring(0, 10);

    final outlets = await db.query('outlet');
    final result = <LaporanOutletRow>[];

    for (final outlet in outlets) {
      final transaksi = await db.rawQuery(
        '''
        SELECT t.jumlah_kirim, t.jumlah_retur, p.harga_jual, p.hpp
        FROM transaksi_titip t
        JOIN produk p ON p.id = t.produk_id
        WHERE t.outlet_id = ? AND t.tanggal BETWEEN ? AND ?
        ''',
        [outlet['id'], dariStr, sampaiStr],
      );

      int totalKirim = 0;
      int totalRetur = 0;
      double totalNilai = 0;
      double totalUntungRugi = 0;

      for (final row in transaksi) {
        final kirim = row['jumlah_kirim'] as int;
        final retur = row['jumlah_retur'] as int;
        final hargaJual = (row['harga_jual'] as num).toDouble();
        final hpp = (row['hpp'] as num).toDouble();
        final terjual = CalculationService.hitungTerjual(kirim, retur);

        totalKirim += kirim;
        totalRetur += retur;
        totalNilai += CalculationService.hitungNilaiTerjual(terjual, hargaJual);
        totalUntungRugi += CalculationService.hitungUntungRugi(kirim, terjual, hargaJual, hpp);
      }

      final totalTerjual = totalKirim - totalRetur;
      final statusResult = CalculationService.hitungStatus(totalTerjual, totalKirim);

      result.add(LaporanOutletRow(
        outletId: outlet['id'] as String,
        namaOutlet: outlet['nama_outlet'] as String,
        totalKirim: totalKirim,
        totalRetur: totalRetur,
        totalTerjual: totalTerjual,
        totalNilaiTerjual: totalNilai,
        totalUntungRugi: totalUntungRugi,
        sellThroughRate: statusResult.rate,
        status: statusResult.status,
      ));
    }

    // Urutkan agar outlet dengan status "Kurang" mudah terlihat sekilas,
    // sesuai dokumen UI/UX Design Bagian 8.
    result.sort((a, b) => a.sellThroughRate.compareTo(b.sellThroughRate));

    rows = result;
    isLoading = false;
    notifyListeners();
  }
}
