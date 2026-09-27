import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/outlet.dart';
import '../../providers/laporan_provider.dart';
import '../../providers/outlet_provider.dart';
import '../../providers/pesanan_provider.dart';
import '../../providers/produk_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/format_utils.dart';
import '../titip/titip_input_sheet.dart';

/// Beranda (Dashboard), sesuai dokumen UI/UX Design Bagian 4.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _loadAll();
    }
  }

  Future<void> _loadAll() async {
    final today = DateTime.now();
    await Future.wait([
      context.read<OutletProvider>().load(),
      context.read<ProdukProvider>().load(),
      context.read<PesananProvider>().load(),
      context.read<LaporanProvider>().hitungTitipOutlet(
            DateTime(today.year, today.month, 1),
            DateTime(today.year, today.month + 1, 0),
          ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final outletProvider = context.watch<OutletProvider>();
    final pesananProvider = context.watch<PesananProvider>();
    final laporanProvider = context.watch<LaporanProvider>();
    final produkProvider = context.watch<ProdukProvider>();

    final totalKirimBulanIni = laporanProvider.rows.fold<int>(0, (s, r) => s + r.totalKirim);
    final totalNilaiTerjual = laporanProvider.rows.fold<double>(0, (s, r) => s + r.totalNilaiTerjual);
    final outletBelumInput = outletProvider.items.length; // disederhanakan: bisa dikembangkan mengecek input hari ini
    final pesananJatuhTempo = pesananProvider.items.where((p) => !p.statusSelesai).take(5).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('UMKM Titip')),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SizedBox(
              height: 96,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _SummaryCard(title: 'Total Kirim (bulan ini)', value: '$totalKirimBulanIni pcs'),
                  const SizedBox(width: 12),
                  _SummaryCard(title: 'Total Terjual (Rp)', value: formatRupiah(totalNilaiTerjual)),
                  const SizedBox(width: 12),
                  _SummaryCard(title: 'Jumlah Outlet', value: '$outletBelumInput'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Outlet Hari Ini', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (outletProvider.items.isEmpty)
              const EmptyState(icon: Icons.storefront_outlined, message: 'Belum ada outlet, tambahkan outlet pertamamu di menu Master.')
            else
              ...outletProvider.items.map((outlet) => _OutletCard(
                    outlet: outlet,
                    onTap: produkProvider.items.isEmpty
                        ? null
                        : () => showTitipInputSheet(context, outlet: outlet, tanggal: DateTime.now()),
                  )),
            const SizedBox(height: 24),
            Text('Pesanan Jatuh Tempo', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (pesananJatuhTempo.isEmpty)
              const EmptyState(icon: Icons.receipt_long_outlined, message: 'Belum ada pesanan yang perlu diselesaikan.')
            else
              ...pesananJatuhTempo.map((p) => ListTile(
                    dense: true,
                    leading: Icon(Icons.circle, size: 10, color: p.jatuhTempoLewat ? Colors.red : Colors.grey),
                    title: Text(p.namaPemesan ?? '-'),
                    subtitle: Text('Jatuh tempo: ${formatTanggal(p.tanggalJatuhTempo)}'),
                  )),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;

  const _SummaryCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _OutletCard extends StatelessWidget {
  final Outlet outlet;
  final VoidCallback? onTap;

  const _OutletCard({required this.outlet, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.storefront)),
        title: Text(outlet.namaOutlet),
        subtitle: Text(outlet.alamat?.isNotEmpty == true ? outlet.alamat! : 'Ketuk untuk input titip hari ini'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
