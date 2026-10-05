import 'package:flutter/material.dart';

import '../utils/constants.dart';

/// Avatar bulat: foto dari server, atau inisial nama usaha kalau belum ada
/// foto / sedang offline dan foto belum sempat termuat.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.radius, this.fotoUrl, this.nama});

  final double radius;
  final String? fotoUrl;
  final String? nama;

  String get _inisial {
    final n = (nama ?? '').trim();
    return n.isEmpty ? '?' : n.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = AppConfig.mediaUrl(fotoUrl);
    final size = radius * 2;

    final fallback = Center(
      child: Text(
        _inisial,
        style: TextStyle(fontSize: radius * 0.9, fontWeight: FontWeight.w600, color: scheme.onPrimaryContainer),
      ),
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.primaryContainer),
      clipBehavior: Clip.antiAlias,
      child: url == null
          ? fallback
          : Image.network(
              url,
              key: ValueKey(url),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
            ),
    );
  }
}
