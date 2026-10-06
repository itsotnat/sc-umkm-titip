import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/reminder_service.dart';
import '../../services/sync_manager.dart';
import '../../widgets/app_bar_brand.dart';
import '../../widgets/profile_action.dart';
import '../../widgets/profile_avatar.dart';
import '../profile/ganti_password_screen.dart';
import '../profile/profile_screen.dart';

class AkunScreen extends StatefulWidget {
  const AkunScreen({super.key});

  @override
  State<AkunScreen> createState() => _AkunScreenState();
}

class _AkunScreenState extends State<AkunScreen> {
  bool _pengingatPesanan = true;
  bool _pengingatRetur = true;
  bool _mengirimCadangan = false;

  @override
  void initState() {
    super.initState();
    _muatSaklar();
  }

  Future<void> _muatSaklar() async {
    final pesanan = await ReminderService.instance.pesananAktif();
    final retur = await ReminderService.instance.returAktif();
    if (mounted) {
      setState(() {
        _pengingatPesanan = pesanan;
        _pengingatRetur = retur;
      });
    }
  }

  Future<void> _sinkronSekarang() async {
    final sync = SyncManager.instance;
    final messenger = ScaffoldMessenger.of(context);
    if (!await sync.isOnline) {
      messenger.showSnackBar(const SnackBar(content: Text('Tidak ada internet. Data tetap aman di HP dan akan terkirim saat online.')));
      return;
    }
    final berhasil = await sync.syncAll();
    final sisa = await sync.countPending();
    final pesan = !berhasil
        ? (sync.lastError ?? 'Sinkronisasi gagal. Coba lagi nanti.')
        : (sisa > 0 ? '$sisa data belum diterima server: ${sync.lastError ?? 'coba lagi nanti'}' : 'Semua data sudah tersinkron');
    messenger.showSnackBar(SnackBar(content: Text(pesan)));
  }

  Future<void> _kirimCadangan() async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kirim cadangan ke email?'),
        content: Text(
          'Data Anda akan disinkronkan lalu dikirim sebagai file cadangan ke ${context.read<AuthProvider>().email ?? 'email akun'}.\n\n'
          'Cadangan juga dikirim otomatis setiap tengah malam (00:00 WIB) bila ada perubahan data.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kirim')),
        ],
      ),
    );
    if (yakin != true || !mounted) return;

    setState(() => _mengirimCadangan = true);
    final messenger = ScaffoldMessenger.of(context);
    final email = context.read<AuthProvider>().email;
    final error = await context.read<AuthProvider>().kirimCadangan();
    if (!mounted) return;
    setState(() => _mengirimCadangan = false);
    messenger.showSnackBar(SnackBar(content: Text(error ?? 'Cadangan dikirim ke ${email ?? 'email Anda'}. Cek kotak masuk atau folder spam.')));
  }

  /// Mencoba mengirim data tertunda dulu. Kalau masih ada yang belum terkirim
  /// (mis. offline), minta konfirmasi: data lokal dihapus saat keluar.
  Future<void> _keluar(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final sync = SyncManager.instance;

    await sync.syncAll();
    final sisa = await sync.countPending();
    if (sisa > 0 && context.mounted) {
      final yakin = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ada data belum tersinkron'),
          content: Text(
            '$sisa data belum terkirim ke server dan akan HILANG jika Anda keluar sekarang. '
            'Sambungkan internet dulu agar data terkirim, atau tetap keluar?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Tetap keluar', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (yakin != true) return;
    }
    await auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final sync = context.watch<SyncManager>();

    final String statusSinkron;
    if (sync.isSyncing) {
      statusSinkron = 'Sedang menyinkronkan...';
    } else if (sync.pendingCount > 0) {
      statusSinkron = '${sync.pendingCount} data menunggu dikirim';
    } else if (sync.lastSyncAt != null) {
      statusSinkron = 'Terakhir: ${DateFormat('dd/MM HH:mm').format(sync.lastSyncAt!)}';
    } else {
      statusSinkron = 'Semua data tersinkron';
    }

    return Scaffold(
      appBar: AppBar(title: const AppBarBrand(label: 'Akun'), actions: const [ProfileAction()]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: ProfileAvatar(radius: 24, fotoUrl: auth.fotoUrl, nama: auth.namaUsaha),
            title: Text(auth.namaUsaha ?? 'UMKM Titip', maxLines: 2, overflow: TextOverflow.ellipsis),
            // FittedBox: email panjang mengecil otomatis supaya tampil utuh (tidak terpotong di ".com").
            subtitle: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(auth.email ?? 'Kelola akun dan sinkronisasi', maxLines: 1, softWrap: false),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
          const Divider(),
          const _Judul('Data & Cadangan'),
          ListTile(
            leading: sync.isSyncing
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync),
            title: const Text('Sinkronkan sekarang'),
            subtitle: Text(statusSinkron),
            onTap: sync.isSyncing ? null : _sinkronSekarang,
          ),
          ListTile(
            leading: _mengirimCadangan
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.mark_email_read_outlined),
            title: const Text('Kirim cadangan ke email'),
            subtitle: const Text('Otomatis tiap 00:00 WIB bila ada perubahan'),
            onTap: _mengirimCadangan ? null : _kirimCadangan,
          ),
          const _Judul('Pengingat'),
          SwitchListTile(
            secondary: const Icon(Icons.event_available_outlined),
            title: const Text('Pesanan jatuh tempo'),
            subtitle: const Text('Notifikasi pukul 07:00'),
            value: _pengingatPesanan,
            onChanged: (v) async {
              setState(() => _pengingatPesanan = v);
              await ReminderService.instance.setPesananAktif(v);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.assignment_return_outlined),
            title: const Text('Retur belum diinput'),
            subtitle: const Text('Notifikasi pukul 18:00'),
            value: _pengingatRetur,
            onChanged: (v) async {
              setState(() => _pengingatRetur = v);
              await ReminderService.instance.setReturAktif(v);
            },
          ),
          const _Judul('Keamanan'),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Ganti password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GantiPasswordScreen())),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _keluar(context),
            icon: const Icon(Icons.logout),
            label: const Text('Keluar'),
          ),
        ],
      ),
    );
  }
}

class _Judul extends StatelessWidget {
  final String teks;

  const _Judul(this.teks);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        teks,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}
