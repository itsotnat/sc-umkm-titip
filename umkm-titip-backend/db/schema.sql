-- Skema database UMKM Titip
-- Sesuai dokumen "Database Design: UMKM Titip" (Capstone STSI4440)
-- Jalankan dengan: psql -U <user> -d <database> -f db/schema.sql

CREATE EXTENSION IF NOT EXISTS pgcrypto; -- untuk gen_random_uuid()

-- =========================================================
-- users
-- =========================================================
CREATE TABLE IF NOT EXISTS users (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nama_usaha     VARCHAR(150) NOT NULL,
    nama_pemilik   VARCHAR(150) NOT NULL,
    email          VARCHAR(150) UNIQUE NOT NULL,
    no_hp          VARCHAR(30) UNIQUE,
    password_hash  VARCHAR(255) NOT NULL,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =========================================================
-- produk
-- =========================================================
CREATE TABLE IF NOT EXISTS produk (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    nama_produk   VARCHAR(150) NOT NULL,
    hpp           DECIMAL(12,2) NOT NULL DEFAULT 0,
    harga_jual    DECIMAL(12,2) NOT NULL DEFAULT 0,
    sync_status   VARCHAR(20) NOT NULL DEFAULT 'synced',
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_produk_user_id ON produk(user_id);

-- =========================================================
-- outlet
-- =========================================================
CREATE TABLE IF NOT EXISTS outlet (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    nama_outlet   VARCHAR(150) NOT NULL,
    alamat        TEXT,
    no_whatsapp   VARCHAR(30),
    sync_status   VARCHAR(20) NOT NULL DEFAULT 'synced',
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_outlet_user_id ON outlet(user_id);

-- =========================================================
-- pemesan
-- =========================================================
CREATE TABLE IF NOT EXISTS pemesan (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    nama_pemesan  VARCHAR(150) NOT NULL,
    no_whatsapp   VARCHAR(30),
    sync_status   VARCHAR(20) NOT NULL DEFAULT 'synced'
);
CREATE INDEX IF NOT EXISTS idx_pemesan_user_id ON pemesan(user_id);

-- =========================================================
-- transaksi_titip
-- =========================================================
CREATE TABLE IF NOT EXISTS transaksi_titip (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    outlet_id       UUID NOT NULL REFERENCES outlet(id) ON DELETE CASCADE,
    produk_id       UUID NOT NULL REFERENCES produk(id) ON DELETE CASCADE,
    tanggal         DATE NOT NULL,
    jumlah_kirim    INT NOT NULL DEFAULT 0,
    -- NULL berarti retur belum diinput (beda dari 0 = sudah dikonfirmasi
    -- habis terjual/tidak ada retur). jumlah_terjual ikut NULL selama retur
    -- belum diisi, karena belum bisa dihitung.
    jumlah_retur    INT,
    jumlah_terjual  INT GENERATED ALWAYS AS (jumlah_kirim - jumlah_retur) STORED,
    sync_status     VARCHAR(20) NOT NULL DEFAULT 'synced',
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_titip_user_id ON transaksi_titip(user_id);
CREATE INDEX IF NOT EXISTS idx_titip_user_tanggal ON transaksi_titip(user_id, tanggal);
CREATE INDEX IF NOT EXISTS idx_titip_outlet_tanggal ON transaksi_titip(outlet_id, tanggal);

-- =========================================================
-- pesanan (header)
-- =========================================================
CREATE TABLE IF NOT EXISTS pesanan (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id               UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    pemesan_id            UUID NOT NULL REFERENCES pemesan(id) ON DELETE CASCADE,
    tanggal_pesan         DATE NOT NULL DEFAULT CURRENT_DATE,
    tanggal_jatuh_tempo   DATE NOT NULL,
    status_selesai        BOOLEAN NOT NULL DEFAULT false,
    status_lunas          BOOLEAN NOT NULL DEFAULT false,
    catatan               TEXT,
    sync_status           VARCHAR(20) NOT NULL DEFAULT 'synced',
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_pesanan_user_id ON pesanan(user_id);
CREATE INDEX IF NOT EXISTS idx_pesanan_user_jatuh_tempo ON pesanan(user_id, tanggal_jatuh_tempo);

-- =========================================================
-- pesanan_detail
-- =========================================================
CREATE TABLE IF NOT EXISTS pesanan_detail (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pesanan_id  UUID NOT NULL REFERENCES pesanan(id) ON DELETE CASCADE,
    produk_id   UUID NOT NULL REFERENCES produk(id) ON DELETE CASCADE,
    jumlah      INT NOT NULL DEFAULT 1
);
CREATE INDEX IF NOT EXISTS idx_pesanan_detail_pesanan_id ON pesanan_detail(pesanan_id);
