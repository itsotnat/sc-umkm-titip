import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/outlet.dart';
import '../../providers/produk_provider.dart';
import '../../providers/titip_provider.dart';
import '../../widgets/format_utils.dart';

/// Bottom Sheet Input Harian Titip, sesuai dokumen UI/UX Design Bagian 5.
/// Layar yang paling sering dipakai (berkali-kali sehari), sehingga setiap
/// detik yang dihemat di sini berdampak besar ke pengalaman pengguna.
Future<void> showTitipInputSheet(BuildContext context, {required Outlet outlet, required DateTime tanggal}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => TitipInputSheet(outlet: outlet, tanggal: tanggal),
  );
}

class TitipInputSheet extends StatefulWidget {
  final Outlet outlet;
  final DateTime tanggal;

  const TitipInputSheet({super.key, required this.outlet, required this.tanggal});

  @override
  State<TitipInputSheet> createState() => _TitipInputSheetState();
}

class _TitipInputSheetState extends State<TitipInputSheet> {
  final List<TitipInputRow> _rows = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final produkProvider = context.read<ProdukProvider>();
    if (produkProvider.items.isEmpty) await produkProvider.load();
    await context.read<TitipProvider>().loadUntukOutlet(widget.outlet.id, widget.tanggal, produkProvider.items, _rows);
    setState(() => _loading = false);
  }

  int get _totalTerjual => _rows.fold(0, (sum, r) => sum + r.terjual);
  double get _totalNilai => _rows.fold(0, (sum, r) => sum + r.nilaiTerjual);

  Future<void> _simpan() async {
    setState(() => _saving = true);
    await context.read<TitipProvider>().simpan(widget.outlet.id, widget.tanggal, _rows);
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tersimpan')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              const SizedBox(height: 8),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Input Titip: ${widget.outlet.namaOutlet}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(formatTanggal(widget.tanggal), style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _rows.isEmpty
                        ? const Center(child: Text('Belum ada produk. Tambahkan produk terlebih dahulu di menu Master.'))
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: _rows.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (context, index) => _ProdukRow(
                              row: _rows[index],
                              onChanged: () => setState(() {}),
                            ),
                          ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Terjual: $_totalTerjual pcs', style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(formatRupiah(_totalNilai), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: (_loading || _saving || _rows.isEmpty) ? null : _simpan,
                        child: _saving
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Simpan'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProdukRow extends StatelessWidget {
  final TitipInputRow row;
  final VoidCallback onChanged;

  const _ProdukRow({required this.row, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(row.produk.namaProduk, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _NumberField(
                rowKey: row.produk.id,
                label: 'Kirim',
                value: row.jumlahKirim,
                onChanged: (v) {
                  row.jumlahKirim = v;
                  onChanged();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _NumberField(
                rowKey: row.produk.id,
                label: 'Retur',
                value: row.jumlahRetur,
                onChanged: (v) {
                  row.jumlahRetur = v;
                  onChanged();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Terjual', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(height: 4),
                  Text(
                    '${row.terjual}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: row.terjual < 0 ? Colors.red : Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  final String rowKey;
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _NumberField({required this.rowKey, required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    // Key stabil per baris+label (bukan per rebuild), supaya fokus dan posisi
    // kursor tidak hilang saat parent melakukan setState di tiap ketikan.
    return TextFormField(
      key: ValueKey('numfield-$rowKey-$label'),
      initialValue: value == 0 ? '' : value.toString(),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label, isDense: true),
      onChanged: (text) => onChanged(int.tryParse(text) ?? 0),
    );
  }
}
