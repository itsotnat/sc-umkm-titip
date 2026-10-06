const express = require('express');
const multer = require('multer');
const authController = require('./auth.controller');
const { authMiddleware } = require('../../middleware/auth.middleware');
const { authLimiter, forgotLimiter, resetLimiter, changePasswordLimiter } = require('../../middleware/rateLimit.middleware');
const { ApiError } = require('../../utils/ApiError');

const router = express.Router();

// Foto ditahan di memori (maks 2 MB), tipenya divalidasi dari isi file di profile.service.
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 2 * 1024 * 1024, files: 1 } });

function handleUpload(req, res, next) {
  upload.single('foto')(req, res, (err) => {
    if (!err) return next();
    if (err instanceof multer.MulterError && err.code === 'LIMIT_FILE_SIZE') {
      return next(ApiError.badRequest('Ukuran foto maksimal 2 MB', 'FILE_TOO_LARGE'));
    }
    return next(ApiError.badRequest('Upload foto gagal'));
  });
}

router.post('/register', authLimiter, authController.register);
router.post('/login', authLimiter, authController.login);
router.post('/forgot-password', forgotLimiter, authController.forgotPassword);
router.post('/reset-password', resetLimiter, authController.resetPassword);

router.get('/me', authMiddleware, authController.me);
router.patch('/me', authMiddleware, authController.updateMe);
router.post('/change-password', authMiddleware, changePasswordLimiter, authController.changePassword);
router.post('/me/foto', authMiddleware, handleUpload, authController.uploadFoto);
router.delete('/me/foto', authMiddleware, authController.deleteFoto);

module.exports = router;
