import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/produk.dart';
import '../../providers/produk_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/hapus_undo.dart';
import '../../widgets/search_field.dart';
import '../../widgets/format_utils.dart';

class ProdukScreen extends StatefulWidget {
  const ProdukScreen({super.key});

  @override
  State<ProdukScreen> createState() => _ProdukScreenState();
}

class _ProdukScreenState extends State<ProdukScreen> {
  bool _loaded = false;
  String _query = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      context.read<ProdukProvider>().load();
    }
  }

  void _openForm({Produk? produk}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ProdukFormSheet(produk: produk),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProdukProvider>();
    final daftar = _query.isEmpty
        ? provider.items
        : provider.items.where((p) => p.namaProduk.toLowerCase().contains(_query)).toList();

    return Scaffold(
      body: (provider.isLoading && provider.items.isEmpty)
          ? const Center(child: CircularProgressIndicator())
          : provider.items.isEmpty
              ? EmptyState(
                  icon: Icons.inventory_2_outlined,
                  message: 'Belum ada produk, tambahkan produk pertamamu.',
                  actionLabel: 'Tambah Produk',
                  onAction: () => _openForm(),
                )
              : Column(
                  children: [
                    SearchField(
                      hint: 'Cari produk',
                      onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                    ),
                    Expanded(
                      child: daftar.isEmpty
                          ? const EmptyState(icon: Icons.search_off, message: 'Produk tidak ditemukan.')
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                              itemCount: daftar.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final produk = daftar[index];
                                return Dismissible(
                                  key: ValueKey(produk.id),
                                  direction: DismissDirection.endToStart,
                                  onDismissed: (_) {
                                    late VoidCallback pulihkan;
                                    hapusDenganUndo(
                                      context,
                                      pesan: 'Produk "${produk.namaProduk}" dihapus',
                                      sembunyikan: () => pulihkan = provider.sembunyikan(produk.id),
                                      pulihkan: () => pulihkan(),
                                      hapusPermanen: () => provider.remove(produk.id),
                                    );
                                  },
                                  background: Container(
                                    color: Colors.red,
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    child: const Icon(Icons.delete, color: Colors.white),
                                  ),
                                  child: Card(
                                    child: ListTile(
                                      title: Text(produk.namaProduk),
                                      subtitle: Text('HPP ${formatRupiah(produk.hpp)} · Jual ${formatRupiah(produk.hargaJual)}'),
                                      onTap: () => _openForm(produk: produk),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(onPressed: () => _openForm(), child: const Icon(Icons.add)),
    );
  }
}

class _ProdukFormSheet extends StatefulWidget {
  final Produk? produk;

  const _ProdukFormSheet({this.produk});

  @override
  State<_ProdukFormSheet> createState() => _ProdukFormSheetState();
}

class _ProdukFormSheetState extends State<_ProdukFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _namaController;
  late final TextEditingController _hppController;
  late final TextEditingController _hargaJualController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _namaController = TextEditingController(text: widget.produk?.namaProduk ?? '');
    _hppController = TextEditingController(text: widget.produk?.hpp.toStringAsFixed(0) ?? '');
    _hargaJualController = TextEditingController(text: widget.produk?.hargaJual.toStringAsFixed(0) ?? '');
  }

  @override
  void dispose() {
    _namaController.dispose();
    _hppController.dispose();
    _hargaJualController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final provider = context.read<ProdukProvider>();
    final hpp = double.parse(_hppController.text);
    final hargaJual = double.parse(_hargaJualController.text);

    if (widget.produk == null) {
      await provider.add(namaProduk: _namaController.text.trim(), hpp: hpp, hargaJual: hargaJual);
    } else {
      await provider.update(widget.produk!.copyWith(namaProduk: _namaController.text.trim(), hpp: hpp, hargaJual: hargaJual));
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.produk == null ? 'Tambah Produk' : 'Ubah Produk', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            TextFormField(
              controller: _namaController,
              decoration: const InputDecoration(labelText: 'Nama Produk'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama produk wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _hppController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'HPP (Harga Pokok Produksi)'),
              validator: (v) => (v == null || double.tryParse(v) == null || double.parse(v) < 0) ? 'HPP tidak valid' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _hargaJualController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Harga Jual'),
              validator: (v) => (v == null || double.tryParse(v) == null || double.parse(v) < 0) ? 'Harga jual tidak valid' : null,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Simpan'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
