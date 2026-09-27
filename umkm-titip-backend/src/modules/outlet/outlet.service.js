const outletRepository = require('./outlet.repository');
const { ApiError } = require('../../utils/ApiError');

async function list(userId) {
  return outletRepository.findAllByUser(userId);
}

function validate({ namaOutlet }) {
  if (!namaOutlet || !namaOutlet.trim()) {
    throw ApiError.badRequest('nama_outlet wajib diisi');
  }
}

async function create(userId, payload) {
  validate(payload);
  return outletRepository.create(userId, payload);
}

async function update(id, userId, payload) {
  validate(payload);
  const updated = await outletRepository.update(id, userId, payload);
  if (!updated) throw ApiError.notFound('Outlet tidak ditemukan');
  return updated;
}

async function remove(id, userId) {
  const deleted = await outletRepository.remove(id, userId);
  if (!deleted) throw ApiError.notFound('Outlet tidak ditemukan');
}

module.exports = { list, create, update, remove };
