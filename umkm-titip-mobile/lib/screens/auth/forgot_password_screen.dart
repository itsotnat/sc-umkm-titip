import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';

/// Lupa password lewat kode OTP 6 digit yang dikirim ke email.
/// Langkah 1: isi email -> Langkah 2: isi kode + password baru.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const _cooldownDetik = 60;

  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _kodeTerkirim = false;
  bool _loading = false;
  bool _obscure = true;
  int _sisaCooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _mulaiCooldown() {
    _timer?.cancel();
    setState(() => _sisaCooldown = _cooldownDetik);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _sisaCooldown--);
      if (_sisaCooldown <= 0) t.cancel();
    });
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _kirimKode() async {
    if (!_emailFormKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().kirimKodReset(_emailController.text.trim());
      if (!mounted) return;
      setState(() => _kodeTerkirim = true);
      _mulaiCooldown();
      _snack('Jika email terdaftar, kode 6 digit sudah dikirim. Cek juga folder Spam.');
    } catch (e) {
      if (mounted) _snack(ApiClient.messageFromError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_resetFormKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().resetPassword(
            email: _emailController.text.trim(),
            code: _codeController.text.trim(),
            newPassword: _passwordController.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password berhasil diubah. Silakan masuk dengan password baru.')),
      );
    } catch (e) {
      if (mounted) _snack(ApiClient.messageFromError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lupa Password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _kodeTerkirim
                    ? 'Masukkan kode 6 digit dari email dan buat password baru.'
                    : 'Masukkan email akun Anda. Kami akan mengirim kode untuk mengatur ulang password.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
              ),
              const SizedBox(height: 20),
              Form(
                key: _emailFormKey,
                child: TextFormField(
                  controller: _emailController,
                  enabled: !_kodeTerkirim,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return 'Email wajib diisi';
                    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) return 'Format email tidak valid';
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 16),
              if (!_kodeTerkirim)
                ElevatedButton(
                  onPressed: _loading ? null : _kirimKode,
                  child: _loading ? const _Spinner() : const Text('Kirim Kode'),
                )
              else ...[
                Form(
                  key: _resetFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: const InputDecoration(labelText: 'Kode 6 digit', prefixIcon: Icon(Icons.pin_outlined)),
                        validator: (v) => (v == null || v.trim().length != 6) ? 'Kode terdiri dari 6 digit' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'Password baru',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => (v == null || v.length < 8) ? 'Password minimal 8 karakter' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmController,
                        obscureText: _obscure,
                        decoration: const InputDecoration(labelText: 'Konfirmasi password baru', prefixIcon: Icon(Icons.lock_outline)),
                        validator: (v) => (v != _passwordController.text) ? 'Konfirmasi password tidak cocok' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _resetPassword,
                  child: _loading ? const _Spinner() : const Text('Ubah Password'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: (_loading || _sisaCooldown > 0) ? null : _kirimKode,
                  child: Text(_sisaCooldown > 0 ? 'Kirim ulang kode ($_sisaCooldown dtk)' : 'Kirim ulang kode'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white));
}
