/**
 * Template email kode reset password. Ada versi teks polos dan HTML;
 * keduanya berisi hal yang sama supaya terbaca baik di semua aplikasi email.
 */
function escapeHtml(str) {
  return String(str).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

function buildResetEmail({ nama, email, code, ttlMenit }) {
  const subject = `${code} adalah kode reset password UMKM Titip Anda`;

  const text = [
    `Halo ${nama},`,
    '',
    `Kami menerima permintaan untuk mengatur ulang password akun UMKM Titip dengan email ${email}.`,
    '',
    `Kode verifikasi Anda: ${code}`,
    '',
    `Masukkan kode ini di aplikasi UMKM Titip. Kode berlaku ${ttlMenit} menit dan hanya bisa dipakai satu kali.`,
    '',
    'Demi keamanan, jangan bagikan kode ini kepada siapa pun, termasuk pihak yang mengaku dari UMKM Titip.',
    '',
    'Tidak merasa meminta reset password? Abaikan saja email ini, password Anda tidak akan berubah.',
    '',
    '— Tim UMKM Titip',
  ].join('\n');

  const html = `<!DOCTYPE html>
<html lang="id">
<body style="margin:0;padding:0;background:#f4f6f8;font-family:Arial,Helvetica,sans-serif;color:#1f2933;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f4f6f8;padding:24px 12px;">
    <tr><td align="center">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;background:#ffffff;border-radius:12px;overflow:hidden;">
        <tr><td style="background:#2e7d32;padding:20px 24px;color:#ffffff;font-size:20px;font-weight:bold;">UMKM Titip</td></tr>
        <tr><td style="padding:24px;">
          <p style="margin:0 0 12px;font-size:16px;">Halo ${escapeHtml(nama)},</p>
          <p style="margin:0 0 20px;font-size:14px;line-height:1.5;">
            Kami menerima permintaan untuk mengatur ulang password akun UMKM Titip dengan email
            <strong>${escapeHtml(email)}</strong>. Gunakan kode verifikasi berikut di aplikasi:
          </p>
          <div style="text-align:center;margin:0 0 20px;">
            <span style="display:inline-block;background:#f1f8e9;border:1px dashed #2e7d32;border-radius:8px;padding:14px 24px;font-size:32px;font-weight:bold;letter-spacing:8px;color:#1b5e20;">${code}</span>
          </div>
          <p style="margin:0 0 12px;font-size:14px;line-height:1.5;">
            Kode berlaku <strong>${ttlMenit} menit</strong> dan hanya bisa dipakai satu kali.
          </p>
          <p style="margin:0 0 12px;font-size:13px;line-height:1.5;color:#52606d;">
            Demi keamanan, jangan bagikan kode ini kepada siapa pun, termasuk pihak yang mengaku dari UMKM Titip.
          </p>
          <p style="margin:0;font-size:13px;line-height:1.5;color:#52606d;">
            Tidak merasa meminta reset password? Abaikan saja email ini, password Anda tidak akan berubah.
          </p>
        </td></tr>
        <tr><td style="padding:14px 24px;background:#fafafa;font-size:12px;color:#9aa5b1;text-align:center;">
          Email otomatis dari aplikasi UMKM Titip. Mohon tidak membalas email ini.
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;

  return { subject, text, html };
}

module.exports = { buildResetEmail };
