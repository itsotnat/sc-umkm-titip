const express = require('express');
const produkController = require('./produk.controller');
const { authMiddleware } = require('../../middleware/auth.middleware');

const router = express.Router();
router.use(authMiddleware);

router.get('/', produkController.list);
router.post('/', produkController.create);
router.put('/:id', produkController.update);
router.delete('/:id', produkController.remove);

module.exports = router;
