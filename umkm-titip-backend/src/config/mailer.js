const nodemailer = require('nodemailer');

let transporter = null;

function isConfigured() {
  return Boolean(process.env.SMTP_USER && process.env.SMTP_PASS);
}

function getTransporter() {
  if (!transporter) {
    const port = Number(process.env.SMTP_PORT) || 465;
    transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST || 'smtp.gmail.com',
      port,
      secure: port === 465,
      auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
    });
  }
  return transporter;
}

/**
 * Mengirim email. Kalau SMTP belum dikonfigurasi (mis. saat development),
 * isi email dicetak ke log supaya alur tetap bisa dicoba tanpa mengirim apa pun.
 */
async function sendMail({ to, subject, text, html, attachments }) {
  if (!isConfigured()) {
    console.warn(`[mailer] SMTP belum dikonfigurasi. Email ke ${to} tidak dikirim.\n${subject}\n${text}`);
    return;
  }
  await getTransporter().sendMail({
    from: process.env.MAIL_FROM || `UMKM Titip <${process.env.SMTP_USER}>`,
    to,
    subject,
    text,
    html,
    attachments,
  });
}

module.exports = { sendMail, isConfigured };
