const syncService = require('./sync.service');
const { ok } = require('../../utils/response');
const { asyncHandler } = require('../../utils/asyncHandler');

const pull = asyncHandler(async (req, res) => {
  const { last_sync_at } = req.body;
  const data = await syncService.pull(req.userId, last_sync_at);
  ok(res, data);
});

const push = asyncHandler(async (req, res) => {
  const data = await syncService.push(req.userId, req.body);
  ok(res, data);
});

module.exports = { pull, push };
