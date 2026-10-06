const rateLimit = require('express-rate-limit');

function limiter({ windowMs, limit, message }) {
  return rateLimit({
    windowMs,
    limit,
    standardHeaders: 'draft-7',
    legacyHeaders: false,
    handler: (req, res) =>
      res.status(429).json({ success: false, error: { code: 'TOO_MANY_REQUESTS', message } }),
  });
}

const MENIT = 60 * 1000;

// Login & register: cukup longgar untuk pemakaian normal (banyak HP bisa
// berbagi satu IP operator seluler), tapi menahan tebak-tebak password massal.
const authLimiter = limiter({
  windowMs: 15 * MENIT,
  limit: 30,
  message: 'Terlalu banyak percobaan. Coba lagi beberapa menit lagi.',
});

// Lupa password diperketat karena memicu pengiriman email.
const forgotLimiter = limiter({
  windowMs: 15 * MENIT,
  limit: 5,
  message: 'Terlalu banyak permintaan kode. Coba lagi dalam 15 menit.',
});

const resetLimiter = limiter({
  windowMs: 15 * MENIT,
  limit: 10,
  message: 'Terlalu banyak percobaan reset. Coba lagi dalam 15 menit.',
});

// Ganti password & kirim backup manual: dibatasi per akun (bukan per IP) karena sudah terautentikasi.
function perAkun({ windowMs, limit, message }) {
  return rateLimit({
    windowMs,
    limit,
    standardHeaders: 'draft-7',
    legacyHeaders: false,
    keyGenerator: (req) => req.userId || 'anon',
    validate: { keyGeneratorIpFallback: false },
    handler: (req, res) =>
      res.status(429).json({ success: false, error: { code: 'TOO_MANY_REQUESTS', message } }),
  });
}

const changePasswordLimiter = perAkun({
  windowMs: 15 * MENIT,
  limit: 5,
  message: 'Terlalu banyak percobaan ganti password. Coba lagi dalam 15 menit.',
});

const backupLimiter = perAkun({
  windowMs: 10 * MENIT,
  limit: 2,
  message: 'Cadangan baru saja dikirim. Coba lagi dalam beberapa menit.',
});

module.exports = { authLimiter, forgotLimiter, resetLimiter, changePasswordLimiter, backupLimiter };
