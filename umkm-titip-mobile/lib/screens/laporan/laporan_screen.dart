import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/laporan_provider.dart';
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

class _LaporanScreenState extends State<LaporanScreen> {
  _QuickRange _range = _QuickRange.bulanIni;
  late DateTime _dari;
  late DateTime _sampai;
  bool _loaded = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dari = DateTime(now.year, now.month, 1);
    _sampai = DateTime(now.year, now.month + 1, 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _muatUlang();
    }
  }

  Future<void> _muatUlang() => context.read<LaporanProvider>().hitungTitipOutlet(_dari, _sampai);

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
      appBar: AppBar(title: const Text('Laporan')),
      body: Stack(
        children: [
          Column(
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
              if (!provider.isLoading && provider.rows.isNotEmpty)
                SizedBox(
                  height: 180,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _RingkasanChart(rows: provider.rows),
                  ),
                ),
              const SizedBox(height: 12),
              Expanded(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : provider.rows.isEmpty
                        ? const EmptyState(icon: Icons.bar_chart_outlined, message: 'Belum ada data pada rentang tanggal ini.')
                        : ListView.separated(
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
                                    '${formatRupiah(row.totalNilaiTerjual)} · Untung/Rugi ${formatRupiah(row.totalUntungRugi)}',
                                  ),
                                  isThreeLine: true,
                                  trailing: StatusBadge(label: row.status),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
          if (!provider.isLoading && provider.rows.isNotEmpty)
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.extended(
                onPressed: _exporting ? null : _export,
                icon: _exporting
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.file_download_outlined),
                label: const Text('Export ke Excel'),
              ),
            ),
        ],
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
