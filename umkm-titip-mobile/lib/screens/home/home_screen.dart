import 'package:flutter/material.dart';

import '../laporan/laporan_screen.dart';
import '../master/master_tab_screen.dart';
import '../pesanan/pesanan_list_screen.dart';
import 'akun_screen.dart';
import 'dashboard_screen.dart';

/// Shell dengan Bottom Navigation Bar (5 tab), sesuai dokumen UI/UX Design Bagian 4.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  static const _tabs = [
    DashboardScreen(),
    MasterTabScreen(),
    PesananListScreen(),
    LaporanScreen(),
    AkunScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Master'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Pesanan'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Laporan'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Akun'),
        ],
      ),
    );
  }
}
