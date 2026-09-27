const { pool } = require('../../config/db');

async function findAllByUser(userId) {
  const { rows } = await pool.query(
    'SELECT * FROM outlet WHERE user_id = $1 ORDER BY nama_outlet ASC',
    [userId]
  );
  return rows;
}

async function create(userId, { namaOutlet, alamat, noWhatsapp }) {
  const { rows } = await pool.query(
    `INSERT INTO outlet (user_id, nama_outlet, alamat, no_whatsapp)
     VALUES ($1, $2, $3, $4) RETURNING *`,
    [userId, namaOutlet, alamat || null, noWhatsapp || null]
  );
  return rows[0];
}

async function update(id, userId, { namaOutlet, alamat, noWhatsapp }) {
  const { rows } = await pool.query(
    `UPDATE outlet SET nama_outlet = $1, alamat = $2, no_whatsapp = $3, updated_at = now()
     WHERE id = $4 AND user_id = $5 RETURNING *`,
    [namaOutlet, alamat || null, noWhatsapp || null, id, userId]
  );
  return rows[0] || null;
}

async function remove(id, userId) {
  const { rowCount } = await pool.query('DELETE FROM outlet WHERE id = $1 AND user_id = $2', [id, userId]);
  return rowCount > 0;
}

module.exports = { findAllByUser, create, update, remove };
