import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/pemesan.dart';
import '../../models/produk.dart';
import '../../providers/pesanan_provider.dart';
import '../../providers/produk_provider.dart';
import '../../widgets/format_utils.dart';

class _ItemPesanan {
  Produk? produk;
  int jumlah = 1;
}

/// Id penanda untuk opsi "Pemesan baru" di dalam dropdown Autocomplete,
/// supaya bisa dibedakan dari pemesan yang sudah tersimpan tanpa perlu
/// tipe union/sealed terpisah.
const _idPemesanBaru = '__pemesan_baru__';

/// Form Pesanan, sesuai dokumen UI/UX Design Bagian 7.
class PesananFormScreen extends StatefulWidget {
  const PesananFormScreen({super.key});

  @override
  State<PesananFormScreen> createState() => _PesananFormScreenState();
}

class _PesananFormScreenState extends State<PesananFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pemesanController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _catatanController = TextEditingController();
  Pemesan? _pemesanTerpilih;
  DateTime? _tanggalJatuhTempo;
  bool _catatanExpanded = false;
  bool _saving = false;

  final List<_ItemPesanan> _items = [_ItemPesanan()];

  @override
  void dispose() {
    _pemesanController.dispose();
    _whatsappController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  Future<void> _pilihTanggal() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _tanggalJatuhTempo = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_tanggalJatuhTempo == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tanggal jatuh tempo wajib diisi')));
      return;
    }
    final validItems = _items.where((i) => i.produk != null && i.jumlah > 0).toList();
    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Minimal satu produk harus dipilih')));
      return;
    }

    setState(() => _saving = true);
    final provider = context.read<PesananProvider>();

    String pemesanId;
    if (_pemesanTerpilih != null) {
      pemesanId = _pemesanTerpilih!.id;
    } else {
      final baru = await provider.tambahPemesanBaru(_pemesanController.text.trim(), _whatsappController.text.trim());
      pemesanId = baru.id;
    }

    await provider.tambah(
      pemesanId: pemesanId,
      tanggalJatuhTempo: _tanggalJatuhTempo!,
      produkItems: validItems.map((i) => (produkId: i.produk!.id, jumlah: i.jumlah)).toList(),
      catatan: _catatanController.text.trim().isEmpty ? null : _catatanController.text.trim(),
    );

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final pesananProvider = context.watch<PesananProvider>();
    final produkProvider = context.watch<ProdukProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Tambah Pesanan')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Autocomplete<Pemesan>(
              displayStringForOption: (p) => p.namaPemesan,
              optionsBuilder: (textEditingValue) {
                final query = textEditingValue.text.trim();
                if (query.isEmpty) return const Iterable<Pemesan>.empty();
                final cocok = pesananProvider.daftarPemesan
                    .where((p) => p.namaPemesan.toLowerCase().contains(query.toLowerCase()))
                    .toList();
                // Kalau tidak ada nama yang persis sama (tanpa memandang huruf
                // besar/kecil), tampilkan opsi "Pemesan baru" di baris terakhir
                // supaya penggunanya tahu nama ini akan dibuat sebagai pemesan baru.
                final adaYangSamaPersis = cocok.any((p) => p.namaPemesan.toLowerCase() == query.toLowerCase());
                if (!adaYangSamaPersis) {
                  cocok.add(Pemesan(id: _idPemesanBaru, namaPemesan: query));
                }
                return cocok;
              },
              onSelected: (p) {
                if (p.id == _idPemesanBaru) {
                  _pemesanTerpilih = null;
                  _pemesanController.text = p.namaPemesan;
                } else {
                  _pemesanTerpilih = p;
                  _pemesanController.text = p.namaPemesan;
                  _whatsappController.text = p.noWhatsapp ?? '';
                }
              },
              optionsViewBuilder: (context, onSelected, options) {
                final list = options.toList();
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final option = list[index];
                          if (option.id == _idPemesanBaru) {
                            return ListTile(
                              leading: const Icon(Icons.add, color: Colors.green),
                              title: Text(
                                'Pemesan baru "${option.namaPemesan}"',
                                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                              ),
                              onTap: () => onSelected(option),
                            );
                          }
                          return ListTile(
                            title: Text(option.namaPemesan, style: const TextStyle(fontWeight: FontWeight.bold)),
                            trailing: Text(
                              option.noWhatsapp?.isNotEmpty == true ? option.noWhatsapp! : '-',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                return TextFormField(
                  controller: controller..text = _pemesanController.text,
                  focusNode: focusNode,
                  decoration: const InputDecoration(labelText: 'Nama Pemesan', prefixIcon: Icon(Icons.person_outline)),
                  onChanged: (v) {
                    _pemesanController.text = v;
                    _pemesanTerpilih = null;
                  },
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama pemesan wajib diisi' : null,
                );
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _whatsappController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'No. WhatsApp (opsional)'),
            ),
            const SizedBox(height: 20),
            Text('Produk Dipesan', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<Produk>(
                        value: item.produk,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Produk', isDense: true),
                        items: produkProvider.items
                            .map((p) => DropdownMenuItem(value: p, child: Text(p.namaProduk, overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (v) => setState(() => item.produk = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: '1',
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Jumlah', isDense: true),
                        onChanged: (v) => item.jumlah = int.tryParse(v) ?? 1,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                      onPressed: _items.length == 1 ? null : () => setState(() => _items.removeAt(index)),
                    ),
                  ],
                ),
              );
            }),
            TextButton.icon(
              onPressed: () => setState(() => _items.add(_ItemPesanan())),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Produk'),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tanggal Jatuh Tempo'),
              subtitle: Text(_tanggalJatuhTempo == null ? 'Belum dipilih' : formatTanggal(_tanggalJatuhTempo!)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pilihTanggal,
            ),
            const Divider(),
            ExpansionTile(
              title: const Text('Catatan (opsional)'),
              initiallyExpanded: _catatanExpanded,
              onExpansionChanged: (v) => setState(() => _catatanExpanded = v),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(controller: _catatanController, maxLines: 3),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}
