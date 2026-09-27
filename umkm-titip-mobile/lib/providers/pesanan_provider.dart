import 'package:flutter/foundation.dart';

import '../models/pemesan.dart';
import '../models/pesanan.dart';
import '../repositories/pesanan_repository.dart';

class PesananProvider extends ChangeNotifier {
  final PesananRepository _repository = PesananRepository();
  final PemesanRepository _pemesanRepository = PemesanRepository();

  List<Pesanan> items = [];
  List<Pemesan> daftarPemesan = [];
  bool isLoading = false;
  String filter = 'semua'; // semua | belum_selesai | selesai

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    final status = filter == 'semua' ? null : filter;
    items = await _repository.getAll(filterStatus: status);
    daftarPemesan = await _pemesanRepository.getAll();
    isLoading = false;
    notifyListeners();
  }

  void setFilter(String value) {
    filter = value;
    load();
  }

  Future<void> tambah({
    required String pemesanId,
    required DateTime tanggalJatuhTempo,
    required List<({String produkId, int jumlah})> produkItems,
    String? catatan,
  }) async {
    await _repository.create(
      pemesanId: pemesanId,
      tanggalJatuhTempo: tanggalJatuhTempo,
      items: produkItems,
      catatan: catatan,
    );
    await load();
  }

  Future<Pemesan> tambahPemesanBaru(String nama, String? noWhatsapp) async {
    final pemesan = await _pemesanRepository.create(namaPemesan: nama, noWhatsapp: noWhatsapp);
    daftarPemesan = await _pemesanRepository.getAll();
    notifyListeners();
    return pemesan;
  }

  Future<void> toggleSelesai(String id, bool value) async {
    await _repository.updateStatus(id, statusSelesai: value);
    await load();
  }

  Future<void> toggleLunas(String id, bool value) async {
    await _repository.updateStatus(id, statusLunas: value);
    await load();
  }

  Future<void> hapus(String id) async {
    await _repository.delete(id);
    await load();
  }
}
