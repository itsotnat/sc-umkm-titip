import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/pesanan_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/format_utils.dart';
import '../../widgets/status_badge.dart';
import 'pesanan_form_screen.dart';

/// Daftar Pesanan, sesuai dokumen UI/UX Design Bagian 7.
class PesananListScreen extends StatefulWidget {
  const PesananListScreen({super.key});

  @override
  State<PesananListScreen> createState() => _PesananListScreenState();
}

class _PesananListScreenState extends State<PesananListScreen> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      context.read<PesananProvider>().load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PesananProvider>();

    return DefaultTabController(
      length: 3,
      initialIndex: 0,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pesanan'),
          bottom: TabBar(
            tabs: const [Tab(text: 'Semua'), Tab(text: 'Belum Selesai'), Tab(text: 'Selesai')],
            onTap: (index) {
              provider.setFilter(['semua', 'belum_selesai', 'selesai'][index]);
            },
          ),
        ),
        body: provider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : provider.items.isEmpty
                ? const EmptyState(icon: Icons.receipt_long_outlined, message: 'Belum ada pesanan.')
                : RefreshIndicator(
                    onRefresh: provider.load,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: provider.items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final pesanan = provider.items[index];
                        final ringkasan = pesanan.items.map((i) => '${i.namaProduk ?? ''} x${i.jumlah}').join(', ');

                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: pesanan.jatuhTempoLewat
                                ? const BorderSide(color: Colors.red, width: 1.2)
                                : BorderSide.none,
                          ),
                          child: ListTile(
                            title: Text(pesanan.namaPemesan ?? '-', style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(ringkasan.isEmpty ? '-' : ringkasan, maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Text('Jatuh tempo: ${formatTanggal(pesanan.tanggalJatuhTempo)}', style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                GestureDetector(
                                  onTap: () => provider.toggleSelesai(pesanan.id, !pesanan.statusSelesai),
                                  child: StatusBadge(label: pesanan.statusSelesai ? 'Selesai' : 'Menunggu'),
                                ),
                                const SizedBox(height: 4),
                                GestureDetector(
                                  onTap: () => provider.toggleLunas(pesanan.id, !pesanan.statusLunas),
                                  child: StatusBadge(label: pesanan.statusLunas ? 'Lunas' : 'Belum Lunas'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PesananFormScreen())),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
