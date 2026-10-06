const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const userRepository = require('./user.repository');
const { sendMail } = require('../../config/mailer');
const { buildResetEmail } = require('./reset-email');
const { ApiError } = require('../../utils/ApiError');

const MIN_PASSWORD = 8;
const RESET_CODE_TTL_MENIT = 15;
const RESET_RESEND_COOLDOWN_DETIK = 60;
const RESET_MAX_ATTEMPTS = 5;
const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function signToken(userId, sid) {
  return jwt.sign({ sub: userId, sid }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN || '7d',
  });
}

function normalizeEmail(email) {
  return String(email || '').trim().toLowerCase();
}

function validatePassword(password) {
  if (typeof password !== 'string' || password.length < MIN_PASSWORD) {
    throw ApiError.badRequest(`Password minimal ${MIN_PASSWORD} karakter`);
  }
  if (password.length > 72) {
    // Batas efektif bcrypt: karakter setelah byte ke-72 diabaikan.
    throw ApiError.badRequest('Password maksimal 72 karakter');
  }
}

async function register({ namaUsaha, namaPemilik, email, noHp, password }) {
  namaUsaha = String(namaUsaha || '').trim();
  namaPemilik = String(namaPemilik || '').trim();
  email = normalizeEmail(email);

  if (!namaUsaha || !namaPemilik || !email || !password) {
    throw ApiError.badRequest('nama_usaha, nama_pemilik, email, dan password wajib diisi');
  }
  if (!EMAIL_REGEX.test(email)) {
    throw ApiError.badRequest('Format email tidak valid');
  }
  validatePassword(password);

  const existing = await userRepository.findByEmail(email);
  if (existing) {
    throw ApiError.badRequest('Email sudah terdaftar', 'EMAIL_TAKEN');
  }

  const passwordHash = await bcrypt.hash(password, 10);
  const user = await userRepository.create({ namaUsaha, namaPemilik, email, noHp, passwordHash });
  const sid = crypto.randomUUID();
  await userRepository.setActiveSession(user.id, sid);
  const token = signToken(user.id, sid);
  return { user, token };
}

async function login({ email, password }) {
  if (!email || !password) {
    throw ApiError.badRequest('email dan password wajib diisi');
  }

  const user = await userRepository.findByEmail(normalizeEmail(email));
  if (!user) {
    throw new ApiError(401, 'INVALID_CREDENTIALS', 'Email atau password salah');
  }

  const match = await bcrypt.compare(password, user.password_hash);
  if (!match) {
    throw new ApiError(401, 'INVALID_CREDENTIALS', 'Email atau password salah');
  }

  // Login baru menggantikan sesi lama: token di perangkat sebelumnya langsung tidak berlaku.
  const sid = crypto.randomUUID();
  await userRepository.setActiveSession(user.id, sid);
  const token = signToken(user.id, sid);
  delete user.password_hash;
  delete user.active_session_id;
  return { user, token };
}

async function getProfile(userId) {
  const user = await userRepository.findById(userId);
  if (!user) throw ApiError.notFound('Akun tidak ditemukan');
  return user;
}

// --- Lupa password -----------------------------------------------------------

function hashResetCode(code) {
  // HMAC dengan JWT_SECRET sebagai pepper: kode 6 digit tidak tersimpan polos di DB.
  return crypto.createHmac('sha256', process.env.JWT_SECRET).update(String(code)).digest('hex');
}

/**
 * Selalu mengembalikan hasil yang sama, ada atau tidaknya email di database,
 * supaya endpoint ini tidak bisa dipakai untuk menebak email yang terdaftar.
 */
async function forgotPassword({ email }) {
  email = normalizeEmail(email);
  if (!EMAIL_REGEX.test(email)) {
    throw ApiError.badRequest('Format email tidak valid');
  }
  const generic = { message: 'Jika email terdaftar, kode reset telah dikirim.' };

  const user = await userRepository.findByEmail(email);
  if (!user) return generic;

  const last = await userRepository.findResetCode(user.id);
  if (last && Date.now() - new Date(last.created_at).getTime() < RESET_RESEND_COOLDOWN_DETIK * 1000) {
    return generic;
  }

  const code = String(crypto.randomInt(0, 1000000)).padStart(6, '0');
  const expiresAt = new Date(Date.now() + RESET_CODE_TTL_MENIT * 60 * 1000);
  await userRepository.replaceResetCode(user.id, hashResetCode(code), expiresAt);

  try {
    await sendMail({
      to: user.email,
      ...buildResetEmail({ nama: user.nama_pemilik, email: user.email, code, ttlMenit: RESET_CODE_TTL_MENIT }),
    });
  } catch (err) {
    // Jangan bocorkan kegagalan SMTP ke klien (tetap respons generik), cukup dicatat.
    console.error('[forgotPassword] Gagal mengirim email:', err.message);
  }
  return generic;
}

async function resetPassword({ email, code, newPassword }) {
  email = normalizeEmail(email);
  if (!email || !code || !newPassword) {
    throw ApiError.badRequest('email, code, dan new_password wajib diisi');
  }
  validatePassword(newPassword);

  const invalid = () => ApiError.badRequest('Kode salah atau sudah kedaluwarsa', 'INVALID_RESET_CODE');

  const user = await userRepository.findByEmail(email);
  if (!user) throw invalid();

  const reset = await userRepository.findResetCode(user.id);
  if (!reset || new Date(reset.expires_at).getTime() < Date.now() || reset.attempts >= RESET_MAX_ATTEMPTS) {
    throw invalid();
  }

  const expected = Buffer.from(reset.code_hash, 'hex');
  const given = Buffer.from(hashResetCode(String(code).trim()), 'hex');
  if (expected.length !== given.length || !crypto.timingSafeEqual(expected, given)) {
    await userRepository.incrementResetAttempts(reset.id);
    throw invalid();
  }

  const passwordHash = await bcrypt.hash(newPassword, 10);
  await userRepository.updatePassword(user.id, passwordHash);
  await userRepository.deleteResetCodes(user.id);
  await userRepository.setActiveSession(user.id, null); // keluarkan semua perangkat
  return { message: 'Password berhasil diubah. Silakan masuk dengan password baru.' };
}

module.exports = { register, login, getProfile, forgotPassword, resetPassword };
