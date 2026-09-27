const produkService = require('./produk.service');
const { ok, created } = require('../../utils/response');
const { asyncHandler } = require('../../utils/asyncHandler');

const list = asyncHandler(async (req, res) => {
  const data = await produkService.list(req.userId);
  ok(res, data);
});

const create = asyncHandler(async (req, res) => {
  const { nama_produk, hpp, harga_jual } = req.body;
  const data = await produkService.create(req.userId, {
    namaProduk: nama_produk,
    hpp: Number(hpp),
    hargaJual: Number(harga_jual),
  });
  created(res, data);
});

const update = asyncHandler(async (req, res) => {
  const { nama_produk, hpp, harga_jual } = req.body;
  const data = await produkService.update(req.params.id, req.userId, {
    namaProduk: nama_produk,
    hpp: Number(hpp),
    hargaJual: Number(harga_jual),
  });
  ok(res, data);
});

const remove = asyncHandler(async (req, res) => {
  await produkService.remove(req.params.id, req.userId);
  ok(res, { id: req.params.id });
});

module.exports = { list, create, update, remove };
