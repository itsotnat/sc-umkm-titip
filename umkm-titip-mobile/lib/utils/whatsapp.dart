import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/pesanan.dart';
import '../widgets/format_utils.dart';

/// Menormalkan nomor WhatsApp ke format internasional yang dipakai wa.me
/// (mis. "0812..." atau "+62812..." -> "62812...").
String? normalisasiWhatsapp(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  var nomor = raw.replaceAll(RegExp(r'[^0-9+]'), '');
  if (nomor.startsWith('+')) nomor = nomor.substring(1);
  if (nomor.startsWith('0')) nomor = '62${nomor.substring(1)}';
  return nomor.isEmpty ? null : nomor;
}

/// Membuka chat WhatsApp ke [nomor]. [pesan] (opsional) diisikan otomatis di kolom ketik.
Future<void> bukaWhatsapp(BuildContext context, String? nomor, {String? pesan}) async {
  final normalized = normalisasiWhatsapp(nomor);
  if (normalized == null) return;
  final uri = Uri.parse('https://wa.me/$normalized').replace(
    queryParameters: (pesan != null && pesan.isNotEmpty) ? {'text': pesan} : null,
  );
  var berhasil = false;
  try {
    berhasil = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!berhasil && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tidak bisa membuka WhatsApp. Pastikan WhatsApp terpasang di HP ini.')),
    );
  }
}

/// Teks pembuka chat untuk pemesan: mengingatkan pesanan (dan pembayaran bila belum lunas).
String pesanUntukPesanan(Pesanan p) {
  final item = p.items.map((i) => '${i.namaProduk ?? ''} x${i.jumlah}').where((t) => t.trim() != 'x').join(', ');
  final buffer = StringBuffer('Halo ${p.namaPemesan ?? ''}, ');
  buffer.write(item.isEmpty ? 'mengingatkan pesanan Anda' : 'mengingatkan pesanan Anda ($item)');
  buffer.write(' yang jatuh tempo pada ${formatTanggal(p.tanggalJatuhTempo)}.');
  if (!p.statusLunas) buffer.write(' Mohon konfirmasi pembayarannya ya. Terima kasih.');
  return buffer.toString();
}
