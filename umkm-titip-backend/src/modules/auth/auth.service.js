const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const userRepository = require('./user.repository');
const { ApiError } = require('../../utils/ApiError');

function signToken(userId) {
  return jwt.sign({ sub: userId }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN || '7d',
  });
}

async function register({ namaUsaha, namaPemilik, email, noHp, password }) {
  if (!namaUsaha || !namaPemilik || !email || !password) {
    throw ApiError.badRequest('nama_usaha, nama_pemilik, email, dan password wajib diisi');
  }
  if (password.length < 6) {
    throw ApiError.badRequest('Password minimal 6 karakter');
  }

  const existing = await userRepository.findByEmail(email);
  if (existing) {
    throw ApiError.badRequest('Email sudah terdaftar', 'EMAIL_TAKEN');
  }

  const passwordHash = await bcrypt.hash(password, 10);
  const user = await userRepository.create({ namaUsaha, namaPemilik, email, noHp, passwordHash });
  const token = signToken(user.id);
  return { user, token };
}

async function login({ email, password }) {
  if (!email || !password) {
    throw ApiError.badRequest('email dan password wajib diisi');
  }

  const user = await userRepository.findByEmail(email);
  if (!user) {
    throw new ApiError(401, 'INVALID_CREDENTIALS', 'Email atau password salah');
  }

  const match = await bcrypt.compare(password, user.password_hash);
  if (!match) {
    throw new ApiError(401, 'INVALID_CREDENTIALS', 'Email atau password salah');
  }

  const token = signToken(user.id);
  delete user.password_hash;
  return { user, token };
}

module.exports = { register, login };
