const { pool } = require('../../config/db');

async function findByOutletAndTanggal(userId, outletId, tanggal) {
  const { rows } = await pool.query(
    `SELECT t.*, p.nama_produk, p.harga_jual, p.hpp
     FROM transaksi_titip t
     JOIN produk p ON p.id = t.produk_id
     WHERE t.user_id = $1 AND t.outlet_id = $2 AND t.tanggal = $3
     ORDER BY p.nama_produk ASC`,
    [userId, outletId, tanggal]
  );
  return rows;
}

/**
 * Upsert satu baris transaksi titip berdasarkan id yang dibuat di sisi mobile (UUID),
 * sesuai kebijakan sinkronisasi "id dibuat di client" pada dokumen Database Design Bagian 5.
 */
async function upsert(userId, item) {
  const { id, outlet_id, produk_id, tanggal, jumlah_kirim, jumlah_retur } = item;
  const { rows } = await pool.query(
    `INSERT INTO transaksi_titip (id, user_id, outlet_id, produk_id, tanggal, jumlah_kirim, jumlah_retur, sync_status, updated_at)
     VALUES ($1, $2, $3, $4, $5, $6, $7, 'synced', now())
     ON CONFLICT (id) DO UPDATE SET
       jumlah_kirim = EXCLUDED.jumlah_kirim,
       jumlah_retur = EXCLUDED.jumlah_retur,
       sync_status = 'synced',
       updated_at = now()
     WHERE transaksi_titip.user_id = $2
     RETURNING id`,
    [id, userId, outlet_id, produk_id, tanggal, jumlah_kirim, jumlah_retur]
  );
  return rows[0] || null;
}

module.exports = { findByOutletAndTanggal, upsert };
