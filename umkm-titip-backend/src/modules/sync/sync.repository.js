const { pool } = require('../../config/db');

async function changedSince(userId, sinceIso) {
  const since = sinceIso || '1970-01-01T00:00:00Z';

  const [produk, outlet, pemesan, titip, pesanan] = await Promise.all([
    pool.query('SELECT * FROM produk WHERE user_id = $1 AND updated_at > $2', [userId, since]),
    pool.query('SELECT * FROM outlet WHERE user_id = $1 AND updated_at > $2', [userId, since]),
    pool.query('SELECT * FROM pemesan WHERE user_id = $1', [userId]),
    pool.query('SELECT * FROM transaksi_titip WHERE user_id = $1 AND updated_at > $2', [userId, since]),
    pool.query('SELECT * FROM pesanan WHERE user_id = $1 AND updated_at > $2', [userId, since]),
  ]);

  return {
    produk: produk.rows,
    outlet: outlet.rows,
    pemesan: pemesan.rows,
    titip: titip.rows,
    pesanan: pesanan.rows,
  };
}

module.exports = { changedSince };
