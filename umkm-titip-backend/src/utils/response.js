/**
 * Helper format response sukses, sesuai standar di dokumen REST API Spec Bagian 9:
 * { "success": true, "data": { ... } }
 */
function ok(res, data, statusCode = 200) {
  return res.status(statusCode).json({ success: true, data });
}

function created(res, data) {
  return ok(res, data, 201);
}

module.exports = { ok, created };
