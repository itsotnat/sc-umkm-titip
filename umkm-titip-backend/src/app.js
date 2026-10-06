const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');

const authRoutes = require('./modules/auth/auth.routes');
const produkRoutes = require('./modules/produk/produk.routes');
const outletRoutes = require('./modules/outlet/outlet.routes');
const titipRoutes = require('./modules/titip/titip.routes');
const pesananRoutes = require('./modules/pesanan/pesanan.routes');
const laporanRoutes = require('./modules/laporan/laporan.routes');
const syncRoutes = require('./modules/sync/sync.routes');
const backupRoutes = require('./modules/backup/backup.routes');

const path = require('path');
const { UPLOAD_ROOT } = require('./modules/auth/profile.service');
const { errorMiddleware, notFoundMiddleware } = require('./middleware/error.middleware');

const app = express();

// Di belakang Nginx: pakai IP klien asli (X-Forwarded-For) untuk rate limiting.
app.set('trust proxy', 1);

app.use(helmet());
app.use(cors({ origin: process.env.CORS_ORIGIN === '*' ? true : (process.env.CORS_ORIGIN || '').split(',') }));
app.use(express.json({ limit: '2mb' }));
app.use(morgan(process.env.NODE_ENV === 'production' ? 'combined' : 'dev'));

// Foto profil. Nama file berupa UUID acak (tidak bisa ditebak) dan berganti setiap foto diubah.
app.use('/uploads', express.static(UPLOAD_ROOT, { index: false, maxAge: '7d', dotfiles: 'deny' }));

app.get('/health', (req, res) => {
  res.json({ success: true, data: { status: 'ok', time: new Date().toISOString() } });
});

const API_PREFIX = '/api/v1';
app.use(`${API_PREFIX}/auth`, authRoutes);
app.use(`${API_PREFIX}/produk`, produkRoutes);
app.use(`${API_PREFIX}/outlet`, outletRoutes);
app.use(`${API_PREFIX}/titip`, titipRoutes);
app.use(`${API_PREFIX}`, pesananRoutes); // /pesanan dan /pemesan
app.use(`${API_PREFIX}/laporan`, laporanRoutes);
app.use(`${API_PREFIX}/sync`, syncRoutes);
app.use(`${API_PREFIX}/backup`, backupRoutes);

app.use(notFoundMiddleware);
app.use(errorMiddleware);

module.exports = { app };
