const { pool } = require('../config/db');
const { isConfigured } = require('../config/mailer');
const { kirimCadangan } = require('../modules/backup/backup.service');

// WIB = UTC+7 tanpa DST, jadi 00:00 WIB selalu 17:00 UTC hari sebelumnya.
const JAM_UTC = 17;

function msKeBerikutnya(sekarang = new Date()) {
  const target = new Date(Date.UTC(sekarang.getUTCFullYear(), sekarang.getUTCMonth(), sekarang.getUTCDate(), JAM_UTC, 0, 5));
  if (target <= sekarang) target.setUTCDate(target.getUTCDate() + 1);
  return target - sekarang;
}

async function jalankanSekali() {
  const { rows } = await pool.query('SELECT id, email FROM users ORDER BY created_at');
  let terkirim = 0;
  let dilewati = 0;
  let gagal = 0;
  for (const u of rows) {
    try {
      const hasil = await kirimCadangan(u.id, { lewatiBilaSama: true });
      if (hasil.terkirim) terkirim++;
      else dilewati++;
    } catch (err) {
      gagal++;
      console.error(`[backup] gagal untuk ${u.email}:`, err.message);
    }
    // Jeda kecil agar tidak memicu batas kecepatan SMTP.
    await new Promise((r) => setTimeout(r, 1500));
  }
  console.log(`[backup] selesai: ${terkirim} terkirim, ${dilewati} dilewati, ${gagal} gagal`);
}

function mulai() {
  if (process.env.BACKUP_ENABLED === 'false') {
    console.log('[backup] dinonaktifkan (BACKUP_ENABLED=false)');
    return;
  }
  if (!isConfigured()) {
    console.warn('[backup] SMTP belum dikonfigurasi, cadangan otomatis tidak dijadwalkan');
    return;
  }
  const jadwalkan = () => {
    const tunggu = msKeBerikutnya();
    console.log(`[backup] cadangan berikutnya 00:00 WIB (${Math.round(tunggu / 60000)} menit lagi)`);
    const t = setTimeout(async () => {
      try {
        await jalankanSekali();
      } catch (err) {
        console.error('[backup] job gagal:', err.message);
      }
      jadwalkan();
    }, tunggu);
    t.unref();
  };
  jadwalkan();
}

module.exports = { mulai, jalankanSekali, msKeBerikutnya };
