const { ApiError } = require('../utils/ApiError');

/**
 * Middleware error terpusat. Semua error (termasuk error tak terduga)
 * dipetakan ke format error standar:
 * { "success": false, "error": { "code", "message" } }
 */
// eslint-disable-next-line no-unused-vars
function errorMiddleware(err, req, res, next) {
  if (err instanceof ApiError) {
    return res.status(err.statusCode).json({
      success: false,
      error: { code: err.code, message: err.message },
    });
  }

  // Error dari driver PostgreSQL: unique violation
  if (err && err.code === '23505') {
    return res.status(400).json({
      success: false,
      error: { code: 'DUPLICATE', message: 'Data sudah ada (duplikat).' },
    });
  }

  console.error(err);
  return res.status(500).json({
    success: false,
    error: { code: 'INTERNAL_ERROR', message: 'Kesalahan server.' },
  });
}

function notFoundMiddleware(req, res) {
  res.status(404).json({
    success: false,
    error: { code: 'NOT_FOUND', message: `Endpoint ${req.method} ${req.originalUrl} tidak ditemukan` },
  });
}

module.exports = { errorMiddleware, notFoundMiddleware };
