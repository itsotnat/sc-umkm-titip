const express = require('express');
const { authMiddleware } = require('../../middleware/auth.middleware');
const { backupLimiter } = require('../../middleware/rateLimit.middleware');
const { asyncHandler } = require('../../utils/asyncHandler');
const { ok } = require('../../utils/response');
const { ApiError } = require('../../utils/ApiError');
const { isConfigured } = require('../../config/mailer');
const backupService = require('./backup.service');

const router = express.Router();

// Kirim cadangan sekarang ke email akun (tombol "Kirim cadangan ke email" di aplikasi).
router.post(
  '/email',
  authMiddleware,
  backupLimiter,
  asyncHandler(async (req, res) => {
    if (!isConfigured()) {
      throw new ApiError(503, 'MAIL_NOT_CONFIGURED', 'Pengiriman email belum diaktifkan di server');
    }
    const hasil = await backupService.kirimCadangan(req.userId);
    if (!hasil.terkirim && hasil.alasan === 'KOSONG') {
      throw ApiError.badRequest('Belum ada data yang bisa dicadangkan', 'NO_DATA');
    }
    ok(res, { terkirim: hasil.terkirim, jumlah_data: hasil.jumlah });
  })
);

module.exports = router;
