class Produk {
  final String id;
  final String namaProduk;
  final double hpp;
  final double hargaJual;
  final String syncStatus;
  final DateTime updatedAt;

  Produk({
    required this.id,
    required this.namaProduk,
    required this.hpp,
    required this.hargaJual,
    this.syncStatus = 'pending',
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Produk copyWith({
    String? namaProduk,
    double? hpp,
    double? hargaJual,
    String? syncStatus,
  }) {
    return Produk(
      id: id,
      namaProduk: namaProduk ?? this.namaProduk,
      hpp: hpp ?? this.hpp,
      hargaJual: hargaJual ?? this.hargaJual,
      syncStatus: syncStatus ?? this.syncStatus,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama_produk': namaProduk,
      'hpp': hpp,
      'harga_jual': hargaJual,
      'sync_status': syncStatus,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Produk.fromMap(Map<String, dynamic> map) {
    return Produk(
      id: map['id'] as String,
      namaProduk: map['nama_produk'] as String,
      hpp: (map['hpp'] as num).toDouble(),
      hargaJual: (map['harga_jual'] as num).toDouble(),
      syncStatus: map['sync_status'] as String? ?? 'synced',
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
