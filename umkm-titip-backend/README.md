# UMKM Titip - Backend

Backend REST API untuk aplikasi UMKM Titip (Capstone STSI4440, Universitas Terbuka).
Dibangun dengan Node.js, Express, dan PostgreSQL, mengikuti dokumen SAD, SDD, Database Design, dan REST API Spec di folder dokumen Capstone.

Infrastruktur proyek ini (server dan domain) terpisah total dari infrastruktur pribadi/pekerjaan anggota tim, khusus untuk Capstone ini.

## Menjalankan secara lokal (tanpa Docker)

Prasyarat: Node.js 18+ dan PostgreSQL terpasang di komputer.

```bash
cd umkm-titip-backend
cp .env.example .env
# edit .env: isi DB_HOST=localhost, DB_USER, DB_PASSWORD, JWT_SECRET, dst.

npm install
npm run db:migrate   # membuat seluruh tabel dari db/schema.sql
npm run db:seed      # opsional, membuat 1 akun contoh untuk testing
npm run dev           # server aktif di http://localhost:3000
```

Cek server hidup: `GET http://localhost:3000/health`

## Menjalankan dengan Docker (direkomendasikan, sama seperti yang nanti dipakai di VPS)

Prasyarat: Docker dan Docker Compose terpasang.

```bash
cd umkm-titip-backend
cp .env.example .env
# edit .env

docker compose up -d --build
docker compose logs -f app   # cek log kalau ada masalah
```

Skema database otomatis dibuat saat container `db` pertama kali dijalankan (lewat `db/schema.sql` yang di-mount sebagai init script).

## Struktur folder

```
src/
├── config/db.js          # koneksi pool PostgreSQL
├── middleware/            # auth (JWT) dan error handler terpusat
├── modules/
│   ├── auth/               # register, login
│   ├── produk/              # CRUD master produk
│   ├── outlet/              # CRUD master outlet
│   ├── titip/               # input harian titip + sinkronisasi batch
│   ├── pesanan/              # pesanan custom + pemesan
│   ├── laporan/              # rekap titip per outlet & rekap pesanan
│   └── sync/                # pull/push untuk multi-perangkat
├── utils/                  # ApiError, asyncHandler, response helper
├── app.js                  # setup Express + routing
└── server.js                # entry point
db/
├── schema.sql               # skema tabel (lihat dokumen Database Design)
├── migrate.js                # runner untuk schema.sql
└── seed.js                    # data contoh untuk development
```

Setiap modul mengikuti pola **Controller -> Service -> Repository** sesuai dokumen SDD Bagian 2:
- **Controller**: menerima request, memanggil service, mengembalikan response.
- **Service**: logika bisnis dan validasi.
- **Repository**: satu-satunya lapisan yang menyentuh database.

## Keamanan multi-tenant

Setiap request (kecuali register/login) wajib menyertakan header `Authorization: Bearer <token>`.
Middleware `authMiddleware` mengambil `user_id` dari token JWT, dan seluruh query di repository memfilter berdasarkan `user_id` tersebut, bukan dari parameter request. Ini mencegah satu akun mengakses data akun lain (lihat dokumen SAD Bagian 7).

## Daftar endpoint

Lihat dokumen **REST API Spec: UMKM Titip** untuk daftar lengkap endpoint, format request/response, dan kode error standar. Ringkasan singkat:

| Modul | Endpoint |
| --- | --- |
| Auth | `POST /api/v1/auth/register`, `POST /api/v1/auth/login` |
| Produk | `GET/POST /api/v1/produk`, `PUT/DELETE /api/v1/produk/:id` |
| Outlet | `GET/POST /api/v1/outlet`, `PUT/DELETE /api/v1/outlet/:id` |
| Titip | `GET /api/v1/titip`, `POST /api/v1/titip/sync` |
| Pesanan | `GET/POST /api/v1/pesanan`, `PATCH /api/v1/pesanan/:id/status`, `DELETE /api/v1/pesanan/:id` |
| Pemesan | `GET/POST /api/v1/pemesan` |
| Laporan | `GET /api/v1/laporan/titip-outlet`, `GET /api/v1/laporan/pesanan` |
| Sync | `POST /api/v1/sync/pull`, `POST /api/v1/sync/push` |

## Deploy ke VPS

**Sudah live di production.** Backend berjalan di VPS lewat Docker Compose (container app + db + nginx), dengan domain `api-backend.umkm-titip.web.id` dan SSL (Let's Encrypt, auto-renew via cron) sudah aktif. Base URL API: `https://api-backend.umkm-titip.web.id/api/v1`. Detail langkah setup ada di dokumen **Deployment & Maintenance Guide: UMKM Titip**.
