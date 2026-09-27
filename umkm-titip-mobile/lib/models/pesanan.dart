import 'pesanan_detail.dart';

class Pesanan {
  final String id;
  final String pemesanId;
  final String? namaPemesan;
  final DateTime tanggalPesan;
  final DateTime tanggalJatuhTempo;
  final bool statusSelesai;
  final bool statusLunas;
  final String? catatan;
  final String syncStatus;
  final DateTime updatedAt;
  final List<PesananDetail> items;

  Pesanan({
    required this.id,
    required this.pemesanId,
    this.namaPemesan,
    required this.tanggalPesan,
    required this.tanggalJatuhTempo,
    this.statusSelesai = false,
    this.statusLunas = false,
    this.catatan,
    this.syncStatus = 'pending',
    DateTime? updatedAt,
    this.items = const [],
  }) : updatedAt = updatedAt ?? DateTime.now();

  bool get jatuhTempoLewat => !statusSelesai && tanggalJatuhTempo.isBefore(DateTime.now());

  Pesanan copyWith({bool? statusSelesai, bool? statusLunas, String? syncStatus}) {
    return Pesanan(
      id: id,
      pemesanId: pemesanId,
      namaPemesan: namaPemesan,
      tanggalPesan: tanggalPesan,
      tanggalJatuhTempo: tanggalJatuhTempo,
      statusSelesai: statusSelesai ?? this.statusSelesai,
      statusLunas: statusLunas ?? this.statusLunas,
      catatan: catatan,
      syncStatus: syncStatus ?? this.syncStatus,
      updatedAt: DateTime.now(),
      items: items,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pemesan_id': pemesanId,
      'tanggal_pesan': tanggalPesan.toIso8601String().substring(0, 10),
      'tanggal_jatuh_tempo': tanggalJatuhTempo.toIso8601String().substring(0, 10),
      'status_selesai': statusSelesai ? 1 : 0,
      'status_lunas': statusLunas ? 1 : 0,
      'catatan': catatan,
      'sync_status': syncStatus,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Pesanan.fromMap(Map<String, dynamic> map, {List<PesananDetail> items = const []}) {
    return Pesanan(
      id: map['id'] as String,
      pemesanId: map['pemesan_id'] as String,
      namaPemesan: map['nama_pemesan'] as String?,
      tanggalPesan: DateTime.parse(map['tanggal_pesan'] as String),
      tanggalJatuhTempo: DateTime.parse(map['tanggal_jatuh_tempo'] as String),
      statusSelesai: (map['status_selesai'] == 1 || map['status_selesai'] == true),
      statusLunas: (map['status_lunas'] == 1 || map['status_lunas'] == true),
      catatan: map['catatan'] as String?,
      syncStatus: map['sync_status'] as String? ?? 'synced',
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ?? DateTime.now(),
      items: items,
    );
  }
}
