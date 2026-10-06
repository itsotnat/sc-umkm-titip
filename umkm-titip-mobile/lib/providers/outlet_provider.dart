import 'package:flutter/foundation.dart';

import '../models/outlet.dart';
import '../repositories/outlet_repository.dart';

class OutletProvider extends ChangeNotifier {
  final OutletRepository _repository = OutletRepository();

  List<Outlet> items = [];
  bool isLoading = false;

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    items = await _repository.getAll();
    isLoading = false;
    notifyListeners();
  }

  Future<void> add({required String namaOutlet, String? alamat, String? noWhatsapp}) async {
    await _repository.create(namaOutlet: namaOutlet, alamat: alamat, noWhatsapp: noWhatsapp);
    await load();
  }

  Future<void> update(Outlet outlet) async {
    await _repository.update(outlet);
    await load();
  }

  Future<void> remove(String id) async {
    await _repository.delete(id);
    await load();
  }

  /// Menyembunyikan item dari daftar (untuk "hapus dengan Batalkan"). Mengembalikan
  /// fungsi pemulih yang memasukkannya kembali ke posisi semula.
  VoidCallback sembunyikan(String id) {
    final index = items.indexWhere((e) => e.id == id);
    if (index < 0) return () {};
    final item = items.removeAt(index);
    notifyListeners();
    return () {
      items.insert(index.clamp(0, items.length), item);
      notifyListeners();
    };
  }
}
