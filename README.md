# UMKM Titip — Source Code

Aplikasi manajemen titip-jual untuk UMKM: backend REST API + aplikasi mobile Flutter (offline-first). Dibangun berdasarkan dokumen desain capstone (PRD, SRS, SAD, SDD, Database Design, REST API Spec, UI/UX Design, Deployment & Maintenance Guide) di folder `Capstone` kamu.

## Struktur folder

```
source-code/
├── umkm-titip-backend/     Node.js + Express REST API, PostgreSQL
└── umkm-titip-mobile/      Aplikasi Flutter (Android), offline-first + SQLite
```

Masing-masing punya `README.md` sendiri dengan instruksi setup lengkap.

## Status pengerjaan

| Bagian | Status |
|---|---|
| Backend — semua modul (auth, produk, outlet, titip+sync, pesanan+pemesan, laporan) | ✅ Selesai, **sudah diuji end-to-end** dengan PostgreSQL asli (register/login, CRUD, sync batch, transaksi atomik pesanan, semua rumus laporan diverifikasi cocok dengan SDD) |
| Backend — Deploy production | ✅ **Live di VPS**: `https://api-backend.umkm-titip.web.id/api/v1`, jalan via Docker Compose (app + db + nginx), SSL Let's Encrypt aktif dengan auto-renew (cron) |
| Mobile — semua layar sesuai UI/UX Design (Beranda, Master Produk/Outlet, Input Titip, Pesanan, Laporan+Export Excel, Auth) | ✅ Selesai, terhubung ke SQLite lokal + API backend (bukan data dummy) |
| Mobile — kompilasi dengan Flutter SDK | ⚠️ **Belum bisa diverifikasi di lingkungan saya** — sandbox saya diblokir mengunduh Dart SDK. Kode sudah dicek manual (struktur, import, sintaks) dan beberapa bug nyata sudah ditemukan & diperbaiki, tapi kamu tetap perlu menjalankan `flutter pub get` + build pertama kali di komputermu sendiri untuk memastikan tidak ada typo yang lolos. |

## Langkah selanjutnya di komputermu

1. **Backend**: sudah live di production (`https://api-backend.umkm-titip.web.id`), tidak perlu dijalankan lokal lagi kecuali untuk development/debugging (`umkm-titip-backend/README.md` tetap punya instruksi jalan lokal kalau dibutuhkan).
2. **Mobile**: masuk ke `umkm-titip-mobile/`, jalankan:
   ```
   flutter create --platforms=android .
   flutter pub get
   flutter run --dart-define=API_BASE_URL=https://api-backend.umkm-titip.web.id/api/v1
   ```
   (`flutter create` di sini **tidak** menimpa `lib/` atau `pubspec.yaml` yang sudah ada — dia cuma melengkapi folder `android/` yang belum ada.)
3. Untuk build APK final (bukan mode debug):
   ```
   flutter build apk --dart-define=API_BASE_URL=https://api-backend.umkm-titip.web.id/api/v1
   ```
4. Domain final proyek ini adalah **`umkm-titip.web.id`** (bukan `umkmtitip.store` yang sempat direncanakan di dokumen awal) — VPS dan domain ini terpisah total dari infrastruktur pribadi kamu (adamLabs).

## Catatan penting

- Tidak ada bagian dari kode ini yang berkaitan dengan pekerjaan LIS/analyzer integration kamu di PT Wahana Meditek — ini murni proyek capstone UMKM Titip.
- Semua rumus perhitungan (terjual, nilai terjual, untung/rugi, sell-through rate, status Laris/Standar/Kurang) diimplementasikan identik di backend dan mobile, sesuai SDD Bagian 4, dan sudah diverifikasi lewat pengujian backend.
