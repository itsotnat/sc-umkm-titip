const laporanService = require('./laporan.service');
const { ok } = require('../../utils/response');
const { asyncHandler } = require('../../utils/asyncHandler');

const titipOutlet = asyncHandler(async (req, res) => {
  const { dari, sampai } = req.query;
  const data = await laporanService.titipOutlet(req.userId, dari, sampai);
  ok(res, data);
});

const pesanan = asyncHandler(async (req, res) => {
  const { dari, sampai } = req.query;
  const data = await laporanService.pesanan(req.userId, dari, sampai);
  ok(res, data);
});

module.exports = { titipOutlet, pesanan };
