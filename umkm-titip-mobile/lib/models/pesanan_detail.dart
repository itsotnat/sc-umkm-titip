class PesananDetail {
  final String id;
  final String pesananId;
  final String produkId;
  final int jumlah;
  final String? namaProduk;

  PesananDetail({
    required this.id,
    required this.pesananId,
    required this.produkId,
    required this.jumlah,
    this.namaProduk,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pesanan_id': pesananId,
      'produk_id': produkId,
      'jumlah': jumlah,
    };
  }

  factory PesananDetail.fromMap(Map<String, dynamic> map) {
    return PesananDetail(
      id: map['id'] as String,
      pesananId: map['pesanan_id'] as String,
      produkId: map['produk_id'] as String,
      jumlah: map['jumlah'] as int,
      namaProduk: map['nama_produk'] as String?,
    );
  }
}
