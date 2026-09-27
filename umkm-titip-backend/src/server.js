require('dotenv').config();
const { app } = require('./app');

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log(`UMKM Titip backend berjalan di port ${PORT} (${process.env.NODE_ENV || 'development'})`);
});
