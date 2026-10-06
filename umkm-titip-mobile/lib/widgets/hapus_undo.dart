import 'package:flutter/material.dart';

/// Hapus dengan kesempatan "Batalkan" selama beberapa detik.
///
/// Item langsung disembunyikan dari daftar ([sembunyikan]); penghapusan sebenarnya
/// ([hapusPermanen]) baru dijalankan setelah SnackBar tertutup tanpa dibatalkan.
/// Bila pengguna menekan "Batalkan", item dikembalikan lewat [pulihkan] dan
/// tidak ada yang terhapus.
void hapusDenganUndo(
  BuildContext context, {
  required String pesan,
  required VoidCallback sembunyikan,
  required VoidCallback pulihkan,
  required Future<void> Function() hapusPermanen,
}) {
  final messenger = ScaffoldMessenger.of(context);
  sembunyikan();
  messenger.hideCurrentSnackBar();
  var dibatalkan = false;
  messenger
      .showSnackBar(
        SnackBar(
          content: Text(pesan),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Batalkan',
            onPressed: () {
              dibatalkan = true;
              pulihkan();
            },
          ),
        ),
      )
      .closed
      .then((_) {
    if (!dibatalkan) hapusPermanen();
  });
}
