const { pool } = require('../../config/db');

async function findAllByUser(userId) {
  const { rows } = await pool.query(
    'SELECT * FROM produk WHERE user_id = $1 ORDER BY nama_produk ASC',
    [userId]
  );
  return rows;
}

async function findByIdAndUser(id, userId) {
  const { rows } = await pool.query('SELECT * FROM produk WHERE id = $1 AND user_id = $2', [id, userId]);
  return rows[0] || null;
}

async function create(userId, { namaProduk, hpp, hargaJual }) {
  const { rows } = await pool.query(
    `INSERT INTO produk (user_id, nama_produk, hpp, harga_jual)
     VALUES ($1, $2, $3, $4) RETURNING *`,
    [userId, namaProduk, hpp, hargaJual]
  );
  return rows[0];
}

async function update(id, userId, { namaProduk, hpp, hargaJual }) {
  const { rows } = await pool.query(
    `UPDATE produk SET nama_produk = $1, hpp = $2, harga_jual = $3, updated_at = now()
     WHERE id = $4 AND user_id = $5 RETURNING *`,
    [namaProduk, hpp, hargaJual, id, userId]
  );
  return rows[0] || null;
}

async function remove(id, userId) {
  const { rowCount } = await pool.query('DELETE FROM produk WHERE id = $1 AND user_id = $2', [id, userId]);
  return rowCount > 0;
}

module.exports = { findAllByUser, findByIdAndUser, create, update, remove };
