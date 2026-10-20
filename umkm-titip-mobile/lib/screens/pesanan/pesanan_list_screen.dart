import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../providers/pesanan_provider.dart';
import '../../models/pesanan.dart';
import '../../utils/whatsapp.dart';
import '../../widgets/app_bar_brand.dart';
import '../../widgets/search_field.dart';
import '../../widgets/profile_action.dart';
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
  String _query = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      context.read<PesananProvider>().load();
    }
  }

  bool _cocok(Pesanan p) {
    if ((p.namaPemesan ?? '').toLowerCase().contains(_query)) return true;
    return p.items.any((i) => (i.namaProduk ?? '').toLowerCase().contains(_query));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PesananProvider>();
    final daftar = _query.isEmpty ? provider.items : provider.items.where(_cocok).toList();

    return DefaultTabController(
      length: 3,
      initialIndex: 0,
      child: Scaffold(
        appBar: AppBar(
          title: const AppBarBrand(label: 'Pesanan'),
          actions: const [ProfileAction()],
          bottom: TabBar(
            labelPadding: const EdgeInsets.symmetric(horizontal: 6),
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            tabs: const [
              Tab(child: Text('Semua', maxLines: 1, softWrap: false)),
              Tab(child: Text('Belum Selesai', maxLines: 1, softWrap: false)),
              Tab(child: Text('Selesai', maxLines: 1, softWrap: false)),
            ],
            onTap: (index) {
              provider.setFilter(['semua', 'belum_selesai', 'selesai'][index]);
            },
          ),
        ),
        body: (provider.isLoading && provider.items.isEmpty)
            ? const Center(child: CircularProgressIndicator())
            : provider.items.isEmpty
                ? const EmptyState(icon: Icons.receipt_long_outlined, message: 'Belum ada pesanan.')
                : Column(
                    children: [
                      SearchField(
                        hint: 'Cari pemesan atau produk',
                        onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                      ),
                      Expanded(
                        child: daftar.isEmpty
                            ? const EmptyState(icon: Icons.search_off, message: 'Tidak ada pesanan yang cocok.')
                            : RefreshIndicator(
                                onRefresh: provider.load,
                                child: ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                                  itemCount: daftar.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (context, index) => _PesananCard(pesanan: daftar[index]),
                                ),
                              ),
                      ),
                    ],
                  ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PesananFormScreen())),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class _PesananCard extends StatelessWidget {
  final Pesanan pesanan;

  const _PesananCard({required this.pesanan});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<PesananProvider>();
    final ringkasan = pesanan.items.map((i) => '${i.namaProduk ?? ''} x${i.jumlah}').join(', ');
    final adaWa = (pesanan.noWhatsapp ?? '').trim().isNotEmpty;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: pesanan.jatuhTempoLewat ? const BorderSide(color: Colors.red, width: 1.2) : BorderSide.none,
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (adaWa)
              IconButton(
                icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green),
                tooltip: 'Chat ${pesanan.namaPemesan ?? 'pemesan'} lewat WhatsApp',
                onPressed: () => bukaWhatsapp(context, pesanan.noWhatsapp, pesan: pesanUntukPesanan(pesanan)),
              ),
            FittedBox(
              // Mencegah overflow beberapa pixel saat dua badge status ditumpuk vertikal
              // di ruang trailing yang sempit (ukuran font perangkat berbeda).
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Semantics(
                    button: true,
                    label: pesanan.statusSelesai ? 'Tandai belum selesai' : 'Tandai selesai',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => provider.toggleSelesai(pesanan.id, !pesanan.statusSelesai),
                      child: StatusBadge(label: pesanan.statusSelesai ? 'Selesai' : 'Menunggu'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Semantics(
                    button: true,
                    label: pesanan.statusLunas ? 'Tandai belum lunas' : 'Tandai lunas',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => provider.toggleLunas(pesanan.id, !pesanan.statusLunas),
                      child: StatusBadge(label: pesanan.statusLunas ? 'Lunas' : 'Belum Lunas'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
