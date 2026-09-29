class TransaksiTitip {
  final String id;
  final String outletId;
  final String produkId;
  final DateTime tanggal;
  final int jumlahKirim;

  /// NULL berarti retur belum diinput sama sekali (beda dari 0, yang berarti
  /// sudah dikonfirmasi habis terjual/tidak ada retur).
  final int? jumlahRetur;
  final String syncStatus;
  final DateTime updatedAt;

  TransaksiTitip({
    required this.id,
    required this.outletId,
    required this.produkId,
    required this.tanggal,
    required this.jumlahKirim,
    this.jumlahRetur,
    this.syncStatus = 'pending',
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  /// terjual = kirim - retur, sesuai formula di dokumen SDD Bagian 4.
  /// NULL bila retur belum diinput (belum bisa dihitung).
  int? get jumlahTerjual => jumlahRetur == null ? null : jumlahKirim - jumlahRetur!;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'outlet_id': outletId,
      'produk_id': produkId,
      'tanggal': tanggal.toIso8601String().substring(0, 10),
      'jumlah_kirim': jumlahKirim,
      'jumlah_retur': jumlahRetur,
      'sync_status': syncStatus,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory TransaksiTitip.fromMap(Map<String, dynamic> map) {
    return TransaksiTitip(
      id: map['id'] as String,
      outletId: map['outlet_id'] as String,
      produkId: map['produk_id'] as String,
      tanggal: DateTime.parse(map['tanggal'] as String),
      jumlahKirim: map['jumlah_kirim'] as int,
      jumlahRetur: map['jumlah_retur'] as int?,
      syncStatus: map['sync_status'] as String? ?? 'synced',
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
