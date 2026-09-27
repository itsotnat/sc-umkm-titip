const { pool } = require('../../config/db');
const pesananRepository = require('./pesanan.repository');
const pemesanRepository = require('./pemesan.repository');
const { ApiError } = require('../../utils/ApiError');

async function listPesanan(userId, query) {
  const rows = await pesananRepository.findAllByUser(userId, query);
  const withDetail = await Promise.all(
    rows.map(async (row) => ({
      ...row,
      items: await pesananRepository.findDetailByPesanan(row.id),
    }))
  );
  return withDetail;
}

/**
 * Membuat pesanan header + detail dalam satu transaksi database (atomic),
 * sesuai dokumen SDD Bagian 3 (Flow Tambah Pesanan).
 * `pemesan` boleh berupa objek baru { nama_pemesan, no_whatsapp } atau pemesan_id yang sudah ada.
 */
async function createPesanan(userId, { pemesan, pemesanId, tanggalJatuhTempo, items, catatan }) {
  if (!tanggalJatuhTempo) {
    throw ApiError.badRequest('tanggal_jatuh_tempo wajib diisi');
  }
  if (!Array.isArray(items) || items.length === 0) {
    throw ApiError.badRequest('Minimal satu produk harus dipilih');
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    let resolvedPemesanId = pemesanId;
    if (!resolvedPemesanId) {
      if (!pemesan || !pemesan.nama_pemesan) {
        throw ApiError.badRequest('pemesan_id atau data pemesan baru wajib diisi');
      }
      const createdPemesan = await pemesanRepository.create(
        userId,
        { namaPemesan: pemesan.nama_pemesan, noWhatsapp: pemesan.no_whatsapp },
        client
      );
      resolvedPemesanId = createdPemesan.id;
    }

    const header = await pesananRepository.create(client, userId, {
      pemesanId: resolvedPemesanId,
      tanggalJatuhTempo,
      catatan,
    });

    for (const item of items) {
      if (!item.produk_id || !item.jumlah || item.jumlah <= 0) {
        throw ApiError.badRequest('Setiap item pesanan wajib memiliki produk_id dan jumlah > 0');
      }
      await pesananRepository.addDetailItem(client, header.id, { produkId: item.produk_id, jumlah: item.jumlah });
    }

    await client.query('COMMIT');
    return header;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

async function updateStatus(id, userId, payload) {
  const updated = await pesananRepository.updateStatus(id, userId, payload);
  if (!updated) throw ApiError.notFound('Pesanan tidak ditemukan');
  return updated;
}

async function remove(id, userId) {
  const deleted = await pesananRepository.remove(id, userId);
  if (!deleted) throw ApiError.notFound('Pesanan tidak ditemukan');
}

async function listPemesan(userId) {
  return pemesanRepository.findAllByUser(userId);
}

async function createPemesan(userId, { namaPemesan, noWhatsapp }) {
  if (!namaPemesan || !namaPemesan.trim()) {
    throw ApiError.badRequest('nama_pemesan wajib diisi');
  }
  return pemesanRepository.create(userId, { namaPemesan, noWhatsapp });
}

module.exports = { listPesanan, createPesanan, updateStatus, remove, listPemesan, createPemesan };
