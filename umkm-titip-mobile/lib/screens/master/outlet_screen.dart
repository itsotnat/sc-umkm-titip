import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/outlet.dart';
import '../../providers/outlet_provider.dart';
import '../../widgets/empty_state.dart';

/// Menormalkan nomor WhatsApp ke format internasional yang dipakai wa.me
/// (mis. "0812..." atau "+62812..." -> "62812...").
String? _normalizeWhatsapp(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  var nomor = raw.replaceAll(RegExp(r'[\s\-]'), '');
  if (nomor.startsWith('+')) nomor = nomor.substring(1);
  if (nomor.startsWith('0')) nomor = '62${nomor.substring(1)}';
  return nomor;
}

Future<void> _bukaWhatsapp(BuildContext context, String? nomor) async {
  final normalized = _normalizeWhatsapp(nomor);
  if (normalized == null) return;
  final uri = Uri.parse('https://wa.me/$normalized');
  final berhasil = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!berhasil && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tidak bisa membuka WhatsApp. Pastikan WhatsApp terpasang di HP ini.')),
    );
  }
}

class OutletScreen extends StatefulWidget {
  const OutletScreen({super.key});

  @override
  State<OutletScreen> createState() => _OutletScreenState();
}

class _OutletScreenState extends State<OutletScreen> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      context.read<OutletProvider>().load();
    }
  }

  void _openForm({Outlet? outlet}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _OutletFormSheet(outlet: outlet),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OutletProvider>();

    return Scaffold(
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.items.isEmpty
              ? EmptyState(
                  icon: Icons.storefront_outlined,
                  message: 'Belum ada outlet, tambahkan outlet pertamamu.',
                  actionLabel: 'Tambah Outlet',
                  onAction: () => _openForm(),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final outlet = provider.items[index];
                    return Dismissible(
                      key: ValueKey(outlet.id),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) => showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Hapus outlet?'),
                          content: Text('Outlet "${outlet.namaOutlet}" akan dihapus.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
                          ],
                        ),
                      ),
                      onDismissed: (_) => provider.remove(outlet.id),
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      child: Card(
                        child: ListTile(
                          title: Text(outlet.namaOutlet),
                          subtitle: Text(outlet.alamat?.isNotEmpty == true ? outlet.alamat! : '-'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (outlet.noWhatsapp?.isNotEmpty == true)
                                IconButton(
                                  icon: const Icon(Icons.chat, color: Colors.green),
                                  tooltip: 'Chat WhatsApp',
                                  onPressed: () => _bukaWhatsapp(context, outlet.noWhatsapp),
                                ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: 'Edit outlet',
                                onPressed: () => _openForm(outlet: outlet),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(onPressed: () => _openForm(), child: const Icon(Icons.add)),
    );
  }
}

class _OutletFormSheet extends StatefulWidget {
  final Outlet? outlet;

  const _OutletFormSheet({this.outlet});

  @override
  State<_OutletFormSheet> createState() => _OutletFormSheetState();
}

class _OutletFormSheetState extends State<_OutletFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _namaController;
  late final TextEditingController _alamatController;
  late final TextEditingController _whatsappController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _namaController = TextEditingController(text: widget.outlet?.namaOutlet ?? '');
    _alamatController = TextEditingController(text: widget.outlet?.alamat ?? '');
    _whatsappController = TextEditingController(text: widget.outlet?.noWhatsapp ?? '');
  }

  @override
  void dispose() {
    _namaController.dispose();
    _alamatController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final provider = context.read<OutletProvider>();

    if (widget.outlet == null) {
      await provider.add(
        namaOutlet: _namaController.text.trim(),
        alamat: _alamatController.text.trim(),
        noWhatsapp: _whatsappController.text.trim(),
      );
    } else {
      await provider.update(Outlet(
        id: widget.outlet!.id,
        namaOutlet: _namaController.text.trim(),
        alamat: _alamatController.text.trim(),
        noWhatsapp: _whatsappController.text.trim(),
        syncStatus: 'pending',
      ));
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
            Text(widget.outlet == null ? 'Tambah Outlet' : 'Ubah Outlet', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            TextFormField(
              controller: _namaController,
              decoration: const InputDecoration(labelText: 'Nama Outlet'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama outlet wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _alamatController, decoration: const InputDecoration(labelText: 'Alamat')),
            const SizedBox(height: 12),
            TextFormField(
              controller: _whatsappController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'No. WhatsApp (contoh: 628123456789)'),
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
