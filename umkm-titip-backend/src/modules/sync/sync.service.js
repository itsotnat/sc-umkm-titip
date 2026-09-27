const syncRepository = require('./sync.repository');
const titipService = require('../titip/titip.service');

/**
 * POST /sync/pull
 * Mengambil seluruh perubahan data di server sejak last_sync_at,
 * untuk kasus satu akun dipakai di lebih dari satu perangkat
 * (dokumen REST API Spec Bagian 8).
 */
async function pull(userId, lastSyncAt) {
  const data = await syncRepository.changedSince(userId, lastSyncAt);
  return { ...data, server_time: new Date().toISOString() };
}

/**
 * POST /sync/push
 * Pendekatan sync terpusat: saat ini didelegasikan ke masing-masing modul
 * (titip.sync, dst). Endpoint ini disediakan sebagai titik masuk tunggal
 * opsional jika tim ingin mengganti sinkronisasi per-modul di kemudian hari.
 */
async function push(userId, payload) {
  const result = { server_time: new Date().toISOString() };
  if (Array.isArray(payload?.titip) && payload.titip.length > 0) {
    result.titip = await titipService.syncBatch(userId, payload.titip);
  }
  return result;
}

module.exports = { pull, push };
