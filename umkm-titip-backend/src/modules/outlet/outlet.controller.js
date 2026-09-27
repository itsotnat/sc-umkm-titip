const outletService = require('./outlet.service');
const { ok, created } = require('../../utils/response');
const { asyncHandler } = require('../../utils/asyncHandler');

const list = asyncHandler(async (req, res) => {
  const data = await outletService.list(req.userId);
  ok(res, data);
});

const create = asyncHandler(async (req, res) => {
  const { nama_outlet, alamat, no_whatsapp } = req.body;
  const data = await outletService.create(req.userId, { namaOutlet: nama_outlet, alamat, noWhatsapp: no_whatsapp });
  created(res, data);
});

const update = asyncHandler(async (req, res) => {
  const { nama_outlet, alamat, no_whatsapp } = req.body;
  const data = await outletService.update(req.params.id, req.userId, {
    namaOutlet: nama_outlet,
    alamat,
    noWhatsapp: no_whatsapp,
  });
  ok(res, data);
});

const remove = asyncHandler(async (req, res) => {
  await outletService.remove(req.params.id, req.userId);
  ok(res, { id: req.params.id });
});

module.exports = { list, create, update, remove };
