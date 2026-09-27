import 'package:intl/intl.dart';

final _rupiahFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
final _tanggalFormat = DateFormat('d MMM yyyy', 'id_ID');

String formatRupiah(num value) => _rupiahFormat.format(value);

String formatTanggal(DateTime date) {
  try {
    return _tanggalFormat.format(date);
  } catch (_) {
    // Fallback bila locale id_ID belum diinisialisasi.
    return '${date.day}/${date.month}/${date.year}';
  }
}
