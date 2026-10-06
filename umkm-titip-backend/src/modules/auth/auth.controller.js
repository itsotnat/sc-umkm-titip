const authService = require('./auth.service');
const profileService = require('./profile.service');
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

const forgotPassword = asyncHandler(async (req, res) => {
  ok(res, await authService.forgotPassword({ email: req.body.email }));
});

const resetPassword = asyncHandler(async (req, res) => {
  const { email, code, new_password } = req.body;
  ok(res, await authService.resetPassword({ email, code, newPassword: new_password }));
});

const me = asyncHandler(async (req, res) => {
  ok(res, { user: await authService.getProfile(req.userId) });
});

const updateMe = asyncHandler(async (req, res) => {
  const { nama_usaha, nama_pemilik, no_hp } = req.body;
  ok(res, { user: await authService.updateProfile(req.userId, { namaUsaha: nama_usaha, namaPemilik: nama_pemilik, noHp: no_hp }) });
});

const changePassword = asyncHandler(async (req, res) => {
  const { current_password, new_password } = req.body;
  ok(res, await authService.changePassword(req.userId, { currentPassword: current_password, newPassword: new_password }));
});

const uploadFoto = asyncHandler(async (req, res) => {
  const user = await profileService.setFoto(req.userId, req.file && req.file.buffer);
  ok(res, { user });
});

const deleteFoto = asyncHandler(async (req, res) => {
  ok(res, { user: await profileService.deleteFoto(req.userId) });
});

module.exports = { register, login, forgotPassword, resetPassword, me, updateMe, changePassword, uploadFoto, deleteFoto };
