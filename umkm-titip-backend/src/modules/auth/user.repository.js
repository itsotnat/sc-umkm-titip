const { pool } = require('../../config/db');

async function findByEmail(email) {
  const { rows } = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
  return rows[0] || null;
}

async function findById(id) {
  const { rows } = await pool.query(
    'SELECT id, nama_usaha, nama_pemilik, email, no_hp, created_at FROM users WHERE id = $1',
    [id]
  );
  return rows[0] || null;
}

async function create({ namaUsaha, namaPemilik, email, noHp, passwordHash }) {
  const { rows } = await pool.query(
    `INSERT INTO users (nama_usaha, nama_pemilik, email, no_hp, password_hash)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING id, nama_usaha, nama_pemilik, email, no_hp, created_at`,
    [namaUsaha, namaPemilik, email, noHp || null, passwordHash]
  );
  return rows[0];
}

module.exports = { findByEmail, findById, create };
