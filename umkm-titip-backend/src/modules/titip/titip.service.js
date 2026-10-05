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
      // NULL/undefined berarti retur belum diinput (beda dari 0, yang berarti
      // sudah dikonfirmasi habis terjual) — jangan dipaksa jadi 0 di sini.
      const returMentah = item.jumlah_retur;
      const retur = returMentah === null || returMentah === undefined ? null : Number(returMentah);
      if (kirim < 0 || (retur !== null && retur < 0)) {
        throw new Error('jumlah_kirim dan jumlah_retur tidak boleh negatif');
      }
      if (retur !== null && retur > kirim) {
        throw new Error('jumlah_retur tidak boleh melebihi jumlah_kirim');
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
