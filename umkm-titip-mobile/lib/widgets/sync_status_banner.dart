import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/sync_manager.dart';

/// Status sinkronisasi di Beranda: tersinkron / offline / N data menunggu.
/// Ketuk "Sinkron sekarang" untuk memaksa kirim data yang tertunda.
class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncManager>();

    final IconData icon;
    final Color color;
    final String text;

    if (sync.isSyncing) {
      icon = Icons.sync;
      color = Colors.blueGrey;
      text = 'Menyinkronkan data...';
    } else if (sync.isOffline) {
      icon = Icons.cloud_off_outlined;
      color = Colors.orange.shade800;
      text = sync.pendingCount > 0
          ? 'Offline · ${sync.pendingCount} menunggu'
          : 'Offline · data tersimpan di HP';
    } else if (sync.pendingCount > 0) {
      icon = Icons.cloud_upload_outlined;
      color = Colors.orange.shade800;
      text = '${sync.pendingCount} data menunggu sinkron';
    } else {
      icon = Icons.cloud_done_outlined;
      color = Colors.green.shade700;
      final waktu = sync.lastSyncAt;
      text = waktu == null ? 'Semua data tersinkron' : 'Tersinkron · ${DateFormat('HH:mm').format(waktu)}';
    }

    final bisaSinkron = !sync.isSyncing && !sync.isOffline && sync.pendingCount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              sync.isSyncing
                  ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: color))
                  : Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600))),
              if (bisaSinkron)
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => sync.syncAll(),
                  child: const Text('Sinkron sekarang'),
                ),
            ],
          ),
          if (sync.lastError != null && !sync.isSyncing)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 26),
              child: Text(sync.lastError!, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ),
        ],
      ),
    );
  }
}
