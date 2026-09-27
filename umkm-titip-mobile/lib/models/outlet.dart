class Outlet {
  final String id;
  final String namaOutlet;
  final String? alamat;
  final String? noWhatsapp;
  final String syncStatus;
  final DateTime updatedAt;

  Outlet({
    required this.id,
    required this.namaOutlet,
    this.alamat,
    this.noWhatsapp,
    this.syncStatus = 'pending',
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama_outlet': namaOutlet,
      'alamat': alamat,
      'no_whatsapp': noWhatsapp,
      'sync_status': syncStatus,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Outlet.fromMap(Map<String, dynamic> map) {
    return Outlet(
      id: map['id'] as String,
      namaOutlet: map['nama_outlet'] as String,
      alamat: map['alamat'] as String?,
      noWhatsapp: map['no_whatsapp'] as String?,
      syncStatus: map['sync_status'] as String? ?? 'synced',
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
