# HLD: Kekayaanku

| | |
|---|---|
| Status | **v1.0, disetujui Ilham (12 Oktober 2026)**. v0.2: GitHub Pages, backup disetujui, login email + password saja. |
| Tahap | 2 dari 5 (HLD) |
| Tanggal | 12 Oktober 2026 |
| Dasar | `docs/prd.md` v1.0 (disetujui) |
| Berikutnya | `docs/design-system.md` (Tahap 3) |

Penanda: **[KEPUTUSAN D-n]** pilihan arsitektur beserta alasannya, **[ASUMSI H-n]** hal yang saya anggap benar dan bisa dibatalkan, **[PERLU DIVERIFIKASI]** fakta eksternal yang harus dicek ulang saat implementasi, **[SPIKE]** hal yang harus dibuktikan dengan percobaan kecil di awal Tahap 5 sebelum dibangun penuh.

---

## 1. Ringkasan arsitektur

```
┌──────────────────────────── Flutter app (web + Android + iOS) ────────────────────────────┐
│  UI (design system)  →  Riverpod providers  →  Repository  →  supabase_flutter (anon key)  │
│  Hitungan tampilan saja: rebase seri, format IDR, resampling grafik                         │
└───────────────┬──────────────────────────────────────────────────────┬────────────────────┘
                │ PostgREST (tabel + RPC), Auth (JWT)                   │ invoke (refresh harga)
                ▼                                                       ▼
┌──────────────────────────── Supabase (Free plan) ──────────────────────────────────────────┐
│ Postgres                                                                                    │
│  • Tabel user (RLS: user_id = auth.uid())   • Tabel global harga/kurs (baca saja)           │
│  • Fungsi SQL: recalc posisi, valuasi, deposito, snapshot, performa unit  (SATU sumber)     │
│  • pg_cron: ambil harga 3×/hari, snapshot 11:00 UTC (+retry), pemeliharaan                  │
│  • pg_net: memanggil Edge Function dari pg_cron                                             │
│ Edge Functions (Deno/TypeScript)                                                            │
│  • fetch-prices: PriceProvider → Yahoo, Galeri24 (scrape), Logam Mulia (cadangan)           │
│  • refresh-quotes: dipicu app, dibatasi frekuensi    • add-instrument: validasi ticker      │
│ Auth: email + password                                                                       │
└─────────────────────────────────────────────────────────────────────────────────────────────┘
        ▲ ping harian (keep-alive) + backup mingguan terenkripsi
┌───────┴────────────┐        ┌──────────────────────┐
│ GitHub Actions     │        │ GitHub Pages         │  ← hosting Flutter web (statis)
│ CI, keep-alive,    │        └──────────────────────┘
│ backup             │
└────────────────────┘
```

**[KEPUTUSAN D-1] Backend: Supabase Free plan.** Postgres + RLS + Auth + pg_cron + Edge Functions dalam satu tempat, sesuai kebutuhan PRD (multi-user, data global vs per user, job terjadwal).

**[KEPUTUSAN D-2] Logika keuangan tinggal di Postgres (fungsi SQL), bukan di Flutter.** Avg price, realized P/L, break-even, nilai deposito, valuasi, snapshot, dan performa unit ditulis sebagai fungsi SQL dengan tipe `numeric` (desimal eksak). Alasan:
- Snapshot harus berjalan di server tanpa app terbuka. Kalau logika ada di Dart, logika yang sama harus ditulis ulang di server (dua implementasi = angka bisa beda).
- pg_cron bisa memanggil fungsi SQL langsung, tanpa batas waktu 150 detik Edge Function dan tanpa ketergantungan HTTP.
- App membaca hasil yang sama persis dengan yang disimpan snapshot.
- Diuji dengan **pgTAP** (`supabase test db`), memenuhi kewajiban unit test di PRD.

Alternatif yang ditolak: logika di paket Dart murni (snapshot lewat GitHub Actions menjalankan Dart; jadwal GitHub Actions bisa telat atau terlewat), atau logika di TypeScript Edge Function (Flutter tetap perlu pratinjau, tetap dua bahasa).

**[KEPUTUSAN D-3] Hosting web: GitHub Pages** (dipilih Ilham, 12 Okt), di-deploy dari GitHub Actions. Cloudflare Pages tetap jadi opsi pindah nanti. Android: APK pribadi (PRD A-32). Konsekuensi teknis:
- **GitHub Pages pada akun GitHub Free hanya untuk repo publik**; repo privat butuh GitHub Pro **[PERLU DIVERIFIKASI]** terhadap paket akun Ilham. Kode publik aman selama tidak ada secret di repo (sudah jadi aturan) dan data tetap di Supabase dengan RLS. Lihat pertanyaan di Bagian 15.
- App disajikan di sub-path (`https://<user>.github.io/<repo>/`), jadi build memakai `--base-href /<repo>/`.
- GitHub Pages tidak mendukung rewrite SPA. Routing memakai **hash URL** (`/#/dashboard`) agar refresh halaman dan deep link tidak 404. Alternatif (path URL + salinan `404.html`) bisa dipertimbangkan jika URL bersih penting.
- Pages hanya statis dan publik; tidak ada secret di build web selain `SUPABASE_URL` dan anon key (memang publik).

## 2. Batas tier gratis Supabase (dicek 12 Oktober 2026)

Sumber: [halaman harga Supabase](https://supabase.com/pricing), [batas Edge Functions](https://supabase.com/docs/guides/functions/limits), [dokumentasi Cron](https://supabase.com/docs/guides/cron).

| Sumber daya | Batas Free | Perkiraan pemakaian Kekayaanku | Status |
|---|---|---|---|
| Ukuran database | 500 MB per project | ±4 MB/user/tahun (lihat 6.4) | Aman untuk puluhan user beberapa tahun |
| Egress | 5 GB/bulan (+5 GB cached) | Dashboard ±50–200 KB per buka | Aman |
| Monthly active users | 50.000 | Sedikit | Aman |
| Edge Function invocations | 500.000/bulan | ±100 terjadwal + refresh manual | Aman |
| Edge Function | 150 detik wall clock, **2 detik CPU**, 256 MB | Fetch harga = I/O; parsing HTML ringan | Perlu dijaga (batch, lihat 5.3) |
| Project aktif | 2 | 1 produksi; dev memakai Supabase lokal (Docker) | Aman |
| **Dijeda jika tidak aktif** | **7 hari tanpa aktivitas** | Saat dijeda, pg_cron ikut berhenti → snapshot hilang | **Risiko utama, mitigasi 8.1** |
| Backup otomatis / PITR | **Tidak ada** di Free | | **Mitigasi 8.2** |
| Log retention | 1 hari | | Simpan log job sendiri di tabel |
| Cron | Disarankan ≤ 8 job bersamaan, ≤ 10 menit per job | 4–5 job, berjalan bergantian | Aman |

**[PERLU DIVERIFIKASI]** Ketersediaan pg_cron dan pg_net di Free plan tidak disebutkan eksplisit di halaman harga; praktik umum menunjukkan tersedia. Dibuktikan di [SPIKE S-1] saat project dibuat. Batas-batas di atas dicek ulang setiap kali ada keputusan yang bergantung padanya.

## 3. Komponen

### 3.1 Flutter app
- **[KEPUTUSAN D-4] Stack:** `supabase_flutter`, `flutter_riverpod` (state + DI), `go_router` (routing, deep link web), `fl_chart` (grafik, MIT), `decimal` (uang di sisi klien, tidak pernah `double`), `intl` (format `id_ID`), `freezed` + `json_serializable` (model). Versi dikunci saat Tahap 4.
- Struktur feature-first:
  ```
  lib/
    core/        (theme & design token, router, supabase client, format angka, error)
    features/
      auth/ dashboard/ portfolios/ holdings/ transactions/ stats/
      benchmarks/ snapshots/ settings/ debts_receivables/
        data/ (repository, DTO)   domain/ (model, logika tampilan)   presentation/ (layar, widget)
  ```
- App **tidak** menghitung avg, P/L, atau valuasi sendiri. App memanggil RPC (mis. `preview_sell`, `holding_detail`) dan menampilkan hasil. Logika di Dart hanya: rebase seri ke 100, resampling harian→mingguan, format angka, validasi form ringan.
- Konfigurasi lewat `--dart-define` / `--dart-define-from-file` (file tidak di-commit): `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` (nama baru Supabase untuk anon key; `supabase_flutter` 2.18 menandai `anonKey` usang). Key ini memang publik secara desain, keamanan bertumpu pada RLS.

### 3.2 Postgres
- Skema `public` untuk tabel yang diakses app, skema `private` untuk fungsi internal dan tabel log yang tidak diekspos ke API.
- Semua perhitungan uang memakai `numeric` tanpa pembulatan; pembulatan hanya di tampilan.
- Semua timestamp `timestamptz` (UTC). Tanggal bisnis (`tx_date`, `snap_date`, `price_date`) adalah `date` kalender WIB: `(now() at time zone 'Asia/Jakarta')::date`.

- **[KEPUTUSAN D-10] Auth:** Supabase Auth email + password, dengan verifikasi email dan reset kata sandi lewat email bawaan Supabase. **[PERLU DIVERIFIKASI]** batas kirim email bawaan Supabase di Free plan (cukup untuk pemakaian pribadi; SMTP sendiri bisa ditambah nanti).

### 3.3 Edge Functions (Deno/TypeScript)
| Fungsi | Dipanggil oleh | Tugas |
|---|---|---|
| `fetch-prices` | pg_cron (via pg_net) | Ambil harga semua instrumen global aktif lewat rantai provider, tulis ke `prices_daily` dan `fx_rates_daily` |
| `refresh-quotes` | App (user login) | Segarkan harga instrumen milik user tertentu, maksimal sekali per 15 menit per instrumen |
| `add-instrument` | App | Validasi ticker Yahoo kustom (saham, koin, pembanding), daftarkan sebagai instrumen global, backfill riwayat harga |
| `health` | GitHub Actions | Endpoint keep-alive ringan (query `select 1`) |

Edge Function memakai service role key dari secret Supabase (tidak pernah ke app, tidak pernah di repo).

### 3.4 GitHub Actions
- CI: analisis + test Flutter, `supabase test db` (pgTAP), `deno test`, build web, deploy ke GitHub Pages dari branch utama.
- Keep-alive harian dan backup mingguan (Bagian 8).

## 4. Abstraksi provider harga

**[KEPUTUSAN D-5]** Antarmuka di Edge Function (TypeScript), karena pengambilan harga terjadi di server:

```ts
interface PriceProvider {
  id: string;                                   // 'yahoo' | 'galeri24' | 'logammulia' | 'manual'
  supports(instrument: Instrument): boolean;
  fetchLatest(instruments: Instrument[]): Promise<QuoteResult[]>;   // batch
  fetchHistory?(instrument: Instrument, from: Date, to: Date): Promise<Quote[]>;
}
type QuoteResult = { instrumentId: string; ok: true; quote: Quote } | { instrumentId: string; ok: false; error: string };
type Quote = { priceDate: string; price: string /* desimal sebagai string */; currency: string;
               sourceUpdatedAt?: string; raw?: unknown };
```

- Setiap instrumen punya `provider_chain` (mis. `['yahoo']`, `['galeri24','logammulia']`). Provider dicoba berurutan; kegagalan dicatat di `price_fetch_log`, tidak menghentikan instrumen lain.
- Provider baru (mis. API berbayar atau sumber resmi) cukup menambah satu kelas dan mengubah `provider_chain`, tanpa menyentuh logika SQL.

| Provider | Instrumen | Cara | Catatan |
|---|---|---|---|
| Yahoo Finance | Saham `.JK`, `^JKSE`, kripto `XXX-IDR`/`XXX-USD`, kurs `IDR=X` | Endpoint chart (`/v8/finance/chart/{symbol}`) | Tidak resmi; format bisa berubah, kemungkinan rate limit. **[PERLU DIVERIFIKASI]** bahwa `IDR=X` cukup mewakili kurs mid-market. **[SPIKE S-2]** |
| Galeri24 | Buyback emas Antam, UBS, Galeri24 per pecahan | Ambil HTML halaman harga emas, parse tabel | Scraping; ketentuan situs **[PERLU DIVERIFIKASI]**. **[SPIKE S-3]**: pastikan harga ada di HTML (bukan dimuat JavaScript) |
| Logam Mulia | Buyback Antam (cadangan) | Scraping | Situs sering memblokir bot; hanya cadangan |
| Manual | Reksadana (NAV), koin tanpa ticker, pembanding manual, override apa pun | Input user di `user_prices` | Selalu tersedia |

**Prioritas harga** (PRD F-PRICE-4) dihitung di SQL oleh `price_for(user, instrument, date)`: `user_prices` tanggal itu → `prices_daily` tanggal ≤ itu yang terbaru → tidak ada (nilai 0 + penanda "tanpa harga"). Fungsi mengembalikan juga `price_date` dan `source` agar penanda basi bisa ditampilkan.

## 5. Job terjadwal

### 5.1 Jadwal (pg_cron, UTC)

| Job | Cron (UTC) | WIB | Isi |
|---|---|---|---|
| `fetch_prices_morning` | `30 1 * * *` | 08:30 | `fetch-prices` (emas, kurs, kripto) |
| `fetch_prices_midday` | `0 5 * * *` | 12:00 | `fetch-prices` (semua) |
| `fetch_prices_presnap` | `30 10 * * *` | 17:30 | `fetch-prices` (semua; penutupan IDX sudah lewat) |
| `take_snapshots` | `0 11 * * *` | 18:00 | `select private.take_all_snapshots(current_date_wib())` |
| `take_snapshots_retry` | `*/30 11-16 * * *` | 18:30–23:30 | Fungsi yang sama; idempoten, hanya user yang belum punya snapshot hari itu |
| `maintenance` | `0 18 * * *` | 01:00 | Bersihkan log lama (> 90 hari), cek NAV basi & jatuh tempo → tabel `alerts` |

**[ASUMSI H-1]** Snapshot memakai harga yang sudah ada di database pukul 18:00, bukan menunggu fetch selesai. Fetch 17:30 memberi jeda 30 menit; kalau gagal, harga terakhir dipakai dengan penanda basi (PRD F-SNAP-3).

### 5.2 Algoritma snapshot (per user, satu transaksi DB)

1. Jika `snapshots(user, d)` sudah ada → lewati (idempoten).
2. `valuation := private.valuate_user(user, d)`: untuk setiap holding aktif, ambil posisi (`holding_positions`) dan harga (`price_for`) atau hitung nilai (deposito, tabungan, utang, piutang), konversi ke IDR dengan kurs `d`.
3. Tulis `snapshot_items` (per holding), `snapshot_portfolios` (per portofolio), dan header `snapshots` (total aset, piutang dihitung, utang, net worth, kurs yang dipakai).
4. Cashflow: ambil semua cashflow modal yang belum dihitung (`counted_on is null`, `tx_date ≤ d`), jumlahkan (total dan per portofolio), tandai `counted_on = d` (PRD A-30: yang terlambat masuk snapshot berikutnya).
5. Performa unit (PRD 7.8) total dan per portofolio, dari unit snapshot sebelumnya.
6. Catat ke `job_runs` (mulai, selesai, jumlah user, error).

Kesalahan pada satu user tidak menggagalkan user lain (blok `exception` per user, dicatat, dicoba ulang oleh job retry).

### 5.3 Strategi fetch harga
- Kumpulkan instrumen global yang dipegang minimal satu user atau dipakai sebagai pembanding (`instruments.is_active`).
- Yahoo: batch beberapa simbol per pemanggilan fungsi dengan jeda kecil; data harga disimpan per `price_date` (upsert, nilai hari ini ditimpa oleh fetch berikutnya).
- Galeri24: satu request halaman → semua merek dan pecahan sekaligus.
- Menjaga batas 2 detik CPU: parsing HTML dengan regex/parser ringan; jika jumlah instrumen besar, `fetch-prices` dipanggil per kelompok (`?group=stocks`, `?group=gold`, ...).

## 6. Model data

### 6.1 Tabel global (dibaca semua user login, ditulis hanya service role)

| Tabel | Kolom utama | Catatan |
|---|---|---|
| `instruments` | `id`, `kind` (`stock`,`crypto`,`gold`,`fx`,`index`,`mutual_fund`,`custom`), `symbol`, `provider_symbol`, `currency`, `name`, `provider_chain text[]`, `meta jsonb` (mis. `{brand:'antam', size_gram:10}`), `owner_user_id` (null = global), `is_active` | Instrumen privat (`owner_user_id = user`) untuk reksadana, koin tanpa ticker, pembanding manual |
| `prices_daily` | `instrument_id`, `price_date`, `price numeric`, `currency`, `source`, `source_updated_at`, `fetched_at` | PK (`instrument_id`, `price_date`) |
| `fx_rates_daily` | `base`, `quote`, `rate_date`, `rate`, `source`, `fetched_at` | PK (`base`,`quote`,`rate_date`); USD→IDR di MVP |
| `price_fetch_log` | `run_id`, `instrument_id`, `provider`, `ok`, `error`, `at` | Skema `private`, retensi 90 hari |

### 6.2 Tabel milik user (semua punya `user_id`, RLS aktif)

| Tabel | Kolom utama |
|---|---|
| `profiles` | `user_id` PK, `display_name`, `timezone` (default `Asia/Jakarta`), `settings jsonb` (ambang NAV, ambang penanda cashflow, rentang grafik terakhir, toggle garis), `benchmark_instrument_id`, `tracking_started_on` |
| `fee_presets` | `id`, `user_id`, `name`, `buy_fee_pct`, `sell_fee_pct`, `sell_tax_pct`, `min_fee`, `note`, `needs_verification bool` |
| `portfolios` | `id`, `user_id`, `name`, `color_token`, `icon`, `fee_preset_id`, `cash_enabled`, `sort_order`, `archived_at` |
| `holdings` | `id`, `user_id`, `portfolio_id`, `category` (`gold`,`crypto`,`stock`,`mutual_fund`,`deposit`,`savings_idr`,`savings_fx`,`receivable`,`debt`,`cash`), `instrument_id` (nullable), `name`, `currency`, `started_on`, `params jsonb`, `archived_at` |
| `transactions` | `id`, `user_id`, `holding_id`, `tx_date`, `type`, `qty`, `price`, `amount`, `fee`, `tax`, `reason` (`tp`,`cut_loss`,`other`), `flow_kind` (`external_in`,`external_out`,`internal`,`income`,`expense`,`none`), `group_id`, `realized_pl` (diisi sistem), `counted_on` (diisi snapshot), `note`, `created_at`, `updated_at` |
| `holding_positions` | `holding_id` PK, `user_id`, `qty`, `avg_price`, `buy_fee_per_unit`, `realized_pl_total`, `cash_balance`, `computed_at` (turunan, diisi sistem) |
| `user_prices` | `user_id`, `instrument_id`, `price_date`, `price`, `note` | PK (`user_id`,`instrument_id`,`price_date`); override harga, NAV, kurs (instrumen `fx` USDIDR), buyback emas, pembanding manual |
| `snapshots` | `user_id`, `snap_date` (PK gabungan), `total_assets`, `total_receivables`, `total_debts`, `net_worth`, `net_flow`, `cum_deposits`, `cum_withdrawals`, `units`, `unit_value`, `fx jsonb`, `stale_count`, `created_at` |
| `snapshot_items` | `user_id`, `snap_date`, `holding_id`, `portfolio_id`, `category`, `qty`, `price`, `price_date`, `price_source`, `value_idr`, `cost_idr` (modal = avg × qty, untuk riwayat P/L) |
| `snapshot_portfolios` | `user_id`, `snap_date`, `portfolio_id`, `value_idr`, `net_flow`, `units`, `unit_value`, `cost_idr`, `unrealized_idr`, `realized_cum_idr`, `cash_idr` (ditambah 12 Okt untuk kartu kantong dan riwayat P/L) |
| `alerts` | `id`, `user_id`, `kind` (`nav_stale`,`deposit_maturing`,`debt_due`,`price_stale`,`snapshot_failed`), `holding_id`, `due_on`, `dismissed_at` |

**Isi `holdings.params` per kategori** (divalidasi oleh CHECK + fungsi validasi, skema dirinci di Tahap 5):
- `gold`: `{brand, size_gram}` (harga dari instrumen emas global brand+size).
- `deposit`: `{bank, principal, rate_pa, start_date, tenor_months, aro_mode: 'none'|'principal'|'principal_interest', net_of_tax, tax_rate, day_basis}`.
- `debt`: `{kind, rate_pa?, installment?, due_day?, end_date?}`.
- `receivable`: `{status: 'current'|'doubtful'|'written_off', include, include_pct, expected_on?}`.
- `savings_fx`: mata uang di `currency`.

**[KEPUTUSAN D-6] Kas portofolio = holding kategori `cash`** (satu per portofolio per mata uang). Beli yang dibayar dari kas membuat dua baris transaksi dalam satu `group_id`: beli aset (`internal`) dan keluar kas (`internal`). Setor dari luar ke kas = `external_in`. Dengan begitu satu aturan berlaku untuk semua kategori: **cashflow modal = semua baris `external_in`/`external_out`**.

**Pemetaan kejadian ke `flow_kind`** (mengikuti PRD 7.7 dan 7.10):

| Kejadian | Baris transaksi |
|---|---|
| Setor dari luar ke kas/tabungan | `deposit` · `external_in` |
| Beli saham dari kas RDN | `buy` (saham) `internal` + `withdraw` (kas) `internal` |
| Jual saham ke kas RDN | `sell` (saham) `internal` + `deposit` (kas) `internal`; `realized_pl` diisi |
| Dividen | `deposit` (kas) · `income` |
| Bayar bunga utang | `withdraw` (sumber) · `expense` |
| Belanja kartu kredit | `borrow` (utang) · `external_out` (PRD A-37) |
| Piutang dihapus | `write_off` · `expense` |
| Pindah aset antar portofolio | `transfer_out` + `transfer_in` · `internal`, satu `group_id` |
| "Set saldo" tabungan | `adjust` · `external_in`/`external_out` (default) atau `income` (ditandai bunga) (PRD A-38) |

### 6.3 Posisi turunan
**[KEPUTUSAN D-7]** `holding_positions` dihitung ulang penuh untuk satu holding setiap kali transaksinya berubah (trigger `after insert/update/delete` → `private.recalc_holding(holding_id)`), dengan memutar ulang semua transaksi holding itu berurutan (`tx_date`, `created_at`). Ini deterministik dan mudah diuji; jumlah transaksi per holding kecil. Fungsi ini juga mengisi `transactions.realized_pl` untuk setiap jual dan menolak jual yang melebihi posisi (PRD F-TX-4).

Snapshot lama tidak pernah disentuh oleh recalc (PRD F-SNAP-2). Edit pada cashflow yang sudah `counted_on` tidak diubah di tempat; sistem membuat baris koreksi selisih yang masuk snapshot berikutnya (H-2).

### 6.4 Estimasi ukuran
- `snapshot_items`: ±40 holding × 365 hari ≈ 14.600 baris/user/tahun × ±200 byte (termasuk indeks) ≈ **3 MB/user/tahun**. Ditambah `snapshots`, `snapshot_portfolios`, transaksi: ≈ **4 MB/user/tahun**.
- `prices_daily`: ±200 instrumen × 365 ≈ 73.000 baris/tahun ≈ 10 MB/tahun (global).
- Dengan 500 MB: sekitar 10 user selama 10 tahun, atau 50 user selama 2 tahun. Jika mendekati 70%, `snapshot_items` untuk data lebih dari 2 tahun bisa dipadatkan ke per kategori (PRD A-15 memperbolehkan).

## 7. Keamanan dan RLS

- RLS **aktif di semua tabel** di skema `public`. Pola tabel user:
  ```sql
  alter table holdings enable row level security;
  create policy "own rows" on holdings for all to authenticated
    using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
  ```
- Tabel turunan (`holding_positions`, `snapshots*`, `alerts`): user hanya `select`; tulis hanya oleh fungsi `security definer` di skema `private` dan service role.
- Tabel global: `select` untuk `authenticated`, tanpa policy tulis. `instruments` privat: `owner_user_id is null or owner_user_id = auth.uid()`.
- Foreign key lintas tabel user wajib milik user yang sama (mis. `holdings.portfolio_id` harus portofolio user itu), ditegakkan oleh constraint komposit (`portfolio_id, user_id`) agar user tidak bisa menautkan ke baris user lain.
- RPC publik (`preview_sell`, `holding_detail`, `dashboard_series`, `move_holding`, ...) adalah `security invoker` sehingga RLS tetap berlaku.
- Test RLS di pgTAP: user A tidak bisa membaca/menulis data user B, user tidak bisa menulis tabel global (PRD kriteria 7).
- Secret: service role key dan connection string DB hanya di Supabase secrets / GitHub Actions secrets. `.env*`, `*.local.json`, `dart_defines*.json` masuk `.gitignore`; CI menjalankan secret scanning (gitleaks).
- Hapus akun: RPC menghapus semua baris user (cascade dari `profiles`) lalu user Auth.

## 8. Keandalan

### 8.1 Mencegah project dijeda
Project Free dijeda setelah 7 hari tanpa aktivitas, dan **pg_cron ikut berhenti** saat dijeda, sehingga snapshot hilang tanpa disadari ([referensi](https://runhooks.app/blog/preventing-supabase-free-tier-pausing/)).
- **[KEPUTUSAN D-8]** GitHub Actions memanggil `health` **setiap hari** (bukan mingguan, untuk margin) dan gagal (email notifikasi GitHub) jika respons tidak sehat.
- Job snapshot sendiri memanggil Edge Function lewat pg_net setiap hari, yang kemungkinan juga terhitung aktivitas. **[PERLU DIVERIFIKASI]**, tidak diandalkan sendirian.
- Jika tetap dijeda: celah snapshot terlihat di grafik dan `alerts` (PRD F-SNAP-4); tidak ada data rekaan.

### 8.2 Backup
Free plan tidak punya backup otomatis.
- **[KEPUTUSAN D-9]** GitHub Actions mingguan menjalankan `pg_dump` (data user + global), mengenkripsinya dengan kunci publik `age` milik Ilham, dan menyimpannya sebagai artifact GitHub (retensi 90 hari). Kunci privat hanya di tangan Ilham. Butuh secret `SUPABASE_DB_URL` di repo (disetujui Ilham, 12 Okt). Secret Actions tetap tersembunyi walaupun repo publik; workflow backup hanya berjalan di branch utama dan tidak dipicu oleh pull request dari fork.
- Ekspor CSV dari app (PRD A-33) sebagai jaring pengaman tambahan per user.

### 8.3 Observabilitas
- Tabel `private.job_runs` dan `private.price_fetch_log` (log Supabase hanya 1 hari).
- Halaman Pengaturan menampilkan status: snapshot terakhir, fetch harga terakhir per sumber, instrumen yang basi.

## 9. Alur utama

**Membuka dashboard.** App memanggil RPC `dashboard_summary()` (nilai live dari `valuate_user(auth.uid(), hari ini)` yang sama dengan yang dipakai snapshot) dan `dashboard_series(range, mode)` (baca `snapshots`, `snapshot_portfolios`, harga pembanding). Rebase ke 100 dan resampling mingguan di Dart. Jika fetch harga terakhir > 15 menit, app memanggil `refresh-quotes` di latar belakang lalu memuat ulang ringkasan.

**Mencatat jual saham.** Form membuka → `preview_sell(holding, qty, price)` mengembalikan fee & pajak dari preset, realized P/L bersih, dan sisa posisi. User menyimpan → RPC `record_trade` menulis baris jual + baris kas dalam satu transaksi DB → trigger recalc → app memuat ulang posisi.

**Menambah ticker/koin kustom.** App → `add-instrument(symbol)` → validasi di Yahoo → simpan instrumen global → backfill riwayat sejak `tracking_started_on` user (khusus pembanding, PRD A-19).

**Pindah aset antar portofolio.** RPC `move_holding(holding, target_portfolio, qty?)`: seluruh jumlah = ganti `portfolio_id`; sebagian = buat holding baru dengan avg yang sama dan pasangan `transfer_out`/`transfer_in`.

## 10. Strategi pengujian (wajib per PRD NF-10)

| Lapisan | Alat | Cakupan wajib |
|---|---|---|
| SQL (logika keuangan) | pgTAP via `supabase test db` | Avg price (beli, jual sebagian, habis lalu beli lagi), break-even, realized P/L bersih (contoh PRD 7.1–7.3), estimasi bersih jika dijual, deposito (akrual, pajak, jatuh tempo akhir bulan, kedua mode ARO), cashflow & `flow_kind`, performa unit (setoran besar tidak mengubah nilai per unit, cashflow terlambat, net worth ≤ 0), snapshot idempoten, RLS |
| Edge Functions | `deno test` dengan fixture HTML/JSON tersimpan | Parser Yahoo dan Galeri24, rantai fallback, penanganan error |
| Flutter | `flutter test` | Rebase/resampling seri, format IDR, widget state loading/empty/error, golden test komponen kunci |
| End-to-end ringan | Supabase lokal + integration test Flutter (web) | Daftar → opening balance → snapshot manual (fungsi dipanggil di test) → dashboard |

Fixture provider disimpan di repo agar test tidak bergantung pada internet.

## 11. Lingkungan dan deployment

| Lingkungan | Database | App |
|---|---|---|
| Lokal | Supabase CLI (Docker) dengan migrasi + seed data contoh | `flutter run -d chrome` / emulator |
| CI | Supabase CLI di GitHub Actions | Test + build |
| Produksi | Supabase Free project (region Singapura, terdekat ke Indonesia) **[ASUMSI H-3]** | GitHub Pages (web), APK dari CI (Android) |

- Migrasi database di `supabase/migrations/` (versi terurut), diterapkan ke produksi via `supabase db push` dari CI setelah test hijau, atau manual oleh Ilham. **[ASUMSI H-4]** MVP: manual, untuk menghindari secret DB produksi di CI selain untuk backup.
- iOS: dibangun bila ada Mac/akun developer; di luar jalur utama MVP.

## 12. Risiko teknis

| Risiko | Mitigasi |
|---|---|
| Endpoint Yahoo berubah/diblokir | Abstraksi provider, harga terakhir + penanda basi, input manual; fixture test mendeteksi perubahan format dengan cepat |
| Halaman Galeri24 dimuat via JavaScript atau berubah struktur | [SPIKE S-3] di awal; cadangan Logam Mulia; input manual per merek+pecahan |
| Project dijeda / snapshot terlewat | Keep-alive harian, alert, celah terlihat (8.1) |
| Data hilang (tanpa backup Free) | Backup terenkripsi mingguan + ekspor CSV (8.2) |
| Logika SQL makin rumit | Fungsi kecil per aturan, setiap fungsi punya test pgTAP; contoh angka PRD jadi test |
| Batas 2 detik CPU Edge Function | Fetch dipecah per kelompok; parsing ringan |
| Batas 500 MB | Estimasi 6.4; pemadatan `snapshot_items` lama jika perlu |

## 13. Spike di awal Tahap 5

| Kode | Pertanyaan | Kriteria lolos |
|---|---|---|
| S-1 | pg_cron + pg_net tersedia di Free dan bisa memanggil Edge Function | Job uji berjalan dan tercatat |
| S-2 | Yahoo chart endpoint dari Edge Function untuk `BBCA.JK`, `^JKSE`, `BTC-IDR`, `IDR=X` | Harga terbaru terbaca konsisten 3 hari |
| S-3 | Harga buyback Galeri24 terbaca dari HTML mentah di Edge Function | Antam, UBS, Galeri24 semua pecahan terbaca |

Jika spike gagal, saya kembali ke Ilham dengan alternatif sebelum lanjut membangun bagian itu.

## 14. Urutan vertical slice (gambaran Tahap 5)

1. Fondasi: auth, profil, portofolio, RLS + test RLS.
2. Tabungan IDR + kas portofolio + cashflow modal + snapshot + dashboard net worth (slice ujung-ke-ujung pertama, membuktikan job harian).
3. Saham: instrumen, harga Yahoo, transaksi beli/jual, avg, break-even, realized P/L, preset fee.
4. Kripto dan tabungan valas (kurs).
5. Emas (Galeri24) dan reksadana (NAV manual + pengingat).
6. Deposito, utang, piutang.
7. Performa unit + pembanding + rentang grafik + toggle garis.
8. Statistik realized, ekspor CSV, backup, keep-alive, hardening.

Setiap slice: migrasi DB → fungsi/RPC + test → UI → commit.

## 15. Keputusan Ilham (12 Oktober 2026)

| No | Keputusan |
|---|---|
| 1 | Hosting web di GitHub Pages dulu (D-3). |
| 2 | Backup mingguan terenkripsi ke artifact GitHub disetujui (D-9). |
| 3 | Login MVP cukup email + password (D-10). Magic link dan Google di luar MVP. |
| 4 | Repo publik atau privat: lihat D-3, menunggu konfirmasi. |

## 16. Daftar keputusan dan asumsi

| Kode | Ringkasan |
|---|---|
| D-1 | Supabase Free plan sebagai backend |
| D-2 | Logika keuangan di fungsi SQL Postgres, diuji pgTAP |
| D-3 | Web di GitHub Pages (hash URL, base-href sub-path), Android APK pribadi |
| D-4 | Flutter: Riverpod, go_router, fl_chart, decimal, intl, freezed |
| D-5 | PriceProvider di Edge Function dengan rantai fallback per instrumen |
| D-6 | Kas portofolio sebagai holding `cash`; cashflow modal = `external_in/out` |
| D-7 | Posisi dihitung ulang penuh per holding lewat trigger |
| D-8 | Keep-alive harian via GitHub Actions |
| D-9 | Backup mingguan `pg_dump` terenkripsi `age` ke artifact GitHub |
| D-10 | Auth MVP: email + password saja (reset kata sandi via email) |
| H-1 | Snapshot memakai harga yang ada pukul 18:00, tidak menunggu fetch |
| H-2 | Edit cashflow yang sudah masuk snapshot dicatat sebagai baris koreksi |
| H-3 | Region produksi Singapura |
| H-4 | Migrasi produksi diterapkan manual di MVP |
