import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../screens/profile/profile_screen.dart';
import 'profile_avatar.dart';

/// Avatar profil di pojok kanan atas AppBar; tap membuka layar Profil.
class ProfileAction extends StatelessWidget {
  const ProfileAction({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkResponse(
        radius: 24,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
        child: Tooltip(
          message: 'Profil',
          child: ProfileAvatar(radius: 17, fotoUrl: auth.fotoUrl, nama: auth.namaUsaha),
        ),
      ),
    );
  }
}
