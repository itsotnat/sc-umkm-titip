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
  // Outlet & produk wajib milik user yang sama: FK di DB hanya memeriksa
  // keberadaan, bukan kepemilikan, jadi dicek di sini (isolasi multi-tenant).
  const { rows } = await pool.query(
    `INSERT INTO transaksi_titip (id, user_id, outlet_id, produk_id, tanggal, jumlah_kirim, jumlah_retur, sync_status, updated_at)
     SELECT $1::uuid, $2::uuid, $3::uuid, $4::uuid, $5::date, $6::int, $7::int, 'synced', now()
     WHERE EXISTS (SELECT 1 FROM outlet WHERE id = $3::uuid AND user_id = $2::uuid)
       AND EXISTS (SELECT 1 FROM produk WHERE id = $4::uuid AND user_id = $2::uuid)
     ON CONFLICT (id) DO UPDATE SET
       jumlah_kirim = EXCLUDED.jumlah_kirim,
       jumlah_retur = EXCLUDED.jumlah_retur,
       sync_status = 'synced',
       updated_at = now()
     WHERE transaksi_titip.user_id = $2::uuid
     RETURNING id`,
    [id, userId, outlet_id, produk_id, tanggal, jumlah_kirim, jumlah_retur]
  );
  return rows[0] || null;
}

module.exports = { findByOutletAndTanggal, upsert };
