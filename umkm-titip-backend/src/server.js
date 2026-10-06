require('dotenv').config();
const { app } = require('./app');

const PORT = process.env.PORT || 3000;

const backupScheduler = require('./jobs/backup.scheduler');

app.listen(PORT, () => {
  console.log(`UMKM Titip backend berjalan di port ${PORT} (${process.env.NODE_ENV || 'development'})`);
  backupScheduler.mulai();
});
