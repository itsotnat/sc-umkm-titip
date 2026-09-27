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
| Backend — Docker (Dockerfile, docker-compose, nginx reverse proxy) | ✅ Siap pakai, **belum di-deploy** ke VPS mana pun (sesuai keputusan kamu — belum ada VPS/domain) |
| Mobile — semua layar sesuai UI/UX Design (Beranda, Master Produk/Outlet, Input Titip, Pesanan, Laporan+Export Excel, Auth) | ✅ Selesai, terhubung ke SQLite lokal + API backend (bukan data dummy) |
| Mobile — kompilasi dengan Flutter SDK | ⚠️ **Belum bisa diverifikasi di lingkungan saya** — sandbox saya diblokir mengunduh Dart SDK. Kode sudah dicek manual (struktur, import, sintaks) dan beberapa bug nyata sudah ditemukan & diperbaiki, tapi kamu tetap perlu menjalankan `flutter pub get` + build pertama kali di komputermu sendiri untuk memastikan tidak ada typo yang lolos. |

## Langkah selanjutnya di komputermu

1. **Backend**: masuk ke `umkm-titip-backend/`, ikuti README-nya (bisa jalan lokal dengan `npm install` + PostgreSQL, atau langsung `docker compose up` begitu Docker terpasang).
2. **Mobile**: masuk ke `umkm-titip-mobile/`, jalankan:
   ```
   flutter create --platforms=android .
   flutter pub get
   flutter run
   ```
   (`flutter create` di sini **tidak** menimpa `lib/` atau `pubspec.yaml` yang sudah ada — dia cuma melengkapi folder `android/` yang belum ada.)
3. Sesuaikan `API_BASE_URL` mobile ke alamat backend kamu (default `http://10.0.2.2:3000/api/v1` untuk emulator Android yang mengakses backend lokal).
4. Saat siap deploy sungguhan, ikuti dokumen **Deployment & Maintenance Guide** di Project — dan pastikan VPS/domain yang dipakai terpisah total dari infrastruktur pribadi kamu (adamLabs).

## Catatan penting

- Tidak ada bagian dari kode ini yang berkaitan dengan pekerjaan LIS/analyzer integration kamu di PT Wahana Meditek — ini murni proyek capstone UMKM Titip.
- Semua rumus perhitungan (terjual, nilai terjual, untung/rugi, sell-through rate, status Laris/Standar/Kurang) diimplementasikan identik di backend dan mobile, sesuai SDD Bagian 4, dan sudah diverifikasi lewat pengujian backend.
