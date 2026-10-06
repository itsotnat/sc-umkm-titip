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

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const DATE_RE = /^\d{4}-\d{2}-\d{2}/;
// Batas per entitas per request; sisanya tetap `pending` di klien dan ikut di sync berikutnya.
const MAX_ITEMS = 500;

function reasonOf(err) {
  // Pesan error DB mentah tidak dikirim ke klien; cukup alasan yang bisa dipahami.
  if (err && err.code === '22P02') return 'Format data tidak valid';
  if (err && err.code === '23503') return 'Data induk (mis. outlet/produk) belum ada di server';
  return err && err.message ? err.message : 'Gagal diproses';
}

function checkId(item) {
  if (!item || typeof item.id !== 'string' || !UUID_RE.test(item.id)) throw new Error('id tidak valid');
}

function nonNegative(value, name) {
  const n = Number(value);
  if (!Number.isFinite(n) || n < 0) throw new Error(`${name} tidak boleh negatif`);
  return n;
}

const validators = {
  produk(p) {
    checkId(p);
    if (!p.nama_produk || !String(p.nama_produk).trim()) throw new Error('nama_produk wajib diisi');
    return { ...p, nama_produk: String(p.nama_produk).trim(), hpp: nonNegative(p.hpp, 'hpp'), harga_jual: nonNegative(p.harga_jual, 'harga_jual') };
  },
  outlet(o) {
    checkId(o);
    if (!o.nama_outlet || !String(o.nama_outlet).trim()) throw new Error('nama_outlet wajib diisi');
    return { ...o, nama_outlet: String(o.nama_outlet).trim() };
  },
  pemesan(m) {
    checkId(m);
    if (!m.nama_pemesan || !String(m.nama_pemesan).trim()) throw new Error('nama_pemesan wajib diisi');
    return { ...m, nama_pemesan: String(m.nama_pemesan).trim() };
  },
  pesanan(p) {
    checkId(p);
    if (typeof p.pemesan_id !== 'string' || !UUID_RE.test(p.pemesan_id)) throw new Error('pemesan_id tidak valid');
    if (!p.tanggal_jatuh_tempo || !DATE_RE.test(String(p.tanggal_jatuh_tempo))) throw new Error('tanggal_jatuh_tempo tidak valid');
    if (!Array.isArray(p.items) || p.items.length === 0) throw new Error('Minimal satu produk harus dipilih');
    const items = p.items.map((i) => {
      if (!i || typeof i.produk_id !== 'string' || !UUID_RE.test(i.produk_id)) throw new Error('produk_id item tidak valid');
      const jumlah = Number(i.jumlah);
      if (!Number.isInteger(jumlah) || jumlah <= 0) throw new Error('jumlah item harus > 0');
      return { produk_id: i.produk_id, jumlah };
    });
    return { ...p, items };
  },
};

const upserters = {
  produk: syncRepository.upsertProduk,
  outlet: syncRepository.upsertOutlet,
  pemesan: syncRepository.upsertPemesan,
  pesanan: syncRepository.upsertPesanan,
};

async function pushEntity(userId, entity, items) {
  const synced_ids = [];
  const failed = [];
  for (const raw of items.slice(0, MAX_ITEMS)) {
    try {
      const valid = validators[entity](raw);
      const row = await upserters[entity](userId, valid);
      if (row) synced_ids.push(valid.id);
      else failed.push({ id: raw.id, reason: 'Data bukan milik akun ini' });
    } catch (err) {
      failed.push({ id: raw && raw.id, reason: reasonOf(err) });
    }
  }
  return { synced_ids, failed };
}

/**
 * POST /sync/push
 * Titik masuk tunggal sinkronisasi offline-first. Urutan penting karena ada
 * foreign key: produk, outlet, pemesan -> pesanan -> titip -> penghapusan.
 * Semua operasi idempoten (aman dikirim ulang bila respons sebelumnya hilang).
 *
 * Body: { produk: [], outlet: [], pemesan: [], pesanan: [], titip: [],
 *         deleted: { produk: [id], outlet: [id], pemesan: [id], pesanan: [id] } }
 */
async function push(userId, payload) {
  const body = payload || {};
  const result = { server_time: new Date().toISOString() };

  for (const entity of ['produk', 'outlet', 'pemesan', 'pesanan']) {
    if (Array.isArray(body[entity]) && body[entity].length > 0) {
      result[entity] = await pushEntity(userId, entity, body[entity]);
    }
  }

  if (Array.isArray(body.titip) && body.titip.length > 0) {
    result.titip = await titipService.syncBatch(userId, body.titip.slice(0, MAX_ITEMS));
  }

  if (body.deleted && typeof body.deleted === 'object') {
    result.deleted = {};
    // Anak dulu, induk belakangan.
    for (const entity of ['pesanan', 'pemesan', 'outlet', 'produk']) {
      const ids = Array.isArray(body.deleted[entity]) ? body.deleted[entity].filter((id) => typeof id === 'string') : [];
      const validIds = ids.filter((id) => UUID_RE.test(id)).slice(0, MAX_ITEMS);
      await syncRepository.deleteByIds(userId, entity, validIds);
      // Id tak valid ikut dianggap selesai supaya antrean klien tidak macet selamanya.
      result.deleted[entity] = ids.slice(0, MAX_ITEMS);
    }
  }

  return result;
}

module.exports = { pull, push };
