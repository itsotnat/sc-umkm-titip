import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

/// Ganti password dari dalam aplikasi. Perangkat lain yang memakai akun ini
/// otomatis keluar; perangkat ini tetap masuk.
class GantiPasswordScreen extends StatefulWidget {
  const GantiPasswordScreen({super.key});

  @override
  State<GantiPasswordScreen> createState() => _GantiPasswordScreenState();
}

class _GantiPasswordScreenState extends State<GantiPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _lama = TextEditingController();
  final _baru = TextEditingController();
  final _ulang = TextEditingController();
  bool _lihat = false;
  bool _saving = false;

  @override
  void dispose() {
    _lama.dispose();
    _baru.dispose();
    _ulang.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final error = await context.read<AuthProvider>().gantiPassword(passwordLama: _lama.text, passwordBaru: _baru.text);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? 'Password berhasil diubah')));
    if (error == null) Navigator.of(context).pop();
  }

  InputDecoration _dekor(String label) => InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          icon: Icon(_lihat ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          tooltip: _lihat ? 'Sembunyikan password' : 'Tampilkan password',
          onPressed: () => setState(() => _lihat = !_lihat),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ganti Password')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _lama,
                obscureText: !_lihat,
                decoration: _dekor('Password saat ini'),
                validator: (v) => (v == null || v.isEmpty) ? 'Password saat ini wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _baru,
                obscureText: !_lihat,
                decoration: _dekor('Password baru (min. 8 karakter)'),
                validator: (v) {
                  if (v == null || v.length < 8) return 'Password minimal 8 karakter';
                  if (v.length > 72) return 'Password maksimal 72 karakter';
                  if (v == _lama.text) return 'Password baru harus berbeda dari yang lama';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ulang,
                obscureText: !_lihat,
                decoration: _dekor('Ulangi password baru'),
                validator: (v) => v != _baru.text ? 'Password tidak sama' : null,
              ),
              const SizedBox(height: 12),
              Text(
                'Setelah diganti, perangkat lain yang memakai akun ini akan otomatis keluar.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _simpan,
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Simpan Password'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
