const jwt = require('jsonwebtoken');
const { ApiError } = require('../utils/ApiError');

/**
 * Memverifikasi Bearer token JWT dan mengisi req.userId dari payload token.
 * Setiap query di layer repository WAJIB memfilter berdasarkan req.userId,
 * bukan dari parameter request, sesuai kebijakan multi-tenant di dokumen SAD Bagian 7.
 */
function authMiddleware(req, res, next) {
  const header = req.headers.authorization || '';
  const [scheme, token] = header.split(' ');

  if (scheme !== 'Bearer' || !token) {
    return next(ApiError.unauthorized());
  }

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    req.userId = payload.sub;
    next();
  } catch (err) {
    next(ApiError.unauthorized('Token tidak valid atau kedaluwarsa'));
  }
}

module.exports = { authMiddleware };
