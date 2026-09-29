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

  /// True kalau ada baris titip di rentang ini yang retur-nya belum diinput
  /// — artinya angka terjual/nilai/untung-rugi di atas masih provisional
  /// (belum menghitung baris yang belum lengkap itu).
  final bool adaReturBelumDiinput;

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
    this.adaReturBelumDiinput = false,
  });
}

/// Rekap Pesanan untuk kartu Laporan. `totalNilaiLunas` hanya menjumlahkan
/// nilai pesanan yang statusnya sudah Lunas (kesepakatan: pesanan baru
/// dihitung sebagai "penjualan" begitu uangnya sudah diterima).
class PesananRekap {
  final int totalPesanan;
  final int totalSelesai;
  final int totalBelumSelesai;
  final int totalLunas;
  final int totalBelumLunas;
  final double totalNilaiLunas;

  PesananRekap({
    required this.totalPesanan,
    required this.totalSelesai,
    required this.totalBelumSelesai,
    required this.totalLunas,
    required this.totalBelumLunas,
    required this.totalNilaiLunas,
  });

  factory PesananRekap.kosong() => PesananRekap(
        totalPesanan: 0,
        totalSelesai: 0,
        totalBelumSelesai: 0,
        totalLunas: 0,
        totalBelumLunas: 0,
        totalNilaiLunas: 0,
      );
}

/// Menghitung laporan Titip Outlet langsung dari data lokal (SQLite),
/// sesuai catatan di dokumen REST API Spec Bagian 7: versi MVP boleh
/// menghitung laporan langsung dari data lokal tanpa perlu API laporan.
class LaporanProvider extends ChangeNotifier {
  List<LaporanOutletRow> rows = [];
  bool isLoading = false;

  PesananRekap rekapPesanan = PesananRekap.kosong();
  bool isLoadingPesanan = false;

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

      int totalKirim = 0; // semua kirim, termasuk baris yang retur-nya belum diinput
      int totalKirimTerkonfirmasi = 0; // basis sell-through: hanya baris yang retur-nya sudah diisi
      int totalRetur = 0;
      int totalTerjual = 0;
      double totalNilai = 0;
      double totalUntungRugi = 0;
      bool adaReturBelumDiinput = false;

      for (final row in transaksi) {
        final kirim = row['jumlah_kirim'] as int;
        final retur = row['jumlah_retur'] as int?;
        totalKirim += kirim;

        if (retur == null) {
          // Retur belum diinput: kirim sudah pasti terjadi jadi tetap
          // dihitung di totalKirim, tapi terjual/nilai/untung-rugi belum
          // bisa dihitung dari baris ini.
          adaReturBelumDiinput = true;
          continue;
        }

        final hargaJual = (row['harga_jual'] as num).toDouble();
        final hpp = (row['hpp'] as num).toDouble();
        final terjual = CalculationService.hitungTerjual(kirim, retur);

        totalKirimTerkonfirmasi += kirim;
        totalRetur += retur;
        totalTerjual += terjual;
        totalNilai += CalculationService.hitungNilaiTerjual(terjual, hargaJual);
        totalUntungRugi += CalculationService.hitungUntungRugi(kirim, terjual, hargaJual, hpp);
      }

      final statusResult = CalculationService.hitungStatus(totalTerjual, totalKirimTerkonfirmasi);

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
        adaReturBelumDiinput: adaReturBelumDiinput,
      ));
    }

    // Urutkan agar outlet dengan status "Kurang" mudah terlihat sekilas,
    // sesuai dokumen UI/UX Design Bagian 8.
    result.sort((a, b) => a.sellThroughRate.compareTo(b.sellThroughRate));

    rows = result;
    isLoading = false;
    notifyListeners();
  }

  /// Rekap Pesanan (menu terpisah dari Titip Outlet di Laporan): jumlah
  /// pesanan selesai/belum & lunas/belum, plus total nilai penjualan yang
  /// sudah Lunas, dihitung langsung dari data lokal (sama seperti
  /// [hitungTitipOutlet]) supaya tetap bisa dilihat walau sedang offline.
  Future<void> hitungPesanan(DateTime dari, DateTime sampai) async {
    isLoadingPesanan = true;
    notifyListeners();

    final db = await AppDatabase.instance.database;
    final dariStr = dari.toIso8601String().substring(0, 10);
    final sampaiStr = sampai.toIso8601String().substring(0, 10);

    final headers = await db.query(
      'pesanan',
      where: 'tanggal_jatuh_tempo BETWEEN ? AND ?',
      whereArgs: [dariStr, sampaiStr],
    );

    int totalSelesai = 0;
    int totalBelumSelesai = 0;
    int totalLunas = 0;
    int totalBelumLunas = 0;
    double totalNilaiLunas = 0;

    for (final header in headers) {
      final selesai = header['status_selesai'] == 1 || header['status_selesai'] == true;
      final lunas = header['status_lunas'] == 1 || header['status_lunas'] == true;
      if (selesai) {
        totalSelesai++;
      } else {
        totalBelumSelesai++;
      }

      if (lunas) {
        totalLunas++;
        final items = await db.rawQuery(
          '''
          SELECT pd.jumlah, p.harga_jual
          FROM pesanan_detail pd
          JOIN produk p ON p.id = pd.produk_id
          WHERE pd.pesanan_id = ?
          ''',
          [header['id']],
        );
        for (final item in items) {
          final jumlah = item['jumlah'] as int;
          final hargaJual = (item['harga_jual'] as num).toDouble();
          totalNilaiLunas += jumlah * hargaJual;
        }
      } else {
        totalBelumLunas++;
      }
    }

    rekapPesanan = PesananRekap(
      totalPesanan: headers.length,
      totalSelesai: totalSelesai,
      totalBelumSelesai: totalBelumSelesai,
      totalLunas: totalLunas,
      totalBelumLunas: totalBelumLunas,
      totalNilaiLunas: totalNilaiLunas,
    );
    isLoadingPesanan = false;
    notifyListeners();
  }
}
