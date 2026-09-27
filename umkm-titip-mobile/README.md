# UMKM Titip - Mobile App (Flutter)

Aplikasi mobile Android untuk UMKM Titip (Capstone STSI4440, Universitas Terbuka). Offline-first: seluruh input tersimpan dulu ke SQLite lokal, lalu disinkronkan ke backend saat online, sesuai dokumen SAD Bagian 3 dan SDD.

## Prasyarat

- Flutter SDK (channel stable) sudah terpasang. Lihat https://docs.flutter.dev/get-started/install
- Android Studio atau VS Code dengan plugin Flutter/Dart
- Backend UMKM Titip sudah berjalan (lihat `../umkm-titip-backend/README.md`)

## Langkah setup (penting, baca dulu)

Folder ini berisi seluruh kode aplikasi (`lib/`, `pubspec.yaml`, `test/`), **tetapi folder platform native (`android/`, `ios/`) belum ada**, karena folder tersebut dibuat otomatis oleh Flutter SDK sesuai versi SDK yang terpasang di komputer masing-masing, dan proses pembuatannya butuh mengunduh dari storage Google yang tidak bisa diakses dari lingkungan tempat kode ini dibuat.

Cukup jalankan satu perintah berikut di folder ini untuk melengkapinya:

```bash
cd umkm-titip-mobile
flutter create --platforms=android .
# Perintah di atas HANYA menambahkan folder android/ (dan file platform lain
# yang belum ada). File lib/ dan pubspec.yaml yang sudah dibuat TIDAK akan ditimpa.

flutter pub get
```

Setelah itu, jalankan seperti aplikasi Flutter pada umumnya:

```bash
flutter run
```

## Konfigurasi alamat backend

Alamat backend diatur lewat `lib/utils/constants.dart` (default: `http://10.0.2.2:3000/api/v1`, alamat khusus untuk mengakses localhost komputer dari emulator Android). Untuk device fisik atau saat backend sudah online di VPS, jalankan dengan:

```bash
flutter run --dart-define=API_BASE_URL=https://umkmtitip.store/api/v1
```

## Struktur folder

```
lib/
├── db/app_database.dart        # helper SQLite (skema tabel lokal)
├── models/                       # model data (Produk, Outlet, Pesanan, dst.)
├── repositories/                  # akses data lokal (offline-first)
├── services/                       # ApiClient, AuthService, SyncManager, CalculationService
├── providers/                       # state management (package provider)
├── screens/
│   ├── auth/                          # Login, Registrasi
│   ├── home/                           # Shell + Beranda (Dashboard)
│   ├── titip/                           # Bottom Sheet Input Harian Titip
│   ├── master/                          # Master Produk & Outlet
│   ├── pesanan/                          # Daftar & Form Pesanan
│   └── laporan/                          # Laporan + export Excel
├── widgets/                          # komponen reusable (badge status, empty state, dst.)
└── main.dart
```

## Alur offline-first (ringkas)

1. Setiap input (titip harian, pesanan, dst.) langsung ditulis ke SQLite lokal terlebih dahulu.
2. `SyncManager` mencoba mengirim data berstatus `pending` ke backend setiap kali ada perubahan dan koneksi tersedia.
3. Bila gagal (offline/timeout), data tetap tersimpan lokal dan akan dicoba lagi pada sinkronisasi berikutnya. Pengguna tidak kehilangan data.
4. Laporan dihitung langsung dari data lokal (tidak wajib memanggil API laporan), sesuai catatan di dokumen REST API Spec Bagian 7.

## Menjalankan test

```bash
flutter test
```

Berisi unit test untuk `CalculationService` (kalkulasi terjual, nilai, untung/rugi, dan status Laris/Standar/Kurang), sesuai formula di dokumen SDD Bagian 4.

## Catatan status pengembangan

Kode ini adalah kerangka kerja penuh (bukan prototipe kosong): seluruh layar di dokumen UI/UX Design sudah diimplementasikan dan terhubung ke data asli (SQLite + backend), bukan data dummy. Yang masih perlu dikerjakan tim sebelum rilis:

- Menjalankan `flutter create` sesuai langkah di atas (sekali saja, di komputer masing-masing anggota tim).
- Uji coba end-to-end di perangkat/emulator asli (kode ini belum bisa dijalankan di lingkungan pembuatannya karena tidak ada Flutter SDK/emulator di sana).
- Ikon aplikasi, splash screen, dan penyesuaian visual lain sesuai selera tim.
- Endpoint `/sync/pull` dan `/sync/push` di backend sudah tersedia untuk skenario satu akun di lebih dari satu perangkat, namun pemanggilannya dari mobile belum diintegrasikan penuh (saat ini sinkronisasi per-modul melalui `/titip/sync` sudah berjalan).
