import 'package:flutter/material.dart';

/// Logo resmi aplikasi UMKM Titip (dari file yang dikirim tim, bukan ikon buatan).
///
/// Dipakai konsisten di tiga tempat:
/// - Layar Login (mark saja, `showLabel: false`)
/// - Layar loading/splash awal (mark + wordmark "UMKM TITIP", `showLabel: true`)
/// - AppBar setiap layar menu utama: Beranda, Master, Pesanan, Laporan, Akun
///   (mark kecil di leading AppBar, `showLabel: false`)
///
/// Dua aset dipakai:
/// - `assets/images/logo_icon.png`  -> mark rumah+kotak+tangan saja (persegi, cocok untuk AppBar kecil)
/// - `assets/images/logo_full.png`  -> mark + wordmark "UMKM TITIP" (dipakai saat butuh identitas lengkap)
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 72, this.showLabel = false});

  final double size;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    if (showLabel) {
      return Image.asset(
        'assets/images/logo_full.png',
        height: size * 1.75,
        fit: BoxFit.contain,
      );
    }
    return Image.asset(
      'assets/images/logo_icon.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
