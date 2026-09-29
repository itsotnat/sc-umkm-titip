// Migrasi satu kali: melonggarkan kolom jumlah_retur di tabel transaksi_titip
// dari NOT NULL DEFAULT 0 menjadi boleh NULL.
//
// NULL sekarang berarti "retur belum diinput sama sekali", beda dari 0 yang
// berarti "sudah dikonfirmasi habis terjual/tidak ada retur". db/schema.sql
// sudah diupdate supaya instalasi baru langsung dapat skema ini, tapi
// `npm run db:migrate` (CREATE TABLE IF NOT EXISTS) tidak akan mengubah
// kolom di database yang sudah berjalan (mis. yang sudah dideploy di VPS),
// makanya perlu dijalankan sekali lewat script ini.
//
// Pakai: npm run db:patch-retur-nullable
require('dotenv').config();
const { Pool } = require('pg');

async function main() {
  const pool = new Pool({
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT) || 5432,
    database: process.env.DB_NAME,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
  });

  console.log('Menjalankan migrasi: jumlah_retur -> boleh NULL ...');
  try {
    await pool.query(`
      ALTER TABLE transaksi_titip
        ALTER COLUMN jumlah_retur DROP NOT NULL,
        ALTER COLUMN jumlah_retur DROP DEFAULT;
    `);
    console.log('Migrasi berhasil: jumlah_retur sekarang boleh NULL.');
  } catch (err) {
    console.error('Migrasi gagal:', err.message);
    process.exitCode = 1;
  } finally {
    await pool.end();
  }
}

main();
