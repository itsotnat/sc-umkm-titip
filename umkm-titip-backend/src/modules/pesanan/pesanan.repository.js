const { pool } = require('../../config/db');

async function findAllByUser(userId, { status, dari, sampai }) {
  const conditions = ['p.user_id = $1'];
  const params = [userId];

  if (status === 'selesai') {
    conditions.push('p.status_selesai = true');
  } else if (status === 'belum_selesai') {
    conditions.push('p.status_selesai = false');
  }
  if (dari) {
    params.push(dari);
    conditions.push(`p.tanggal_jatuh_tempo >= $${params.length}`);
  }
  if (sampai) {
    params.push(sampai);
    conditions.push(`p.tanggal_jatuh_tempo <= $${params.length}`);
  }

  const { rows } = await pool.query(
    `SELECT p.*, m.nama_pemesan, m.no_whatsapp
     FROM pesanan p
     JOIN pemesan m ON m.id = p.pemesan_id
     WHERE ${conditions.join(' AND ')}
     ORDER BY p.tanggal_jatuh_tempo ASC`,
    params
  );
  return rows;
}

async function findDetailByPesanan(pesananId) {
  const { rows } = await pool.query(
    `SELECT d.*, pr.nama_produk
     FROM pesanan_detail d
     JOIN produk pr ON pr.id = d.produk_id
     WHERE d.pesanan_id = $1`,
    [pesananId]
  );
  return rows;
}

async function create(client, userId, { pemesanId, tanggalJatuhTempo, catatan }) {
  const { rows } = await client.query(
    `INSERT INTO pesanan (user_id, pemesan_id, tanggal_jatuh_tempo, catatan)
     VALUES ($1, $2, $3, $4) RETURNING *`,
    [userId, pemesanId, tanggalJatuhTempo, catatan || null]
  );
  return rows[0];
}

async function addDetailItem(client, pesananId, { produkId, jumlah }) {
  await client.query(
    `INSERT INTO pesanan_detail (pesanan_id, produk_id, jumlah) VALUES ($1, $2, $3)`,
    [pesananId, produkId, jumlah]
  );
}

async function updateStatus(id, userId, { statusSelesai, statusLunas }) {
  const fields = [];
  const params = [];

  if (statusSelesai !== undefined) {
    params.push(statusSelesai);
    fields.push(`status_selesai = $${params.length}`);
  }
  if (statusLunas !== undefined) {
    params.push(statusLunas);
    fields.push(`status_lunas = $${params.length}`);
  }
  if (fields.length === 0) return null;

  params.push(id, userId);
  const { rows } = await pool.query(
    `UPDATE pesanan SET ${fields.join(', ')}, updated_at = now()
     WHERE id = $${params.length - 1} AND user_id = $${params.length} RETURNING *`,
    params
  );
  return rows[0] || null;
}

async function remove(id, userId) {
  const { rowCount } = await pool.query('DELETE FROM pesanan WHERE id = $1 AND user_id = $2', [id, userId]);
  return rowCount > 0;
}

module.exports = { findAllByUser, findDetailByPesanan, create, addDetailItem, updateStatus, remove };
