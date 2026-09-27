const express = require('express');
const pesananController = require('./pesanan.controller');
const { authMiddleware } = require('../../middleware/auth.middleware');

const router = express.Router();
router.use(authMiddleware);

router.get('/pesanan', pesananController.listPesanan);
router.post('/pesanan', pesananController.createPesanan);
router.patch('/pesanan/:id/status', pesananController.updateStatus);
router.delete('/pesanan/:id', pesananController.remove);

router.get('/pemesan', pesananController.listPemesan);
router.post('/pemesan', pesananController.createPemesan);

module.exports = router;
