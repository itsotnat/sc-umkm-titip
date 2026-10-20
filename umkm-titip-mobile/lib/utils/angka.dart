/// Mengubah nilai dari server menjadi double. PostgreSQL mengirim kolom DECIMAL
/// sebagai teks (mis. "5000.00"), sedangkan JSON biasa berupa angka.
double keDouble(dynamic nilai) {
  if (nilai is num) return nilai.toDouble();
  return double.parse(nilai.toString());
}
