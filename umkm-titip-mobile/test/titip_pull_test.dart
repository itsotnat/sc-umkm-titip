import 'package:flutter_test/flutter_test.dart';
import 'package:umkm_titip/repositories/titip_repository.dart';

void main() {
  group('TitipRepository.tanggalDariServer', () {
    test('tanggal polos dipakai apa adanya', () {
      expect(TitipRepository.tanggalDariServer('2026-10-05'), '2026-10-05');
    });

    test('ISO tengah malam UTC (server UTC) tetap di tanggal yang sama pada WIB', () {
      final offset = DateTime.now().timeZoneOffset;
      // Hanya berlaku untuk zona waktu UTC sampai UTC+12 (termasuk WIB).
      if (offset.isNegative) return;
      expect(TitipRepository.tanggalDariServer('2026-10-05T00:00:00.000Z'), '2026-10-05');
    });

    test('ISO 17:00 UTC (server WIB) tidak bergeser ke hari sebelumnya pada WIB', () {
      // Tes ini hanya bermakna di perangkat/PC berzona waktu WIB (UTC+7).
      if (DateTime.now().timeZoneOffset != const Duration(hours: 7)) return;
      expect(TitipRepository.tanggalDariServer('2026-10-04T17:00:00.000Z'), '2026-10-05');
    });
  });
}
