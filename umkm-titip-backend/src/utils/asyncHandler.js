/**
 * Membungkus controller async supaya reject-nya otomatis diteruskan
 * ke middleware error, tanpa perlu try/catch berulang di tiap controller.
 */
const asyncHandler = (fn) => (req, res, next) => {
  Promise.resolve(fn(req, res, next)).catch(next);
};

module.exports = { asyncHandler };
