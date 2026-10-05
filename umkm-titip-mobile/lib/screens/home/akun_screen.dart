import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/app_bar_brand.dart';
import '../../widgets/profile_action.dart';
import '../../widgets/profile_avatar.dart';
import '../profile/profile_screen.dart';

class AkunScreen extends StatelessWidget {
  const AkunScreen({super.key});

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
              onPressed: () => context.read<AuthProvider>().logout(),
              icon: const Icon(Icons.logout),
              label: const Text('Keluar'),
            ),
          ],
        ),
      ),
    );
  }
}
