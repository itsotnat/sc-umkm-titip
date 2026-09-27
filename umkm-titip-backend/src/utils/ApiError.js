/**
 * Error terstruktur yang dipetakan langsung ke format error standar API
 * (lihat dokumen REST API Spec, Bagian 9).
 */
class ApiError extends Error {
  constructor(statusCode, code, message) {
    super(message);
    this.statusCode = statusCode;
    this.code = code;
  }

  static badRequest(message, code = 'VALIDATION_ERROR') {
    return new ApiError(400, code, message);
  }

  static unauthorized(message = 'Tidak terautentikasi / token tidak valid') {
    return new ApiError(401, 'UNAUTHORIZED', message);
  }

  static forbidden(message = 'Tidak diizinkan') {
    return new ApiError(403, 'FORBIDDEN', message);
  }

  static notFound(message = 'Data tidak ditemukan') {
    return new ApiError(404, 'NOT_FOUND', message);
  }

  static internal(message = 'Kesalahan server') {
    return new ApiError(500, 'INTERNAL_ERROR', message);
  }
}

module.exports = { ApiError };
