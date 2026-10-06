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
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// v1 -> v2: `jumlah_retur` dibuat boleh NULL, supaya bisa membedakan
  /// "retur belum diinput" (NULL) dari "retur sudah dikonfirmasi 0/habis
  /// terjual" (angka 0). SQLite tidak mendukung ALTER COLUMN untuk
  /// melonggarkan NOT NULL, jadi tabel dibuat ulang lalu data lama dipindahkan.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('DROP INDEX IF EXISTS idx_titip_outlet_tanggal');
      await db.execute('ALTER TABLE transaksi_titip RENAME TO transaksi_titip_old');
      await db.execute('''
        CREATE TABLE transaksi_titip (
          id TEXT PRIMARY KEY,
          outlet_id TEXT NOT NULL,
          produk_id TEXT NOT NULL,
          tanggal TEXT NOT NULL,
          jumlah_kirim INTEGER NOT NULL DEFAULT 0,
          jumlah_retur INTEGER,
          sync_status TEXT NOT NULL DEFAULT 'pending',
          updated_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        INSERT INTO transaksi_titip (id, outlet_id, produk_id, tanggal, jumlah_kirim, jumlah_retur, sync_status, updated_at)
        SELECT id, outlet_id, produk_id, tanggal, jumlah_kirim, jumlah_retur, sync_status, updated_at
        FROM transaksi_titip_old
      ''');
      await db.execute('DROP TABLE transaksi_titip_old');
      await db.execute('CREATE INDEX idx_titip_outlet_tanggal ON transaksi_titip(outlet_id, tanggal)');
    }
    // v2 -> v3: simpan path foto profil di sesi lokal supaya avatar langsung
    // tampil saat aplikasi dibuka, sebelum (atau tanpa) refresh dari server.
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE auth_session ADD COLUMN foto_url TEXT');
    }
    // v3 -> v4: antrean penghapusan yang menunggu dikirim ke server.
    if (oldVersion < 4) {
      await _createPendingDelete(db);
    }
  }

  Future<void> _createPendingDelete(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_delete (
        entity TEXT NOT NULL,
        id TEXT NOT NULL,
        PRIMARY KEY (entity, id)
      )
    ''');
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
        jumlah_retur INTEGER,
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
        foto_url TEXT,
        last_sync_at TEXT
      )
    ''');

    await _createPendingDelete(db);
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
      'pending_delete',
      'auth_session',
    ]) {
      batch.delete(table);
    }
    await batch.commit(noResult: true);
  }
}
