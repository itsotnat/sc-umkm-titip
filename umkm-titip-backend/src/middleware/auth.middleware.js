const jwt = require('jsonwebtoken');
const { ApiError } = require('../utils/ApiError');
const userRepository = require('../modules/auth/user.repository');

/**
 * Memverifikasi Bearer token JWT dan mengisi req.userId dari payload token.
 * Setiap query di layer repository WAJIB memfilter berdasarkan req.userId,
 * bukan dari parameter request, sesuai kebijakan multi-tenant di dokumen SAD Bagian 7.
 *
 * Satu akun = satu sesi aktif: token membawa `sid`, dan harus sama dengan
 * users.active_session_id. Login di perangkat lain mengganti sid sehingga
 * token perangkat lama ditolak dengan kode SESSION_REPLACED.
 */
async function authMiddleware(req, res, next) {
  const header = req.headers.authorization || '';
  const [scheme, token] = header.split(' ');

  if (scheme !== 'Bearer' || !token) {
    return next(ApiError.unauthorized());
  }

  let payload;
  try {
    payload = jwt.verify(token, process.env.JWT_SECRET);
  } catch (err) {
    return next(ApiError.unauthorized('Token tidak valid atau kedaluwarsa'));
  }

  try {
    const active = await userRepository.getActiveSession(payload.sub);
    if (active === undefined || !payload.sid) {
      return next(ApiError.unauthorized('Sesi tidak valid, silakan masuk kembali'));
    }
    if (active !== payload.sid) {
      return next(
        new ApiError(401, 'SESSION_REPLACED', 'Akun ini sedang digunakan di perangkat lain. Silakan masuk kembali.')
      );
    }
    req.userId = payload.sub;
    next();
  } catch (err) {
    next(err);
  }
}

module.exports = { authMiddleware };
