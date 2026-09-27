const pesananService = require('./pesanan.service');
const { ok, created } = require('../../utils/response');
const { asyncHandler } = require('../../utils/asyncHandler');

const listPesanan = asyncHandler(async (req, res) => {
  const { status, dari, sampai } = req.query;
  const data = await pesananService.listPesanan(req.userId, { status, dari, sampai });
  ok(res, data);
});

const createPesanan = asyncHandler(async (req, res) => {
  const { pemesan, pemesan_id, tanggal_jatuh_tempo, items, catatan } = req.body;
  const data = await pesananService.createPesanan(req.userId, {
    pemesan,
    pemesanId: pemesan_id,
    tanggalJatuhTempo: tanggal_jatuh_tempo,
    items,
    catatan,
  });
  created(res, data);
});

const updateStatus = asyncHandler(async (req, res) => {
  const { status_selesai, status_lunas } = req.body;
  const data = await pesananService.updateStatus(req.params.id, req.userId, {
    statusSelesai: status_selesai,
    statusLunas: status_lunas,
  });
  ok(res, data);
});

const remove = asyncHandler(async (req, res) => {
  await pesananService.remove(req.params.id, req.userId);
  ok(res, { id: req.params.id });
});

const listPemesan = asyncHandler(async (req, res) => {
  const data = await pesananService.listPemesan(req.userId);
  ok(res, data);
});

const createPemesan = asyncHandler(async (req, res) => {
  const { nama_pemesan, no_whatsapp } = req.body;
  const data = await pesananService.createPemesan(req.userId, { namaPemesan: nama_pemesan, noWhatsapp: no_whatsapp });
  created(res, data);
});

module.exports = { listPesanan, createPesanan, updateStatus, remove, listPemesan, createPemesan };
