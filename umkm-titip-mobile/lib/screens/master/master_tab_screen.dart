import 'package:flutter/material.dart';

import '../../widgets/app_bar_brand.dart';
import '../../widgets/profile_action.dart';
import 'outlet_screen.dart';
import 'produk_screen.dart';

/// Kedua layar Master (Produk & Outlet) berpola sama, sehingga digabung
/// dalam satu tab dengan sub-tab, sesuai dokumen UI/UX Design Bagian 6.
class MasterTabScreen extends StatelessWidget {
  const MasterTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const AppBarBrand(label: 'Master'),
          actions: const [ProfileAction()],
          bottom: const TabBar(tabs: [Tab(text: 'Produk'), Tab(text: 'Outlet')]),
        ),
        body: const TabBarView(children: [ProdukScreen(), OutletScreen()]),
      ),
    );
  }
}
