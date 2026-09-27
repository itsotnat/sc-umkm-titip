const titipRepository = require('./titip.repository');
const { ApiError } = require('../../utils/ApiError');

async function listByOutletTanggal(userId, outletId, tanggal) {
  if (!outletId || !tanggal) {
    throw ApiError.badRequest('outlet_id dan tanggal wajib diisi sebagai query parameter');
  }
  return titipRepository.findByOutletAndTanggal(userId, outletId, tanggal);
}

/**
 * Sinkronisasi batch: item yang gagal (mis. retur > kirim) tidak menggagalkan
 * seluruh batch, cukup dilaporkan agar mobile bisa retry item tsb saja.
 */
async function syncBatch(userId, items) {
  if (!Array.isArray(items) || items.length === 0) {
    throw ApiError.badRequest('items wajib berupa array dan tidak boleh kosong');
  }

  const syncedIds = [];
  const failed = [];

  for (const item of items) {
    try {
      if (!item.id || !item.outlet_id || !item.produk_id || !item.tanggal) {
        throw new Error('field wajib (id, outlet_id, produk_id, tanggal) tidak lengkap');
      }
      const kirim = Number(item.jumlah_kirim) || 0;
      const retur = Number(item.jumlah_retur) || 0;
      if (kirim < 0 || retur < 0) {
        throw new Error('jumlah_kirim dan jumlah_retur tidak boleh negatif');
      }
      const result = await titipRepository.upsert(userId, {
        ...item,
        jumlah_kirim: kirim,
        jumlah_retur: retur,
      });
      if (result) syncedIds.push(result.id);
      else failed.push({ id: item.id, reason: 'Data tidak ditemukan atau bukan milik akun ini' });
    } catch (err) {
      failed.push({ id: item.id, reason: err.message });
    }
  }

  return { synced_ids: syncedIds, failed, server_time: new Date().toISOString() };
}

module.exports = { listByOutletTanggal, syncBatch };
