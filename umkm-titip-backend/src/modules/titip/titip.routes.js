const express = require('express');
const titipController = require('./titip.controller');
const { authMiddleware } = require('../../middleware/auth.middleware');

const router = express.Router();
router.use(authMiddleware);

router.get('/', titipController.list);
router.post('/sync', titipController.sync);

module.exports = router;
