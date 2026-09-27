const titipService = require('./titip.service');
const { ok } = require('../../utils/response');
const { asyncHandler } = require('../../utils/asyncHandler');

const list = asyncHandler(async (req, res) => {
  const { outlet_id, tanggal } = req.query;
  const data = await titipService.listByOutletTanggal(req.userId, outlet_id, tanggal);
  ok(res, data);
});

const sync = asyncHandler(async (req, res) => {
  const { items } = req.body;
  const data = await titipService.syncBatch(req.userId, items);
  ok(res, data);
});

module.exports = { list, sync };
