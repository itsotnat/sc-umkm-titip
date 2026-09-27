/// Logika kalkulasi otomatis, sesuai formula di dokumen SDD Bagian 4.
/// Dipanggil langsung dari UI (murni komputasi lokal, tanpa perlu API),
/// sesuai dokumen SDD Bagian 3 (Flow Input Harian Titip).
class CalculationService {
  static int hitungTerjual(int kirim, int retur) => kirim - retur;

  static double hitungNilaiTerjual(int terjual, double hargaJual) => terjual * hargaJual;

  static double hitungUntungRugi(int kirim, int terjual, double hargaJual, double hpp) {
    return (terjual * hargaJual) - (kirim * hpp);
  }

  /// Mengembalikan sell-through rate (0-100) dan status Laris/Standar/Kurang,
  /// sesuai ambang batas di dokumen SDD Bagian 4.
  static ({double rate, String status}) hitungStatus(int totalTerjual, int totalKirim) {
    if (totalKirim == 0) return (rate: 0, status: 'Belum Ada Data');
    final rate = (totalTerjual / totalKirim) * 100;
    final String status;
    if (rate >= 80) {
      status = 'Laris';
    } else if (rate >= 50) {
      status = 'Standar';
    } else {
      status = 'Kurang';
    }
    return (rate: rate, status: status);
  }
}
