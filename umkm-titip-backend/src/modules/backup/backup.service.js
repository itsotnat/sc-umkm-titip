const crypto = require('crypto');
const { pool } = require('../../config/db');
const { sendMail } = require('../../config/mailer');
const { ApiError } = require('../../utils/ApiError');

const TABEL = {
  produk: 'SELECT id, nama_produk, hpp, harga_jual, updated_at FROM produk WHERE user_id = $1 ORDER BY nama_produk',
  outlet: 'SELECT id, nama_outlet, alamat, no_whatsapp, updated_at FROM outlet WHERE user_id = $1 ORDER BY nama_outlet',
  pemesan: 'SELECT id, nama_pemesan, no_whatsapp FROM pemesan WHERE user_id = $1 ORDER BY nama_pemesan',
  transaksi_titip: `SELECT id, outlet_id, produk_id, to_char(tanggal, 'YYYY-MM-DD') AS tanggal, jumlah_kirim, jumlah_retur, updated_at
                    FROM transaksi_titip WHERE user_id = $1 ORDER BY tanggal, id`,
  pesanan: `SELECT id, pemesan_id, to_char(tanggal_pesan, 'YYYY-MM-DD') AS tanggal_pesan,
                   to_char(tanggal_jatuh_tempo, 'YYYY-MM-DD') AS tanggal_jatuh_tempo,
                   status_selesai, status_lunas, catatan, updated_at
            FROM pesanan WHERE user_id = $1 ORDER BY tanggal_jatuh_tempo, id`,
  pesanan_detail: `SELECT d.id, d.pesanan_id, d.produk_id, d.jumlah
                   FROM pesanan_detail d JOIN pesanan p ON p.id = d.pesanan_id
                   WHERE p.user_id = $1 ORDER BY d.pesanan_id, d.id`,
};

/** Seluruh data milik satu akun sebagai objek JSON (tanpa password/sesi). */
async function kumpulkanData(userId) {
  const data = {};
  for (const [nama, sql] of Object.entries(TABEL)) {
    const { rows } = await pool.query(sql, [userId]);
    data[nama] = rows;
  }
  return data;
}

function hitungJumlah(data) {
  return Object.values(data).reduce((s, rows) => s + rows.length, 0);
}

// Sidik jari tanpa updated_at supaya hanya perubahan isi data yang dihitung.
function sidikJari(data) {
  const bersih = JSON.stringify(data, (k, v) => (k === 'updated_at' ? undefined : v));
  return crypto.createHash('sha256').update(bersih).digest('hex');
}

const BULAN = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

function tanggalWib(d = new Date()) {
  const w = new Date(d.getTime() + 7 * 3600 * 1000);
  return { iso: w.toISOString().slice(0, 10), teks: `${w.getUTCDate()} ${BULAN[w.getUTCMonth()]} ${w.getUTCFullYear()}` };
}

/**
 * Mengirim cadangan JSON ke email akun.
 * `lewatiBilaSama`: dipakai job malam — kalau data tidak berubah sejak cadangan terakhir, tidak kirim.
 * Mengembalikan { terkirim, alasan?, jumlah }.
 */
async function kirimCadangan(userId, { lewatiBilaSama = false } = {}) {
  const { rows } = await pool.query(
    'SELECT id, nama_usaha, nama_pemilik, email, last_backup_hash FROM users WHERE id = $1',
    [userId]
  );
  const user = rows[0];
  if (!user) throw ApiError.notFound('Akun tidak ditemukan');

  const data = await kumpulkanData(userId);
  const jumlah = hitungJumlah(data);
  if (jumlah === 0) return { terkirim: false, alasan: 'KOSONG', jumlah };

  const hash = sidikJari(data);
  if (lewatiBilaSama && user.last_backup_hash === hash) return { terkirim: false, alasan: 'TIDAK_BERUBAH', jumlah };

  const tgl = tanggalWib();
  const berkas = {
    aplikasi: 'UMKM Titip',
    versi_format: 1,
    dibuat_pada: new Date().toISOString(),
    akun: { email: user.email, nama_usaha: user.nama_usaha, nama_pemilik: user.nama_pemilik },
    data,
  };

  await sendMail({
    to: user.email,
    subject: `Cadangan data UMKM Titip - ${tgl.teks}`,
    text: [
      `Halo ${user.nama_pemilik},`,
      '',
      `Terlampir cadangan data UMKM Titip (${user.nama_usaha}) per ${tgl.teks}.`,
      `Isi: ${data.produk.length} produk, ${data.outlet.length} outlet, ${data.transaksi_titip.length} catatan titip, ${data.pesanan.length} pesanan.`,
      '',
      'Simpan file ini di tempat aman. Data juga tersimpan di server dan akan kembali otomatis saat Anda masuk di HP baru.',
      'Catatan: hanya data yang sudah tersinkron ke server yang ikut tercadang.',
      '',
      '— UMKM Titip (email otomatis, mohon tidak membalas)',
    ].join('\n'),
    attachments: [
      {
        filename: `umkm-titip-cadangan-${tgl.iso}.json`,
        content: JSON.stringify(berkas, null, 2),
        contentType: 'application/json',
      },
    ],
  });

  await pool.query('UPDATE users SET last_backup_at = now(), last_backup_hash = $1 WHERE id = $2', [hash, userId]);
  return { terkirim: true, jumlah };
}

module.exports = { kirimCadangan, kumpulkanData };
