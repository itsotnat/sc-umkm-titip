import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/outlet.dart';
import '../../providers/produk_provider.dart';
import '../../providers/titip_provider.dart';
import '../../widgets/format_utils.dart';

/// Bottom Sheet Input Harian Titip, sesuai dokumen UI/UX Design Bagian 5.
/// Layar yang paling sering dipakai (berkali-kali sehari), sehingga setiap
/// detik yang dihemat di sini berdampak besar ke pengalaman pengguna.
Future<void> showTitipInputSheet(BuildContext context, {required Outlet outlet, required DateTime tanggal}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => TitipInputSheet(outlet: outlet, tanggal: tanggal),
  );
}

class TitipInputSheet extends StatefulWidget {
  final Outlet outlet;
  final DateTime tanggal;

  const TitipInputSheet({super.key, required this.outlet, required this.tanggal});

  @override
  State<TitipInputSheet> createState() => _TitipInputSheetState();
}

class _TitipInputSheetState extends State<TitipInputSheet> {
  final List<TitipInputRow> _rows = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final produkProvider = context.read<ProdukProvider>();
    if (produkProvider.items.isEmpty) await produkProvider.load();
    await context.read<TitipProvider>().loadUntukOutlet(widget.outlet.id, widget.tanggal, produkProvider.items, _rows);
    setState(() => _loading = false);
  }

  // Baris yang retur-nya belum diinput dianggap kontribusi 0 dulu ke total di
  // footer (angka provisional, belum final) — badge di kartu produk sendiri
  // yang menunjukkan status "belum lengkap" per baris.
  int get _totalTerjual => _rows.fold(0, (sum, r) => sum + (r.terjual ?? 0));
  double get _totalNilai => _rows.fold(0, (sum, r) => sum + (r.nilaiTerjual ?? 0));
  bool get _adaReturBelumDiinput => _rows.any((r) => r.jumlahKirim > 0 && r.jumlahRetur == null);

  // Retur tidak boleh lebih besar dari kirim (kalau begitu, "Terjual" jadi
  // negatif — nilai yang tidak masuk akal secara bisnis). Dicek di sini
  // (bukan cuma lewat warna merah di angka Terjual) supaya tombol Simpan
  // benar-benar diblok, bukan cuma indikator visual.
  bool get _adaReturLebihBesar => _rows.any((r) => r.jumlahRetur != null && r.jumlahRetur! > r.jumlahKirim);

  Future<void> _simpan() async {
    if (_adaReturLebihBesar) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ada produk dengan Retur melebihi jumlah Kirim. Perbaiki dulu sebelum menyimpan.')),
      );
      return;
    }
    setState(() => _saving = true);
    await context.read<TitipProvider>().simpan(widget.outlet.id, widget.tanggal, _rows);
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tersimpan')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              const SizedBox(height: 8),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Input Titip: ${widget.outlet.namaOutlet}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(formatTanggal(widget.tanggal), style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (!_loading && _rows.isNotEmpty) const _HeaderKolom(),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _rows.isEmpty
                        ? const Center(child: Text('Belum ada produk. Tambahkan produk terlebih dahulu di menu Master.'))
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                            itemCount: _rows.length,
                            separatorBuilder: (_, __) => const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
                            itemBuilder: (context, index) => _ProdukRow(
                              row: _rows[index],
                              onChanged: () => setState(() {}),
                            ),
                          ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_adaReturLebihBesar)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Ada produk dengan Retur melebihi jumlah Kirim — perbaiki dulu sebelum menyimpan.',
                            style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600),
                          ),
                        )
                      else if (_adaReturBelumDiinput)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Ada produk yang Retur-nya belum diisi — total di bawah masih sementara.',
                            style: TextStyle(fontSize: 12, color: Colors.orange),
                          ),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Terjual: $_totalTerjual pcs', style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(formatRupiah(_totalNilai), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: (_loading || _saving || _rows.isEmpty || _adaReturLebihBesar) ? null : _simpan,
                        child: _saving
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Simpan'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Proporsi kolom dipakai bersama oleh header dan baris produk supaya sejajar.
const int _flexProduk = 10;
const int _flexKirim = 6;
const int _flexRetur = 6;
const int _flexTerjual = 7;
const double _kolomGap = 8;
const double _tinggiKotak = 56;

class _HeaderKolom extends StatelessWidget {
  const _HeaderKolom();

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600);
    Widget kolom(String t, int flex, {TextAlign align = TextAlign.center}) =>
        Expanded(flex: flex, child: Text(t, textAlign: align, style: style));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          kolom('Produk', _flexProduk, align: TextAlign.left),
          const SizedBox(width: _kolomGap),
          kolom('Kirim', _flexKirim),
          const SizedBox(width: _kolomGap),
          kolom('Retur', _flexRetur),
          const SizedBox(width: _kolomGap),
          kolom('Terjual', _flexTerjual),
        ],
      ),
    );
  }
}

class _ProdukRow extends StatelessWidget {
  final TitipInputRow row;
  final VoidCallback onChanged;

  const _ProdukRow({required this.row, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    // Retur tidak boleh melebihi Kirim: kotak Retur diberi border merah, kotak
    // Terjual jadi merah dengan "—", dan pesan ditampilkan di bawah baris.
    final returError = row.jumlahRetur != null && row.jumlahRetur! > row.jumlahKirim;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: _flexProduk,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.produk.namaProduk,
                    // Nama panjang turun ke baris berikutnya (maks 3 baris), tinggi baris
                    // mengikuti; kotak angka tetap di tengah secara vertikal.
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, height: 1.2),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${formatRupiah(row.produk.hargaJual)}/pcs',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: _kolomGap),
            Expanded(
              flex: _flexKirim,
              child: _NumberField(
                rowKey: row.produk.id,
                label: 'Kirim',
                value: row.jumlahKirim,
                onChanged: (v) {
                  row.jumlahKirim = v ?? 0;
                  onChanged();
                },
              ),
            ),
            const SizedBox(width: _kolomGap),
            Expanded(
              flex: _flexRetur,
              child: _NumberField(
                rowKey: row.produk.id,
                label: 'Retur',
                value: row.jumlahRetur,
                hasError: returError,
                onChanged: (v) {
                  row.jumlahRetur = v;
                  onChanged();
                },
              ),
            ),
            const SizedBox(width: _kolomGap),
            Expanded(
              flex: _flexTerjual,
              child: _TerjualTile(terjual: row.terjual, nilai: row.nilaiTerjual, error: returError),
            ),
          ],
        ),
        if (returError)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Retur tidak boleh lebih dari Kirim',
              style: TextStyle(fontSize: 12, color: Color(0xFFB3261E), fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}

class _TerjualTile extends StatelessWidget {
  final int? terjual;
  final double? nilai;
  final bool error;

  const _TerjualTile({required this.terjual, required this.nilai, required this.error});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final Widget isi;
    if (error) {
      bg = const Color(0xFFFCE4E4);
      fg = const Color(0xFFB3261E);
      isi = Text('—', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: fg));
    } else if (terjual == null) {
      bg = Colors.grey.shade100;
      fg = Colors.grey.shade500;
      isi = Text('—', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: fg));
    } else {
      bg = const Color(0xFFE3F4E1);
      fg = const Color(0xFF1B5E20);
      isi = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$terjual', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: fg, height: 1.1)),
          if (nilai != null)
            Text(formatRupiah(nilai!), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
        ],
      );
    }
    return Container(
      height: _tinggiKotak,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: FittedBox(fit: BoxFit.scaleDown, child: isi),
    );
  }
}

class _NumberField extends StatelessWidget {
  final String rowKey;
  final String label;

  /// NULL = kolom belum pernah diisi (dibiarkan kosong), beda dari 0 yang
  /// berarti sudah diisi angka nol secara eksplisit.
  final int? value;
  final ValueChanged<int?> onChanged;

  /// Border merah (dipakai untuk Retur yang melebihi Kirim).
  final bool hasError;

  const _NumberField({
    required this.rowKey,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final warna = hasError ? const Color(0xFFB3261E) : Colors.grey.shade700;
    OutlineInputBorder border(Color c, double w) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c, width: w));

    // Key stabil per baris+label (bukan per rebuild), supaya fokus dan posisi
    // kursor tidak hilang saat parent melakukan setState di tiap ketikan.
    return SizedBox(
      height: _tinggiKotak,
      child: TextFormField(
        key: ValueKey('numfield-$rowKey-$label'),
        initialValue: value == null ? '' : value.toString(),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        decoration: InputDecoration(
          hintText: '0',
          hintStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.grey.shade400),
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          enabledBorder: border(warna, hasError ? 2 : 1.5),
          focusedBorder: border(hasError ? warna : Theme.of(context).colorScheme.primary, 2),
          border: border(warna, 1.5),
        ),
        onChanged: (text) => onChanged(text.isEmpty ? null : int.tryParse(text)),
      ),
    );
  }
}
