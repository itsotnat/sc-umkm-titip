import 'package:flutter/material.dart';

import 'app_logo.dart';

/// Judul AppBar berbentuk "Logo | Nama Menu", dipakai konsisten di kelima
/// layar menu utama (Beranda, Master, Pesanan, Laporan, Akun).
class AppBarBrand extends StatelessWidget {
  const AppBarBrand({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppLogo(size: 28),
        const SizedBox(width: 10),
        Container(width: 1, height: 22, color: Theme.of(context).dividerColor),
        const SizedBox(width: 10),
        Text(label),
      ],
    );
  }
}
