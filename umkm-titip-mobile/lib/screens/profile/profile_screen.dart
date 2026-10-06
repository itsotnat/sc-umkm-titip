import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/profile_avatar.dart';
import 'edit_profile_screen.dart';
import 'ganti_password_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _pilihFoto(BuildContext context, ImageSource source) async {
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Dikompres di HP dulu (maks 1024 px, kualitas 80) supaya upload ringan.
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (picked == null) return;
      final error = await auth.ubahFoto(picked.path);
      messenger.showSnackBar(SnackBar(content: Text(error ?? 'Foto profil diperbarui')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Tidak bisa membuka kamera/galeri.')));
    }
  }

  Future<void> _hapusFoto(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final error = await auth.hapusFoto();
    messenger.showSnackBar(SnackBar(content: Text(error ?? 'Foto profil dihapus')));
  }

  void _tampilkanPilihan(BuildContext context) {
    final adaFoto = context.read<AuthProvider>().fotoUrl != null;
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Ambil foto'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pilihFoto(context, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari galeri'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pilihFoto(context, ImageSource.gallery);
              },
            ),
            if (adaFoto)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Hapus foto', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _hapusFoto(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: GestureDetector(
              onTap: auth.isUploadingFoto ? null : () => _tampilkanPilihan(context),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ProfileAvatar(radius: 56, fotoUrl: auth.fotoUrl, nama: auth.namaUsaha),
                  if (auth.isUploadingFoto)
                    Container(
                      width: 112,
                      height: 112,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black38),
                      child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                    ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: auth.isUploadingFoto ? null : () => _tampilkanPilihan(context),
              child: const Text('Ubah foto profil'),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.storefront_outlined),
                  title: const Text('Nama Usaha'),
                  subtitle: Text(auth.namaUsaha ?? '-'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Nama Pemilik'),
                  subtitle: Text(auth.namaPemilik ?? '-'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('Email'),
                  subtitle: Text(auth.email ?? '-'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditProfileScreen())),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Ubah profil'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GantiPasswordScreen())),
            icon: const Icon(Icons.lock_outline),
            label: const Text('Ganti password'),
          ),
        ],
      ),
    );
  }
}
