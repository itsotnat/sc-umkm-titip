import 'package:flutter/foundation.dart';

import '../models/produk.dart';
import '../repositories/produk_repository.dart';

class ProdukProvider extends ChangeNotifier {
  final ProdukRepository _repository = ProdukRepository();

  List<Produk> items = [];
  bool isLoading = false;

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    items = await _repository.getAll();
    isLoading = false;
    notifyListeners();
  }

  Future<void> add({required String namaProduk, required double hpp, required double hargaJual}) async {
    await _repository.create(namaProduk: namaProduk, hpp: hpp, hargaJual: hargaJual);
    await load();
  }

  Future<void> update(Produk produk) async {
    await _repository.update(produk);
    await load();
  }

  Future<void> remove(String id) async {
    await _repository.delete(id);
    await load();
  }
}
