// Data contoh (opsional) untuk development lokal.
// Pakai: npm run db:seed
require('dotenv').config();
const bcrypt = require('bcryptjs');
const { Pool } = require('pg');

async function main() {
  const pool = new Pool({
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT) || 5432,
    database: process.env.DB_NAME,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
  });

  const email = 'demo@umkmtitip.test';
  const password = 'password123';
  const passwordHash = await bcrypt.hash(password, 10);

  try {
    const userResult = await pool.query(
      `INSERT INTO users (nama_usaha, nama_pemilik, email, password_hash)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (email) DO UPDATE SET nama_usaha = EXCLUDED.nama_usaha
       RETURNING id`,
      ['UMKM Contoh Kue Basah', 'Budi Santoso', email, passwordHash]
    );
    const userId = userResult.rows[0].id;

    const produk = await pool.query(
      `INSERT INTO produk (user_id, nama_produk, hpp, harga_jual)
       VALUES ($1, 'Lemper Ayam', 2000, 3500)
       RETURNING id`,
      [userId]
    );

    await pool.query(
      `INSERT INTO outlet (user_id, nama_outlet, alamat, no_whatsapp)
       VALUES ($1, 'Toko Kelontong Bu Siti', 'Jl. Mawar No. 10', '628123456789')`,
      [userId]
    );

    console.log('Seed berhasil. Login demo:');
    console.log(`  email: ${email}`);
    console.log(`  password: ${password}`);
    console.log(`  produk id contoh: ${produk.rows[0].id}`);
  } catch (err) {
    console.error('Seed gagal:', err.message);
    process.exitCode = 1;
  } finally {
    await pool.end();
  }
}

main();
