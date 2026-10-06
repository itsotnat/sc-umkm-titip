import 'package:flutter/material.dart';

import '../utils/theme.dart';

/// Badge status berwarna (Laris/Standar/Kurang, Lunas/Belum Lunas, dst.),
/// sesuai dokumen UI/UX Design Bagian 2.
class StatusBadge extends StatelessWidget {
  final String label;

  const StatusBadge({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(label);
    // Kuning terlalu pucat sebagai warna teks di atas latar kuning muda (kontras rendah),
    // jadi teksnya memakai kuning-cokelat tua; warna bingkai/latar tetap kuning.
    final teks = color == AppColors.kuning ? const Color(0xFF8A5A00) : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: teks, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}
