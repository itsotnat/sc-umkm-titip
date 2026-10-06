import 'package:flutter_test/flutter_test.dart';
import 'package:umkm_titip/models/pesanan.dart';
import 'package:umkm_titip/models/pesanan_detail.dart';
import 'package:umkm_titip/utils/whatsapp.dart';

void main() {
  group('normalisasiWhatsapp', () {
    test('awalan 0 diganti 62', () => expect(normalisasiWhatsapp('0812-3456 7890'), '6281234567890'));
    test('awalan +62 dibuang tandanya', () => expect(normalisasiWhatsapp('+62 812 3456 7890'), '6281234567890'));
    test('sudah 62 dibiarkan', () => expect(normalisasiWhatsapp('6281234567890'), '6281234567890'));
    test('kosong menghasilkan null', () {
      expect(normalisasiWhatsapp(null), isNull);
      expect(normalisasiWhatsapp('   '), isNull);
    });
  });

  group('pesanUntukPesanan', () {
    Pesanan buat({required bool lunas}) => Pesanan(
          id: 'p1',
          pemesanId: 'm1',
          namaPemesan: 'Bu Sari',
          tanggalPesan: DateTime(2026, 10, 1),
          tanggalJatuhTempo: DateTime(2026, 10, 10),
          statusLunas: lunas,
          items: [PesananDetail(id: 'd1', pesananId: 'p1', produkId: 'x', jumlah: 10, namaProduk: 'Lemper')],
        );

    test('belum lunas: menyertakan permintaan konfirmasi pembayaran', () {
      final pesan = pesanUntukPesanan(buat(lunas: false));
      expect(pesan, contains('Bu Sari'));
      expect(pesan, contains('Lemper x10'));
      expect(pesan, contains('konfirmasi pembayaran'));
    });

    test('sudah lunas: tanpa permintaan pembayaran', () {
      expect(pesanUntukPesanan(buat(lunas: true)), isNot(contains('pembayaran')));
    });
  });
}
