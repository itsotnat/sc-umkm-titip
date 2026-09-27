const express = require('express');
const syncController = require('./sync.controller');
const { authMiddleware } = require('../../middleware/auth.middleware');

const router = express.Router();
router.use(authMiddleware);

router.post('/pull', syncController.pull);
router.post('/push', syncController.push);

module.exports = router;
