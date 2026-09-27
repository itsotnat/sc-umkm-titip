import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/laporan_provider.dart';
import 'providers/outlet_provider.dart';
import 'providers/pesanan_provider.dart';
import 'providers/produk_provider.dart';
import 'providers/titip_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'utils/theme.dart';

void main() {
  runApp(const UmkmTitipApp());
}

class UmkmTitipApp extends StatelessWidget {
  const UmkmTitipApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..checkSession()),
        ChangeNotifierProvider(create: (_) => ProdukProvider()),
        ChangeNotifierProvider(create: (_) => OutletProvider()),
        ChangeNotifierProvider(create: (_) => PesananProvider()),
        ChangeNotifierProvider(create: (_) => LaporanProvider()),
        ChangeNotifierProvider(create: (_) => TitipProvider()),
      ],
      child: MaterialApp(
        title: 'UMKM Titip',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const RootRouter(),
      ),
    );
  }
}

/// Menentukan layar awal berdasarkan status login (dokumen UI/UX Design Bagian 3).
class RootRouter extends StatelessWidget {
  const RootRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        switch (auth.status) {
          case AuthStatus.unknown:
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          case AuthStatus.loggedOut:
            return const LoginScreen();
          case AuthStatus.loggedIn:
            return const HomeScreen();
        }
      },
    );
  }
}
