import 'dart:io';

import 'package:excel/excel.dart' as excel_lib;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart' show Share, XFile;

import '../../providers/laporan_provider.dart';
import '../../widgets/format_utils.dart';

/// Mengonversi hasil agregasi laporan menjadi file .xlsx, sesuai dokumen
/// SDD Bagian 3 (ExportService), disimpan ke penyimpanan lokal lalu dibagikan.
class ExportService {
  static Future<String> exportTitipOutletToExcel(List<LaporanOutletRow> rows, DateTime dari, DateTime sampai) async {
    final workbook = excel_lib.Excel.createExcel();
    final sheet = workbook['Laporan Titip Outlet'];
    workbook.setDefaultSheet('Laporan Titip Outlet');

    final headers = ['Outlet', 'Total Kirim', 'Total Retur', 'Total Terjual', 'Nilai Terjual', 'Untung/Rugi', 'Sell-Through Rate (%)', 'Status'];
    sheet.appendRow(headers.map((h) => excel_lib.TextCellValue(h)).toList());

    for (final row in rows) {
      sheet.appendRow([
        excel_lib.TextCellValue(row.namaOutlet),
        excel_lib.IntCellValue(row.totalKirim),
        excel_lib.IntCellValue(row.totalRetur),
        excel_lib.IntCellValue(row.totalTerjual),
        excel_lib.DoubleCellValue(row.totalNilaiTerjual),
        excel_lib.DoubleCellValue(row.totalUntungRugi),
        excel_lib.DoubleCellValue(row.sellThroughRate),
        excel_lib.TextCellValue(row.status),
      ]);
    }

    final bytes = workbook.encode();
    if (bytes == null) throw Exception('Gagal membuat file Excel');

    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'laporan-titip-outlet-${formatTanggal(dari)}-${formatTanggal(sampai)}.xlsx'
        .replaceAll(' ', '-')
        .replaceAll('/', '-');
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  static Future<void> shareFile(String path) async {
    // Menggunakan Share.shareXFiles (API stabil share_plus versi 7-9.x).
    // Bila proyek di-upgrade ke share_plus versi lebih baru yang menghapus
    // API statis ini, ganti ke SharePlus.instance.share(ShareParams(...)).
    await Share.shareXFiles([XFile(path)], text: 'Laporan Titip Outlet - UMKM Titip');
  }
}
