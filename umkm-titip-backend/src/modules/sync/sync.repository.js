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

// ---------------------------------------------------------------------------
// Push dari klien (offline-first): id dibuat di sisi mobile (UUID), jadi semua
// operasi berupa UPSERT berdasarkan id dan hanya boleh menyentuh baris milik
// user yang sama (klausa WHERE user_id pada DO UPDATE). Aman dikirim ulang.
// ---------------------------------------------------------------------------

async function upsertProduk(userId, p) {
  const { rows } = await pool.query(
    `INSERT INTO produk (id, user_id, nama_produk, hpp, harga_jual, sync_status, updated_at)
     VALUES ($1, $2, $3, $4, $5, 'synced', now())
     ON CONFLICT (id) DO UPDATE SET nama_produk = EXCLUDED.nama_produk, hpp = EXCLUDED.hpp,
       harga_jual = EXCLUDED.harga_jual, sync_status = 'synced', updated_at = now()
     WHERE produk.user_id = $2
     RETURNING id`,
    [p.id, userId, p.nama_produk, p.hpp, p.harga_jual]
  );
  return rows[0] || null;
}

async function upsertOutlet(userId, o) {
  const { rows } = await pool.query(
    `INSERT INTO outlet (id, user_id, nama_outlet, alamat, no_whatsapp, sync_status, updated_at)
     VALUES ($1, $2, $3, $4, $5, 'synced', now())
     ON CONFLICT (id) DO UPDATE SET nama_outlet = EXCLUDED.nama_outlet, alamat = EXCLUDED.alamat,
       no_whatsapp = EXCLUDED.no_whatsapp, sync_status = 'synced', updated_at = now()
     WHERE outlet.user_id = $2
     RETURNING id`,
    [o.id, userId, o.nama_outlet, o.alamat || null, o.no_whatsapp || null]
  );
  return rows[0] || null;
}

async function upsertPemesan(userId, m) {
  const { rows } = await pool.query(
    `INSERT INTO pemesan (id, user_id, nama_pemesan, no_whatsapp, sync_status)
     VALUES ($1, $2, $3, $4, 'synced')
     ON CONFLICT (id) DO UPDATE SET nama_pemesan = EXCLUDED.nama_pemesan,
       no_whatsapp = EXCLUDED.no_whatsapp, sync_status = 'synced'
     WHERE pemesan.user_id = $2
     RETURNING id`,
    [m.id, userId, m.nama_pemesan, m.no_whatsapp || null]
  );
  return rows[0] || null;
}

/**
 * Upsert pesanan header + ganti seluruh detail dalam satu transaksi.
 * Pemesan dan semua produk yang dirujuk wajib milik user yang sama.
 */
async function upsertPesanan(userId, p) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const pemesan = await client.query('SELECT 1 FROM pemesan WHERE id = $1 AND user_id = $2', [p.pemesan_id, userId]);
    if (pemesan.rowCount === 0) throw new Error('Pemesan belum ada di server');

    const produkIds = [...new Set(p.items.map((i) => i.produk_id))];
    const produk = await client.query('SELECT id FROM produk WHERE id = ANY($1::uuid[]) AND user_id = $2', [produkIds, userId]);
    if (produk.rowCount !== produkIds.length) throw new Error('Ada produk di pesanan yang belum ada di server');

    const header = await client.query(
      `INSERT INTO pesanan (id, user_id, pemesan_id, tanggal_pesan, tanggal_jatuh_tempo,
                            status_selesai, status_lunas, catatan, sync_status, updated_at)
       VALUES ($1, $2, $3, COALESCE($4::date, CURRENT_DATE), $5, $6, $7, $8, 'synced', now())
       ON CONFLICT (id) DO UPDATE SET pemesan_id = EXCLUDED.pemesan_id,
         tanggal_jatuh_tempo = EXCLUDED.tanggal_jatuh_tempo,
         status_selesai = EXCLUDED.status_selesai, status_lunas = EXCLUDED.status_lunas,
         catatan = EXCLUDED.catatan, sync_status = 'synced', updated_at = now()
       WHERE pesanan.user_id = $2
       RETURNING id`,
      [p.id, userId, p.pemesan_id, p.tanggal_pesan || null, p.tanggal_jatuh_tempo,
       p.status_selesai === true, p.status_lunas === true, p.catatan || null]
    );
    if (header.rowCount === 0) throw new Error('Pesanan bukan milik akun ini');

    await client.query('DELETE FROM pesanan_detail WHERE pesanan_id = $1', [p.id]);
    for (const item of p.items) {
      await client.query(
        'INSERT INTO pesanan_detail (pesanan_id, produk_id, jumlah) VALUES ($1, $2, $3)',
        [p.id, item.produk_id, item.jumlah]
      );
    }

    await client.query('COMMIT');
    return header.rows[0];
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

const DELETE_TABLES = { produk: 'produk', outlet: 'outlet', pemesan: 'pemesan', pesanan: 'pesanan' };

/** Hapus idempoten: id yang sudah tidak ada dianggap berhasil. */
async function deleteByIds(userId, entity, ids) {
  const table = DELETE_TABLES[entity];
  if (!table || ids.length === 0) return;
  await pool.query(`DELETE FROM ${table} WHERE id = ANY($1::uuid[]) AND user_id = $2`, [ids, userId]);
}

module.exports = { changedSince, upsertProduk, upsertOutlet, upsertPemesan, upsertPesanan, deleteByIds };
