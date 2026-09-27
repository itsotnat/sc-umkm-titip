const { pool } = require('../../config/db');

async function rekapTitipOutlet(userId, dari, sampai) {
  const { rows } = await pool.query(
    `SELECT
       o.id AS outlet_id,
       o.nama_outlet,
       COALESCE(SUM(t.jumlah_kirim), 0) AS total_kirim,
       COALESCE(SUM(t.jumlah_retur), 0) AS total_retur,
       COALESCE(SUM(t.jumlah_terjual), 0) AS total_terjual,
       COALESCE(SUM(t.jumlah_terjual * p.harga_jual), 0) AS total_nilai_terjual,
       COALESCE(SUM((t.jumlah_terjual * p.harga_jual) - (t.jumlah_kirim * p.hpp)), 0) AS total_untung_rugi
     FROM outlet o
     LEFT JOIN transaksi_titip t
       ON t.outlet_id = o.id AND t.tanggal BETWEEN $2 AND $3
     LEFT JOIN produk p ON p.id = t.produk_id
     WHERE o.user_id = $1
     GROUP BY o.id, o.nama_outlet
     ORDER BY o.nama_outlet ASC`,
    [userId, dari, sampai]
  );
  return rows;
}

async function rekapPesanan(userId, dari, sampai) {
  const { rows } = await pool.query(
    `SELECT
       COUNT(*) AS total_pesanan,
       COUNT(*) FILTER (WHERE status_selesai = true) AS total_selesai,
       COUNT(*) FILTER (WHERE status_selesai = false) AS total_belum_selesai,
       COUNT(*) FILTER (WHERE status_lunas = true) AS total_lunas,
       COUNT(*) FILTER (WHERE status_lunas = false) AS total_belum_lunas
     FROM pesanan
     WHERE user_id = $1 AND tanggal_jatuh_tempo BETWEEN $2 AND $3`,
    [userId, dari, sampai]
  );
  return rows[0];
}

module.exports = { rekapTitipOutlet, rekapPesanan };
