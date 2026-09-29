import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/laporan_provider.dart';
import '../../widgets/app_bar_brand.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/format_utils.dart';
import '../../widgets/status_badge.dart';
import 'export_service.dart';

enum _QuickRange { hariIni, mingguIni, bulanIni, custom }

/// Laporan Titip Outlet, sesuai dokumen UI/UX Design Bagian 8.
class LaporanScreen extends StatefulWidget {
  const LaporanScreen({super.key});

  @override
  State<LaporanScreen> createState() => _LaporanScreenState();
}

class _LaporanScreenState extends State<LaporanScreen> with SingleTickerProviderStateMixin {
  _QuickRange _range = _QuickRange.bulanIni;
  late DateTime _dari;
  late DateTime _sampai;
  late TabController _tabController;
  bool _loaded = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dari = DateTime(now.year, now.month, 1);
    _sampai = DateTime(now.year, now.month + 1, 0);
    _tabController = TabController(length: 2, vsync: this);
    // Supaya tombol export (khusus Titip Outlet) muncul/hilang sesuai tab aktif.
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _muatUlang();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  /// Memuat rekap Titip Outlet dan rekap Pesanan sekaligus, karena keduanya
  /// berbagi satu rentang tanggal yang sama (chip Hari Ini/Minggu Ini/dst di atas).
  Future<void> _muatUlang() async {
    final provider = context.read<LaporanProvider>();
    await Future.wait([
      provider.hitungTitipOutlet(_dari, _sampai),
      provider.hitungPesanan(_dari, _sampai),
    ]);
  }

  void _pilihQuickRange(_QuickRange range) {
    final now = DateTime.now();
    setState(() {
      _range = range;
      switch (range) {
        case _QuickRange.hariIni:
          _dari = DateTime(now.year, now.month, now.day);
          _sampai = _dari;
          break;
        case _QuickRange.mingguIni:
          _dari = now.subtract(Duration(days: now.weekday - 1));
          _sampai = _dari.add(const Duration(days: 6));
          break;
        case _QuickRange.bulanIni:
          _dari = DateTime(now.year, now.month, 1);
          _sampai = DateTime(now.year, now.month + 1, 0);
          break;
        case _QuickRange.custom:
          break;
      }
    });
    if (range != _QuickRange.custom) _muatUlang();
  }

  Future<void> _pilihCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _dari, end: _sampai),
    );
    if (picked != null) {
      setState(() {
        _range = _QuickRange.custom;
        _dari = picked.start;
        _sampai = picked.end;
      });
      _muatUlang();
    }
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final rows = context.read<LaporanProvider>().rows;
      final path = await ExportService.exportTitipOutletToExcel(rows, _dari, _sampai);
      if (mounted) {
        await ExportService.shareFile(path);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal export: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LaporanProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const AppBarBrand(label: 'Laporan'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Titip Outlet'), Tab(text: 'Pesanan')],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(label: const Text('Hari Ini'), selected: _range == _QuickRange.hariIni, onSelected: (_) => _pilihQuickRange(_QuickRange.hariIni)),
                    ChoiceChip(label: const Text('Minggu Ini'), selected: _range == _QuickRange.mingguIni, onSelected: (_) => _pilihQuickRange(_QuickRange.mingguIni)),
                    ChoiceChip(label: const Text('Bulan Ini'), selected: _range == _QuickRange.bulanIni, onSelected: (_) => _pilihQuickRange(_QuickRange.bulanIni)),
                    ActionChip(
                      label: Text(_range == _QuickRange.custom ? '${formatTanggal(_dari)} - ${formatTanggal(_sampai)}' : 'Custom'),
                      onPressed: _pilihCustomRange,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTabTitipOutlet(provider),
                _buildTabPesanan(provider),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          final tampilkanExport = _tabController.index == 0 && !provider.isLoading && provider.rows.isNotEmpty;
          if (!tampilkanExport) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: _exporting ? null : _export,
            icon: _exporting
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.file_download_outlined),
            label: const Text('Export ke Excel'),
          );
        },
      ),
    );
  }

  Widget _buildTabTitipOutlet(LaporanProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.rows.isEmpty) {
      return const EmptyState(icon: Icons.bar_chart_outlined, message: 'Belum ada data pada rentang tanggal ini.');
    }
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _RingkasanChart(rows: provider.rows),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            itemCount: provider.rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final row = provider.rows[index];
              return Card(
                child: ListTile(
                  title: Text(row.namaOutlet, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    'Kirim ${row.totalKirim} · Retur ${row.totalRetur} · Terjual ${row.totalTerjual}\n'
                    '${formatRupiah(row.totalNilaiTerjual)} · Untung/Rugi ${formatRupiah(row.totalUntungRugi)}'
                    '${row.adaReturBelumDiinput ? '\nAda retur yang belum diinput, angka masih sementara' : ''}',
                  ),
                  isThreeLine: true,
                  trailing: StatusBadge(label: row.status),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Rekap Pesanan: nilai penjualan dihitung hanya dari pesanan yang sudah
  /// Lunas (lihat catatan di [LaporanProvider.hitungPesanan]).
  Widget _buildTabPesanan(LaporanProvider provider) {
    if (provider.isLoadingPesanan) {
      return const Center(child: CircularProgressIndicator());
    }
    final rekap = provider.rekapPesanan;
    if (rekap.totalPesanan == 0) {
      return const EmptyState(icon: Icons.receipt_long_outlined, message: 'Belum ada pesanan pada rentang tanggal ini.');
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      children: [
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Penjualan Pesanan (Lunas)', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 4),
                Text(
                  formatRupiah(rekap.totalNilaiLunas),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _StatTile(label: 'Lunas', value: '${rekap.totalLunas}', color: Colors.green)),
            const SizedBox(width: 8),
            Expanded(child: _StatTile(label: 'Belum Lunas', value: '${rekap.totalBelumLunas}', color: Colors.orange)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _StatTile(label: 'Selesai', value: '${rekap.totalSelesai}', color: Colors.blue)),
            const SizedBox(width: 8),
            Expanded(child: _StatTile(label: 'Belum Selesai', value: '${rekap.totalBelumSelesai}', color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Total ${rekap.totalPesanan} pesanan pada rentang tanggal ini. Nilai penjualan di atas hanya menghitung pesanan yang sudah ditandai Lunas.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _RingkasanChart extends StatelessWidget {
  final List<LaporanOutletRow> rows;

  const _RingkasanChart({required this.rows});

  @override
  Widget build(BuildContext context) {
    final data = rows.take(6).toList();
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= data.length) return const SizedBox.shrink();
                final nama = data[i].namaOutlet;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(nama.length > 8 ? '${nama.substring(0, 8)}...' : nama, style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        barGroups: [
          for (int i = 0; i < data.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(toY: data[i].totalTerjual.toDouble(), color: Theme.of(context).colorScheme.primary, width: 18, borderRadius: BorderRadius.circular(4)),
            ]),
        ],
      ),
    );
  }
}
