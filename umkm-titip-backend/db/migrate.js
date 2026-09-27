// Menjalankan db/schema.sql terhadap database yang dikonfigurasi di .env
// Pakai: npm run db:migrate
require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');

async function main() {
  const pool = new Pool({
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT) || 5432,
    database: process.env.DB_NAME,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
  });

  const schemaPath = path.join(__dirname, 'schema.sql');
  const sql = fs.readFileSync(schemaPath, 'utf8');

  console.log('Menjalankan migrasi dari db/schema.sql ...');
  try {
    await pool.query(sql);
    console.log('Migrasi berhasil.');
  } catch (err) {
    console.error('Migrasi gagal:', err.message);
    process.exitCode = 1;
  } finally {
    await pool.end();
  }
}

main();
