const express = require('express');
const outletController = require('./outlet.controller');
const { authMiddleware } = require('../../middleware/auth.middleware');

const router = express.Router();
router.use(authMiddleware);

router.get('/', outletController.list);
router.post('/', outletController.create);
router.put('/:id', outletController.update);
router.delete('/:id', outletController.remove);

module.exports = router;
