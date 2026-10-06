const { pool } = require('../../config/db');

const PUBLIC_COLUMNS = 'id, nama_usaha, nama_pemilik, email, no_hp, foto_url, created_at';

async function findByEmail(email) {
  const { rows } = await pool.query('SELECT * FROM users WHERE LOWER(email) = LOWER($1)', [email]);
  return rows[0] || null;
}

async function findById(id) {
  const { rows } = await pool.query(`SELECT ${PUBLIC_COLUMNS} FROM users WHERE id = $1`, [id]);
  return rows[0] || null;
}

async function create({ namaUsaha, namaPemilik, email, noHp, passwordHash }) {
  const { rows } = await pool.query(
    `INSERT INTO users (nama_usaha, nama_pemilik, email, no_hp, password_hash)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING ${PUBLIC_COLUMNS}`,
    [namaUsaha, namaPemilik, email, noHp || null, passwordHash]
  );
  return rows[0];
}

async function updatePassword(userId, passwordHash) {
  await pool.query('UPDATE users SET password_hash = $1 WHERE id = $2', [passwordHash, userId]);
}

async function updateFoto(userId, fotoUrl) {
  const { rows } = await pool.query(
    `UPDATE users SET foto_url = $1 WHERE id = $2 RETURNING ${PUBLIC_COLUMNS}`,
    [fotoUrl, userId]
  );
  return rows[0] || null;
}

async function setActiveSession(userId, sid) {
  await pool.query('UPDATE users SET active_session_id = $1 WHERE id = $2', [sid, userId]);
}

async function getActiveSession(userId) {
  const { rows } = await pool.query('SELECT active_session_id FROM users WHERE id = $1', [userId]);
  return rows[0] ? rows[0].active_session_id : undefined; // undefined = akun tidak ada
}

// --- password_reset ---------------------------------------------------------

async function replaceResetCode(userId, codeHash, expiresAt) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('DELETE FROM password_reset WHERE user_id = $1', [userId]);
    await client.query(
      'INSERT INTO password_reset (user_id, code_hash, expires_at) VALUES ($1, $2, $3)',
      [userId, codeHash, expiresAt]
    );
    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

async function findResetCode(userId) {
  const { rows } = await pool.query(
    'SELECT * FROM password_reset WHERE user_id = $1 ORDER BY created_at DESC LIMIT 1',
    [userId]
  );
  return rows[0] || null;
}

async function incrementResetAttempts(id) {
  await pool.query('UPDATE password_reset SET attempts = attempts + 1 WHERE id = $1', [id]);
}

async function deleteResetCodes(userId) {
  await pool.query('DELETE FROM password_reset WHERE user_id = $1', [userId]);
}

module.exports = {
  findByEmail,
  findById,
  create,
  updatePassword,
  updateFoto,
  setActiveSession,
  getActiveSession,
  replaceResetCode,
  findResetCode,
  incrementResetAttempts,
  deleteResetCodes,
};
