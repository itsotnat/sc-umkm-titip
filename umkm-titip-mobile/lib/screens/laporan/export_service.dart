import 'dart:io';

import 'package:excel/excel.dart' as excel_lib;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../db/app_database.dart';
import '../../providers/laporan_provider.dart';
import '../../services/calculation_service.dart';

/// Mengonversi laporan menjadi file .xlsx (Titip Outlet dan Pesanan), disimpan
/// ke penyimpanan lokal lalu dibagikan lewat share sheet (simpan ke Files /
/// Drive, kirim lewat WhatsApp, dsb). Data dibaca langsung dari SQLite lokal,
/// jadi tetap bisa diunduh saat offline.
class ExportService {
  // ---------------------------------------------------------------- helpers

  static String _tgl(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String _tglIso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// '2026-10-06' -> '06/10/2026'
  static String _tglDariIso(String iso) {
    final p = iso.split('-');
    return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : iso;
  }

  static excel_lib.TextCellValue _t(String s) => excel_lib.TextCellValue(s);

  static void _judul(excel_lib.Sheet sheet, String judul, DateTime dari, DateTime sampai) {
    sheet.appendRow([_t(judul)]);
    sheet.appendRow([_t('Periode: ${_tgl(dari)} - ${_tgl(sampai)}')]);
    sheet.appendRow([_t('Dibuat: ${_tgl(DateTime.now())}')]);
    sheet.appendRow([]);
    final bold = excel_lib.CellStyle(bold: true);
    sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = bold;
  }

  /// Menulis baris header (tebal) dan mengatur lebar kolom.
  static void _header(excel_lib.Sheet sheet, List<String> headers, List<double> widths) {
    final rowIndex = sheet.maxRows;
    sheet.appendRow(headers.map(_t).toList());
    final bold = excel_lib.CellStyle(bold: true);
    for (var c = 0; c < headers.length; c++) {
      sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIndex)).cellStyle = bold;
      sheet.setColumnWidth(c, widths[c]);
    }
  }

  static Future<String> _simpan(excel_lib.Excel workbook, String namaFile) async {
    final bytes = workbook.encode();
    if (bytes == null) throw Exception('Gagal membuat file Excel');
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$namaFile');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  static String _namaFile(String jenis, DateTime dari, DateTime sampai) =>
      'laporan-$jenis-${_tglIso(dari)}-sd-${_tglIso(sampai)}.xlsx';

  // ------------------------------------------------------------ Titip Outlet

  /// Sheet 1 "Rekap Outlet": ringkasan per outlet (sama seperti layar Laporan).
  /// Sheet 2 "Detail Harian": satu baris per transaksi titip pada rentang itu.
  static Future<String> exportTitipOutletToExcel(List<LaporanOutletRow> rows, DateTime dari, DateTime sampai) async {
    final workbook = excel_lib.Excel.createExcel();
    workbook.rename('Sheet1', 'Rekap Outlet');
    final rekap = workbook['Rekap Outlet'];

    _judul(rekap, 'Laporan Titip Outlet', dari, sampai);
    _header(
      rekap,
      ['Outlet', 'Total Kirim', 'Total Retur', 'Total Terjual', 'Nilai Terjual (Rp)', 'Untung/Rugi (Rp)', 'Sell-Through Rate (%)', 'Status', 'Catatan'],
      [28, 12, 12, 14, 18, 18, 20, 12, 34],
    );
    for (final row in rows) {
      rekap.appendRow([
        _t(row.namaOutlet),
        excel_lib.IntCellValue(row.totalKirim),
        excel_lib.IntCellValue(row.totalRetur),
        excel_lib.IntCellValue(row.totalTerjual),
        excel_lib.DoubleCellValue(row.totalNilaiTerjual),
        excel_lib.DoubleCellValue(row.totalUntungRugi),
        excel_lib.DoubleCellValue(double.parse(row.sellThroughRate.toStringAsFixed(1))),
        _t(row.status),
        _t(row.adaReturBelumDiinput ? 'Ada retur yang belum diinput (angka sementara)' : ''),
      ]);
    }
    rekap.appendRow([]);
    rekap.appendRow([
      _t('TOTAL'),
      excel_lib.IntCellValue(rows.fold(0, (s, r) => s + r.totalKirim)),
      excel_lib.IntCellValue(rows.fold(0, (s, r) => s + r.totalRetur)),
      excel_lib.IntCellValue(rows.fold(0, (s, r) => s + r.totalTerjual)),
      excel_lib.DoubleCellValue(rows.fold(0.0, (s, r) => s + r.totalNilaiTerjual)),
      excel_lib.DoubleCellValue(rows.fold(0.0, (s, r) => s + r.totalUntungRugi)),
    ]);
    final totalRow = rekap.maxRows - 1;
    final bold = excel_lib.CellStyle(bold: true);
    for (var c = 0; c < 6; c++) {
      rekap.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: totalRow)).cellStyle = bold;
    }

    // ---- Detail harian
    final db = await AppDatabase.instance.database;
    final detail = await db.rawQuery(
      '''
      SELECT t.tanggal, o.nama_outlet, p.nama_produk, p.harga_jual, p.hpp,
             t.jumlah_kirim, t.jumlah_retur
      FROM transaksi_titip t
      JOIN outlet o ON o.id = t.outlet_id
      JOIN produk p ON p.id = t.produk_id
      WHERE t.tanggal BETWEEN ? AND ?
      ORDER BY t.tanggal ASC, o.nama_outlet ASC, p.nama_produk ASC
      ''',
      [_tglIso(dari), _tglIso(sampai)],
    );
    final sheet2 = workbook['Detail Harian'];
    _judul(sheet2, 'Detail Harian Titip Outlet', dari, sampai);
    _header(
      sheet2,
      ['Tanggal', 'Outlet', 'Produk', 'Kirim', 'Retur', 'Terjual', 'Nilai Terjual (Rp)', 'Untung/Rugi (Rp)'],
      [14, 28, 26, 10, 10, 10, 18, 18],
    );
    for (final r in detail) {
      final kirim = r['jumlah_kirim'] as int;
      final retur = r['jumlah_retur'] as int?;
      final hargaJual = (r['harga_jual'] as num).toDouble();
      final hpp = (r['hpp'] as num).toDouble();
      if (retur == null) {
        // Retur belum diinput: terjual/nilai/untung-rugi belum bisa dihitung.
        sheet2.appendRow([_t(_tglDariIso(r['tanggal'] as String)), _t(r['nama_outlet'] as String), _t(r['nama_produk'] as String), excel_lib.IntCellValue(kirim), _t('belum diinput')]);
      } else {
        final terjual = CalculationService.hitungTerjual(kirim, retur);
        sheet2.appendRow([
          _t(_tglDariIso(r['tanggal'] as String)),
          _t(r['nama_outlet'] as String),
          _t(r['nama_produk'] as String),
          excel_lib.IntCellValue(kirim),
          excel_lib.IntCellValue(retur),
          excel_lib.IntCellValue(terjual),
          excel_lib.DoubleCellValue(CalculationService.hitungNilaiTerjual(terjual, hargaJual)),
          excel_lib.DoubleCellValue(CalculationService.hitungUntungRugi(kirim, terjual, hargaJual, hpp)),
        ]);
      }
    }

    return _simpan(workbook, _namaFile('titip-outlet', dari, sampai));
  }

  // ----------------------------------------------------------------- Pesanan

  /// Sheet 1 "Daftar Pesanan": satu baris per pesanan (rentang berdasarkan
  /// tanggal jatuh tempo, sama seperti rekap di layar Laporan).
  /// Sheet 2 "Rincian Item": satu baris per produk di tiap pesanan.
  static Future<String> exportPesananToExcel(DateTime dari, DateTime sampai) async {
    final db = await AppDatabase.instance.database;
    final headers = await db.rawQuery(
      '''
      SELECT ps.id, ps.tanggal_pesan, ps.tanggal_jatuh_tempo, ps.status_selesai, ps.status_lunas,
             ps.catatan, pm.nama_pemesan, pm.no_whatsapp
      FROM pesanan ps
      LEFT JOIN pemesan pm ON pm.id = ps.pemesan_id
      WHERE ps.tanggal_jatuh_tempo BETWEEN ? AND ?
      ORDER BY ps.tanggal_jatuh_tempo ASC, pm.nama_pemesan ASC
      ''',
      [_tglIso(dari), _tglIso(sampai)],
    );

    final workbook = excel_lib.Excel.createExcel();
    workbook.rename('Sheet1', 'Daftar Pesanan');
    final daftar = workbook['Daftar Pesanan'];
    final rincian = workbook['Rincian Item'];
    _judul(daftar, 'Laporan Pesanan', dari, sampai);
    _header(
      daftar,
      ['Tgl Pesan', 'Jatuh Tempo', 'Pemesan', 'No. WhatsApp', 'Item', 'Total Nilai (Rp)', 'Status Pesanan', 'Status Bayar', 'Catatan'],
      [13, 13, 24, 16, 40, 18, 16, 14, 30],
    );
    _judul(rincian, 'Rincian Item Pesanan', dari, sampai);
    _header(
      rincian,
      ['Jatuh Tempo', 'Pemesan', 'Produk', 'Jumlah', 'Harga Satuan (Rp)', 'Subtotal (Rp)'],
      [13, 24, 28, 10, 18, 18],
    );

    double totalSemua = 0;
    double totalLunas = 0;
    for (final h in headers) {
      final items = await db.rawQuery(
        '''
        SELECT p.nama_produk, p.harga_jual, pd.jumlah
        FROM pesanan_detail pd
        JOIN produk p ON p.id = pd.produk_id
        WHERE pd.pesanan_id = ?
        ORDER BY p.nama_produk ASC
        ''',
        [h['id']],
      );
      final selesai = h['status_selesai'] == 1 || h['status_selesai'] == true;
      final lunas = h['status_lunas'] == 1 || h['status_lunas'] == true;
      final pemesan = (h['nama_pemesan'] as String?) ?? '-';
      final jatuhTempo = _tglDariIso(h['tanggal_jatuh_tempo'] as String);

      double total = 0;
      final ringkasItem = <String>[];
      for (final it in items) {
        final jumlah = it['jumlah'] as int;
        final harga = (it['harga_jual'] as num).toDouble();
        total += jumlah * harga;
        ringkasItem.add('${it['nama_produk']} x$jumlah');
        rincian.appendRow([
          _t(jatuhTempo),
          _t(pemesan),
          _t(it['nama_produk'] as String),
          excel_lib.IntCellValue(jumlah),
          excel_lib.DoubleCellValue(harga),
          excel_lib.DoubleCellValue(jumlah * harga),
        ]);
      }
      totalSemua += total;
      if (lunas) totalLunas += total;

      daftar.appendRow([
        _t(_tglDariIso(h['tanggal_pesan'] as String)),
        _t(jatuhTempo),
        _t(pemesan),
        _t((h['no_whatsapp'] as String?) ?? ''),
        _t(ringkasItem.join(', ')),
        excel_lib.DoubleCellValue(total),
        _t(selesai ? 'Selesai' : 'Belum Selesai'),
        _t(lunas ? 'Lunas' : 'Belum Lunas'),
        _t((h['catatan'] as String?) ?? ''),
      ]);
    }

    daftar.appendRow([]);
    final bold = excel_lib.CellStyle(bold: true);
    daftar.appendRow([_t('Total semua pesanan'), _t(''), _t(''), _t(''), _t(''), excel_lib.DoubleCellValue(totalSemua)]);
    daftar.appendRow([_t('Total sudah lunas'), _t(''), _t(''), _t(''), _t(''), excel_lib.DoubleCellValue(totalLunas)]);
    for (var r = daftar.maxRows - 2; r < daftar.maxRows; r++) {
      for (var c = 0; c < 6; c++) {
        daftar.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r)).cellStyle = bold;
      }
    }

    return _simpan(workbook, _namaFile('pesanan', dari, sampai));
  }

  // ------------------------------------------------------------------ share

  static Future<void> shareFile(String path, {String text = 'Laporan - UMKM Titip'}) async {
    await SharePlus.instance.share(ShareParams(files: [XFile(path)], text: text));
  }
}
