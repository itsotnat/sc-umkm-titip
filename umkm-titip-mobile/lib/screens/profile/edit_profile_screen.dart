import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

/// Ubah nama usaha, nama pemilik, dan nomor HP. Email tidak bisa diubah
/// karena dipakai untuk masuk dan sebagai alamat cadangan data.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usaha;
  late final TextEditingController _pemilik;
  late final TextEditingController _hp;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _usaha = TextEditingController(text: auth.namaUsaha ?? '');
    _pemilik = TextEditingController(text: auth.namaPemilik ?? '');
    _hp = TextEditingController(text: auth.noHp ?? '');
    // No. HP tidak disimpan di sesi lokal; ambil dari server bila belum ada.
    if (auth.noHp == null) {
      auth.refreshProfile().then((_) {
        if (mounted && _hp.text.isEmpty) _hp.text = context.read<AuthProvider>().noHp ?? '';
      });
    }
  }

  @override
  void dispose() {
    _usaha.dispose();
    _pemilik.dispose();
    _hp.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final error = await context.read<AuthProvider>().ubahProfil(
          namaUsaha: _usaha.text.trim(),
          namaPemilik: _pemilik.text.trim(),
          noHp: _hp.text.trim(),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? 'Profil diperbarui')));
    if (error == null) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final email = context.watch<AuthProvider>().email ?? '-';

    return Scaffold(
      appBar: AppBar(title: const Text('Ubah Profil')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _usaha,
                textCapitalization: TextCapitalization.words,
                maxLength: 150,
                decoration: const InputDecoration(labelText: 'Nama Usaha', counterText: ''),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama usaha wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pemilik,
                textCapitalization: TextCapitalization.words,
                maxLength: 150,
                decoration: const InputDecoration(labelText: 'Nama Pemilik', counterText: ''),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama pemilik wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _hp,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'No. HP (opsional)'),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return null;
                  return RegExp(r'^[0-9+\-\s]{8,30}$').hasMatch(t) ? null : 'Nomor HP tidak valid';
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: email,
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  helperText: 'Email tidak bisa diubah. Dipakai untuk masuk dan menerima cadangan data.',
                  helperMaxLines: 2,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _simpan,
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Simpan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
