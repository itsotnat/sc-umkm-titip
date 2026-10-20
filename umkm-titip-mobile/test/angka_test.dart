import 'package:flutter_test/flutter_test.dart';
import 'package:umkm_titip/utils/angka.dart';

void main() {
  group('keDouble', () {
    test('menerima angka', () {
      expect(keDouble(5000), 5000.0);
      expect(keDouble(2500.5), 2500.5);
    });

    test('menerima teks desimal dari PostgreSQL', () {
      expect(keDouble('5000.00'), 5000.0);
      expect(keDouble('0.00'), 0.0);
      expect(keDouble('12500'), 12500.0);
    });

    test('teks bukan angka melempar error', () {
      expect(() => keDouble('abc'), throwsFormatException);
    });
  });
}
