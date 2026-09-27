class Pemesan {
  final String id;
  final String namaPemesan;
  final String? noWhatsapp;
  final String syncStatus;

  Pemesan({
    required this.id,
    required this.namaPemesan,
    this.noWhatsapp,
    this.syncStatus = 'pending',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama_pemesan': namaPemesan,
      'no_whatsapp': noWhatsapp,
      'sync_status': syncStatus,
    };
  }

  factory Pemesan.fromMap(Map<String, dynamic> map) {
    return Pemesan(
      id: map['id'] as String,
      namaPemesan: map['nama_pemesan'] as String,
      noWhatsapp: map['no_whatsapp'] as String?,
      syncStatus: map['sync_status'] as String? ?? 'synced',
    );
  }
}
