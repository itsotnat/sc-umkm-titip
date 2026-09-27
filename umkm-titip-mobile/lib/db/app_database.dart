import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Helper database lokal SQLite. Skema tabel dibuat semirip mungkin dengan
/// skema di server (lihat dokumen Database Design & SAD Bagian 3), agar
/// sinkronisasi antara mobile dan backend sederhana.
class AppDatabase {
  AppDatabase._internal();
  static final AppDatabase instance = AppDatabase._internal();

  static Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'umkm_titip.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE produk (
        id TEXT PRIMARY KEY,
        nama_produk TEXT NOT NULL,
        hpp REAL NOT NULL DEFAULT 0,
        harga_jual REAL NOT NULL DEFAULT 0,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE outlet (
        id TEXT PRIMARY KEY,
        nama_outlet TEXT NOT NULL,
        alamat TEXT,
        no_whatsapp TEXT,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE pemesan (
        id TEXT PRIMARY KEY,
        nama_pemesan TEXT NOT NULL,
        no_whatsapp TEXT,
        sync_status TEXT NOT NULL DEFAULT 'pending'
      )
    ''');

    await db.execute('''
      CREATE TABLE transaksi_titip (
        id TEXT PRIMARY KEY,
        outlet_id TEXT NOT NULL,
        produk_id TEXT NOT NULL,
        tanggal TEXT NOT NULL,
        jumlah_kirim INTEGER NOT NULL DEFAULT 0,
        jumlah_retur INTEGER NOT NULL DEFAULT 0,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_titip_outlet_tanggal ON transaksi_titip(outlet_id, tanggal)');

    await db.execute('''
      CREATE TABLE pesanan (
        id TEXT PRIMARY KEY,
        pemesan_id TEXT NOT NULL,
        tanggal_pesan TEXT NOT NULL,
        tanggal_jatuh_tempo TEXT NOT NULL,
        status_selesai INTEGER NOT NULL DEFAULT 0,
        status_lunas INTEGER NOT NULL DEFAULT 0,
        catatan TEXT,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE pesanan_detail (
        id TEXT PRIMARY KEY,
        pesanan_id TEXT NOT NULL,
        produk_id TEXT NOT NULL,
        jumlah INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE auth_session (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        user_id TEXT,
        nama_usaha TEXT,
        nama_pemilik TEXT,
        email TEXT,
        last_sync_at TEXT
      )
    ''');
  }

  /// Dipanggil saat logout: mengosongkan seluruh data lokal milik akun sebelumnya,
  /// supaya data satu akun tidak tercampur dengan akun lain di perangkat yang sama.
  Future<void> clearAll() async {
    final db = await database;
    final batch = db.batch();
    for (final table in [
      'produk',
      'outlet',
      'pemesan',
      'transaksi_titip',
      'pesanan',
      'pesanan_detail',
      'auth_session',
    ]) {
      batch.delete(table);
    }
    await batch.commit(noResult: true);
  }
}
