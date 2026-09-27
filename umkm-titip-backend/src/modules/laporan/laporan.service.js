const laporanRepository = require('./laporan.repository');
const { ApiError } = require('../../utils/ApiError');

/**
 * Menentukan status Laris/Standar/Kurang berdasarkan sell-through rate,
 * sesuai formula di dokumen SDD Bagian 4:
 *   >= 80%        -> Laris
 *   50% - 79.99%  -> Standar
 *   < 50%         -> Kurang
 */
function tentukanStatus(totalTerjual, totalKirim) {
  if (totalKirim === 0) return { sellThroughRate: 0, status: 'Belum Ada Data' };
  const rate = (totalTerjual / totalKirim) * 100;
  let status;
  if (rate >= 80) status = 'Laris';
  else if (rate >= 50) status = 'Standar';
  else status = 'Kurang';
  return { sellThroughRate: Number(rate.toFixed(2)), status };
}

function validateRentang(dari, sampai) {
  if (!dari || !sampai) {
    throw ApiError.badRequest('dari dan sampai wajib diisi (format YYYY-MM-DD)');
  }
}

async function titipOutlet(userId, dari, sampai) {
  validateRentang(dari, sampai);
  const rows = await laporanRepository.rekapTitipOutlet(userId, dari, sampai);
  return rows.map((row) => {
    const totalKirim = Number(row.total_kirim);
    const totalTerjual = Number(row.total_terjual);
    const { sellThroughRate, status } = tentukanStatus(totalTerjual, totalKirim);
    return {
      outlet_id: row.outlet_id,
      nama_outlet: row.nama_outlet,
      total_kirim: totalKirim,
      total_retur: Number(row.total_retur),
      total_terjual: totalTerjual,
      total_nilai_terjual: Number(row.total_nilai_terjual),
      total_untung_rugi: Number(row.total_untung_rugi),
      sell_through_rate: sellThroughRate,
      status,
    };
  });
}

async function pesanan(userId, dari, sampai) {
  validateRentang(dari, sampai);
  const row = await laporanRepository.rekapPesanan(userId, dari, sampai);
  return {
    total_pesanan: Number(row.total_pesanan),
    total_selesai: Number(row.total_selesai),
    total_belum_selesai: Number(row.total_belum_selesai),
    total_lunas: Number(row.total_lunas),
    total_belum_lunas: Number(row.total_belum_lunas),
  };
}

module.exports = { titipOutlet, pesanan, tentukanStatus };
