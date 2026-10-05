const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const userRepository = require('./user.repository');
const { ApiError } = require('../../utils/ApiError');

const UPLOAD_ROOT = process.env.UPLOAD_DIR || path.join(process.cwd(), 'uploads');
const AVATAR_DIR = path.join(UPLOAD_ROOT, 'avatars');
const URL_PREFIX = '/uploads/avatars/';

/** Mengenali tipe gambar dari byte awal file, bukan dari header/nama dari klien. */
function detectImageExt(buf) {
  if (buf.length > 12 && buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return 'jpg';
  if (buf.length > 12 && buf.slice(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) return 'png';
  if (buf.length > 12 && buf.slice(0, 4).toString() === 'RIFF' && buf.slice(8, 12).toString() === 'WEBP') return 'webp';
  return null;
}

function removeOldFile(fotoUrl) {
  if (!fotoUrl || !fotoUrl.startsWith(URL_PREFIX)) return;
  const file = path.basename(fotoUrl);
  fs.promises.unlink(path.join(AVATAR_DIR, file)).catch(() => {});
}

async function setFoto(userId, buffer) {
  if (!buffer) throw ApiError.badRequest('File foto wajib diunggah (field "foto")');
  const ext = detectImageExt(buffer);
  if (!ext) throw ApiError.badRequest('Format foto harus JPG, PNG, atau WEBP');

  const current = await userRepository.findById(userId);
  if (!current) throw ApiError.notFound('Akun tidak ditemukan');

  await fs.promises.mkdir(AVATAR_DIR, { recursive: true });
  const filename = `${crypto.randomUUID()}.${ext}`;
  await fs.promises.writeFile(path.join(AVATAR_DIR, filename), buffer);

  const user = await userRepository.updateFoto(userId, `${URL_PREFIX}${filename}`);
  removeOldFile(current.foto_url);
  return user;
}

async function deleteFoto(userId) {
  const current = await userRepository.findById(userId);
  if (!current) throw ApiError.notFound('Akun tidak ditemukan');
  const user = await userRepository.updateFoto(userId, null);
  removeOldFile(current.foto_url);
  return user;
}

module.exports = { setFoto, deleteFoto, UPLOAD_ROOT };
