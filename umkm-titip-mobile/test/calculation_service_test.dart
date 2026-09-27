import 'package:flutter_test/flutter_test.dart';
import 'package:umkm_titip/services/calculation_service.dart';

void main() {
  group('CalculationService', () {
    test('hitungTerjual = kirim - retur', () {
      expect(CalculationService.hitungTerjual(20, 5), 15);
    });

    test('hitungNilaiTerjual = terjual * hargaJual', () {
      expect(CalculationService.hitungNilaiTerjual(15, 3500), 52500);
    });

    test('hitungUntungRugi memperhitungkan HPP dari seluruh barang yang dikirim', () {
      // (15 * 3500) - (20 * 2000) = 52500 - 40000 = 12500
      expect(CalculationService.hitungUntungRugi(20, 15, 3500, 2000), 12500);
    });

    test('status Laris untuk sell-through rate >= 80%', () {
      final result = CalculationService.hitungStatus(16, 20); // 80%
      expect(result.status, 'Laris');
    });

    test('status Standar untuk sell-through rate 50%-79.99%', () {
      final result = CalculationService.hitungStatus(15, 20); // 75%
      expect(result.status, 'Standar');
    });

    test('status Kurang untuk sell-through rate < 50%', () {
      final result = CalculationService.hitungStatus(5, 20); // 25%
      expect(result.status, 'Kurang');
    });

    test('status Belum Ada Data bila total kirim 0', () {
      final result = CalculationService.hitungStatus(0, 0);
      expect(result.status, 'Belum Ada Data');
    });
  });
}
