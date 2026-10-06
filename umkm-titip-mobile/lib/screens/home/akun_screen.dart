import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/sync_manager.dart';
import '../../widgets/app_bar_brand.dart';
import '../../widgets/profile_action.dart';
import '../../widgets/profile_avatar.dart';
import '../profile/profile_screen.dart';

class AkunScreen extends StatelessWidget {
  const AkunScreen({super.key});

  /// Mencoba mengirim data tertunda dulu. Kalau masih ada yang belum terkirim
  /// (mis. offline), minta konfirmasi: data lokal dihapus saat keluar.
  Future<void> _keluar(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final sync = SyncManager.instance;

    await sync.syncAll();
    final sisa = await sync.countPending();
    if (sisa > 0 && context.mounted) {
      final yakin = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ada data belum tersinkron'),
          content: Text(
            '$sisa data belum terkirim ke server dan akan HILANG jika Anda keluar sekarang. '
            'Sambungkan internet dulu agar data terkirim, atau tetap keluar?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Tetap keluar', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (yakin != true) return;
    }
    await auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const AppBarBrand(label: 'Akun'), actions: const [ProfileAction()]),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: ProfileAvatar(radius: 24, fotoUrl: auth.fotoUrl, nama: auth.namaUsaha),
              title: Text(auth.namaUsaha ?? 'UMKM Titip'),
              subtitle: Text(auth.email ?? 'Kelola akun dan sinkronisasi'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
            ),
            const Divider(),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _keluar(context),
              icon: const Icon(Icons.logout),
              label: const Text('Keluar'),
            ),
          ],
        ),
      ),
    );
  }
}
