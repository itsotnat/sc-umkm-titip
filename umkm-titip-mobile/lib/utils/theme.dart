import 'package:flutter/material.dart';

/// Design system dasar aplikasi, sesuai dokumen UI/UX Design Bagian 2.
class AppColors {
  static const hijau = Color(0xFF2E7D32); // Laris, Lunas, Selesai, tombol utama
  static const kuning = Color(0xFFF9A825); // Standar, menunggu
  static const merah = Color(0xFFD32F2F); // Kurang, belum lunas, peringatan
  static const abuNetral = Color(0xFF757575); // teks sekunder, border
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorSchemeSeed: AppColors.hijau,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.hijau,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}

/// Warna badge status Laris/Standar/Kurang dan Lunas/Belum, sesuai Bagian 2.
Color statusColor(String status) {
  switch (status) {
    case 'Laris':
    case 'Lunas':
    case 'Selesai':
    case 'Sudah Diinput':
    case 'Besok':
      return AppColors.hijau;
    case 'Standar':
    case 'Menunggu':
    case 'Hari Ini':
    case 'Retur Belum Diinput':
      return AppColors.kuning;
    case 'Kurang':
    case 'Belum Lunas':
      return AppColors.merah;
    // "Tidak Dikirim" sengaja netral (abu-abu), bukan merah: ini bukan
    // pekerjaan yang belum selesai, cuma outlet yang memang tidak
    // dikirimi hari itu.
    case 'Tidak Dikirim':
    default:
      return AppColors.abuNetral;
  }
}
