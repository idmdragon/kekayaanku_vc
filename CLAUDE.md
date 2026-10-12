# CLAUDE.md

Panduan kerja untuk Claude (dan siapa pun) di repo ini. Baca bersama `docs/prd.md`, `docs/hld.md`, `docs/design-system.md`, dan `PROGRESS.md`.

## Alur kerja wajib
1. Tahap 1 PRD, 2 HLD, 3 design system + mockup, 4 setup repo: selesai/disetujui Ilham. Status terkini di `PROGRESS.md`.
2. Tahap 5 dikerjakan per **vertical slice**: migrasi DB → fungsi/RPC SQL + test pgTAP → UI → commit. Satu slice satu PR, test ikut di PR yang sama.
3. Hal yang ambigu ditanyakan ke Ilham (beberapa pertanyaan sekaligus, bukan satu per satu). **Jangan menebak aturan keuangan.** Tandai asumsi secara eksplisit (`[ASUMSI ...]`) di PRD/HLD.
4. Perbarui `PROGRESS.md` di setiap PR yang mengubah status slice.

## Aturan keuangan
- Semua logika keuangan (avg price, break-even, realized/unrealized P/L, deposito, valuasi, snapshot, performa unit) ada di **fungsi SQL Postgres** dengan tipe `numeric`. Flutter tidak menghitung ulang; hanya memanggil RPC.
- Di Dart, uang memakai `Decimal` (paket `decimal`), **tidak pernah `double`**.
- Pajak, fee broker, bunga dan pajak deposito, spread buyback: **harus bisa dikonfigurasi** (tabel preset/pengaturan), bukan konstanta di kode, dan diberi catatan "perlu diverifikasi" di UI dan dokumen (PRD bagian 16).
- Setiap fungsi perhitungan wajib punya test. Contoh angka di PRD bagian 7 dijadikan test pgTAP.
- Tanggal bisnis = tanggal kalender WIB (`Asia/Jakarta`); timestamp disimpan UTC.

## UI (skill flutter-anti-slop-ui)
- Ikuti `docs/design-system.md` dan mockup yang disetujui. Hindari tampilan generik AI.
- Warna hanya dari `context.colors` (`AppColors`), angka dari `AppNumberStyles` (tabular), teks dari `Theme.of(context).textTheme`. Spasi dan radius dari `AppSpacing` / `AppRadius`. **Tidak ada hex, `Colors.*`, atau angka padding/ukuran hardcode** di luar `lib/core/theme/`.
- Ikon hanya lewat `AppIcons` (`lib/core/theme/app_icons.dart`), satu-satunya file yang mengimpor paket ikon.
- Setiap layar punya state loading (skeleton), empty (pesan + aksi), dan error (bisa dicoba ulang).
- Responsif: compact < 600, medium 600–1024, expanded > 1024 (`AppBreakpoints`). Web memakai max-width dan navigasi samping, bukan layout HP yang direntangkan.
- Kontras teks ≥ 4.5:1 (dijaga `test/core/theme/contrast_test.dart`), tap target ≥ 48, label Semantics, hormati text scaling.
- Teks UI berbahasa Indonesia, kecuali label rentang waktu (Daily/Weekly/…) yang memang bahasa Inggris sesuai mockup. Minus memakai `−` (U+2212), lihat `lib/core/format/money.dart`.

## Stack (versi dikunci di pubspec.lock)
Flutter 3.47.7 / Dart 3.13.5 · flutter_riverpod · go_router (URL hash untuk GitHub Pages) · supabase_flutter · fl_chart · decimal · intl (`id_ID`) · freezed + json_serializable · lucide_icons_flutter · font Geist (variable, dibundel di `assets/fonts`).

Struktur feature-first: `lib/core/` (theme, router, config, format) dan `lib/features/<fitur>/{data,domain,presentation}`. Widget bersama di `lib/shared/widgets`.

## Secret
- **Jangan pernah commit secret.** Konfigurasi lewat `--dart-define-from-file=dart_defines.json` (di-ignore). Contoh: `dart_defines.example.json`.
- App hanya memegang `SUPABASE_URL` dan `SUPABASE_PUBLISHABLE_KEY` (publik secara desain; keamanan dari RLS). Service role key hanya di secret Supabase untuk Edge Functions. `SUPABASE_DB_URL` hanya di secret GitHub Actions untuk backup.
- Setiap tabel milik user: RLS aktif + test RLS.

## Perintah
```bash
flutter analyze && flutter test
npx supabase start && npx supabase test db
dart run build_runner build --delete-conflicting-outputs   # setelah mengubah model freezed
```

## Commit
Pesan commit dalam bahasa Inggris, imperatif, ringkas. Branch per slice (`slice/<n>-<nama>`), PR ke `main`, CI harus hijau.
