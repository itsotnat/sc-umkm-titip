import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../models/outlet.dart';
import '../../models/transaksi_titip.dart';
import '../../providers/laporan_provider.dart';
import '../../providers/outlet_provider.dart';
import '../../providers/pesanan_provider.dart';
import '../../providers/produk_provider.dart';
import '../../repositories/titip_repository.dart';
import '../../widgets/app_bar_brand.dart';
import '../../services/sync_manager.dart';
import '../../utils/whatsapp.dart';
import '../../widgets/profile_action.dart';
import '../../widgets/sync_status_banner.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/format_utils.dart';
import '../../widgets/status_badge.dart';
import '../titip/titip_input_sheet.dart';

/// Label pengingat hitung mundur untuk pesanan yang belum lewat tanggal
/// jatuh tempo (yang sudah lewat tidak lagi ditampilkan di Beranda, lihat
/// [_DashboardScreenState._loadAll] & filter di [_DashboardScreenState.build]).
String _labelPengingat(DateTime tanggalJatuhTempo) {
  final sekarang = DateTime.now();
  final hariIni = DateTime(sekarang.year, sekarang.month, sekarang.day);
  final tempo = DateTime(tanggalJatuhTempo.year, tanggalJatuhTempo.month, tanggalJatuhTempo.day);
  final selisih = tempo.difference(hariIni).inDays;
  if (selisih <= 0) return 'Hari Ini';
  if (selisih == 1) return 'Besok';
  return 'H-$selisih';
}

/// Beranda (Dashboard), sesuai dokumen UI/UX Design Bagian 4.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TitipRepository _titipRepository = TitipRepository();
  bool _loaded = false;

  /// Transaksi titip hari ini per outlet, dipakai untuk badge
  /// "Tidak Dikirim" / "Retur Belum Diinput" / "Sudah Diinput" di kartu outlet.
  Map<String, List<TransaksiTitip>> _titipHariIni = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _loadAll();
    }
  }

  Future<void> _loadAll() async {
    // Kirim dulu perubahan yang tertunda, supaya data yang dimuat ulang sudah mutakhir.
    await SyncManager.instance.syncAll();
    if (!mounted) return;
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
    await _muatTitipHariIni();
  }

  /// Dipanggil setelah daftar outlet dimuat, supaya tahu outlet mana yang
  /// sudah/belum di-input hari ini.
  Future<void> _muatTitipHariIni() async {
    final outlets = context.read<OutletProvider>().items;
    final hasil = <String, List<TransaksiTitip>>{};
    for (final outlet in outlets) {
      hasil[outlet.id] = await _titipRepository.getByOutletDanTanggal(outlet.id, DateTime.now());
    }
    if (mounted) setState(() => _titipHariIni = hasil);
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
    // Pesanan yang statusnya sudah lewat tanggal jatuh tempo sengaja tidak
    // ditampilkan di sini lagi (hilang dari Beranda), tapi tetap ada di menu
    // Pesanan dan tetap dihitung di Laporan (progress & keuangan).
    final pesananJatuhTempo = pesananProvider.semuaItems.where((p) => !p.statusSelesai && !p.jatuhTempoLewat).take(5).toList();

    return Scaffold(
      appBar: AppBar(title: const AppBarBrand(label: 'Beranda'), actions: const [ProfileAction()]),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SyncStatusBanner(),
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
                    transaksiHariIni: _titipHariIni[outlet.id] ?? const [],
                    onTap: produkProvider.items.isEmpty
                        ? null
                        : () => showTitipInputSheet(context, outlet: outlet, tanggal: DateTime.now()).then((_) => _muatTitipHariIni()),
                  )),
            const SizedBox(height: 24),
            Text('Pesanan Jatuh Tempo', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (pesananJatuhTempo.isEmpty)
              const EmptyState(icon: Icons.receipt_long_outlined, message: 'Belum ada pesanan yang perlu diselesaikan.')
            else
              ...pesananJatuhTempo.map((p) {
                final ringkasan = p.items.map((i) => '${i.namaProduk ?? ''} x${i.jumlah}').join(', ');
                return ListTile(
                  dense: true,
                  title: Text(p.namaPemesan ?? '-', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    ringkasan.isEmpty ? 'Jatuh tempo: ${formatTanggal(p.tanggalJatuhTempo)}' : ringkasan,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StatusBadge(label: _labelPengingat(p.tanggalJatuhTempo)),
                      if ((p.noWhatsapp ?? '').trim().isNotEmpty)
                        IconButton(
                          icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green),
                          tooltip: 'Chat ${p.namaPemesan ?? 'pemesan'} lewat WhatsApp',
                          onPressed: () => bukaWhatsapp(context, p.noWhatsapp, pesan: pesanUntukPesanan(p)),
                        ),
                    ],
                  ),
                );
              }),
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
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
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
  final List<TransaksiTitip> transaksiHariIni;

  const _OutletCard({required this.outlet, required this.onTap, required this.transaksiHariIni});

  @override
  Widget build(BuildContext context) {
    // 3 kemungkinan status hari ini:
    // - belum ada baris sama sekali -> Tidak Dikirim (outlet ini memang tidak dikirimi hari ini)
    // - ada baris kirim, tapi ada yang retur-nya masih kosong -> Retur Belum Diinput
    // - semua baris kirim sudah ada angka retur-nya (termasuk 0) -> Sudah Diinput
    final returBelumLengkap = transaksiHariIni.any((t) => t.jumlahRetur == null);
    final dikirim = transaksiHariIni.isNotEmpty;
    final label = !dikirim ? 'Tidak Dikirim' : (returBelumLengkap ? 'Retur Belum Diinput' : 'Sudah Diinput');

    // Tampilan minimal: nama outlet di atas (lebar penuh, tidak terjepit badge),
    // badge status kecil di bawahnya.
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.storefront)),
        title: Text(
          outlet.namaOutlet,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: StatusBadge(label: label),
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
