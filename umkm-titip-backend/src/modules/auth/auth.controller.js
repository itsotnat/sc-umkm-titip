const authService = require('./auth.service');
const { created, ok } = require('../../utils/response');
const { asyncHandler } = require('../../utils/asyncHandler');

const register = asyncHandler(async (req, res) => {
  const { nama_usaha, nama_pemilik, email, no_hp, password } = req.body;
  const result = await authService.register({
    namaUsaha: nama_usaha,
    namaPemilik: nama_pemilik,
    email,
    noHp: no_hp,
    password,
  });
  created(res, result);
});

const login = asyncHandler(async (req, res) => {
  const { email, password } = req.body;
  const result = await authService.login({ email, password });
  ok(res, result);
});

module.exports = { register, login };
