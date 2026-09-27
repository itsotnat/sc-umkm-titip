const produkRepository = require('./produk.repository');
const { ApiError } = require('../../utils/ApiError');

async function list(userId) {
  return produkRepository.findAllByUser(userId);
}

function validate({ namaProduk, hpp, hargaJual }) {
  if (!namaProduk || !namaProduk.trim()) {
    throw ApiError.badRequest('nama_produk wajib diisi');
  }
  if (hpp === undefined || hpp < 0) {
    throw ApiError.badRequest('hpp wajib diisi dan tidak boleh negatif');
  }
  if (hargaJual === undefined || hargaJual < 0) {
    throw ApiError.badRequest('harga_jual wajib diisi dan tidak boleh negatif');
  }
}

async function create(userId, payload) {
  validate(payload);
  return produkRepository.create(userId, payload);
}

async function update(id, userId, payload) {
  validate(payload);
  const updated = await produkRepository.update(id, userId, payload);
  if (!updated) throw ApiError.notFound('Produk tidak ditemukan');
  return updated;
}

async function remove(id, userId) {
  const deleted = await produkRepository.remove(id, userId);
  if (!deleted) throw ApiError.notFound('Produk tidak ditemukan');
}

module.exports = { list, create, update, remove };
