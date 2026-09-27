const express = require('express');
const laporanController = require('./laporan.controller');
const { authMiddleware } = require('../../middleware/auth.middleware');

const router = express.Router();
router.use(authMiddleware);

router.get('/titip-outlet', laporanController.titipOutlet);
router.get('/pesanan', laporanController.pesanan);

module.exports = router;
