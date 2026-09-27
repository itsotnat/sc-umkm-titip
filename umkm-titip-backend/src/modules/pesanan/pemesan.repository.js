const { pool } = require('../../config/db');

async function findAllByUser(userId) {
  const { rows } = await pool.query(
    'SELECT * FROM pemesan WHERE user_id = $1 ORDER BY nama_pemesan ASC',
    [userId]
  );
  return rows;
}

async function findByIdAndUser(id, userId) {
  const { rows } = await pool.query('SELECT * FROM pemesan WHERE id = $1 AND user_id = $2', [id, userId]);
  return rows[0] || null;
}

async function create(userId, { namaPemesan, noWhatsapp }, client = pool) {
  const { rows } = await client.query(
    `INSERT INTO pemesan (user_id, nama_pemesan, no_whatsapp) VALUES ($1, $2, $3) RETURNING *`,
    [userId, namaPemesan, noWhatsapp || null]
  );
  return rows[0];
}

module.exports = { findAllByUser, findByIdAndUser, create };
