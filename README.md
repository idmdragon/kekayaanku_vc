# Kekayaanku

Pelacak kekayaan bersih pribadi. Snapshot harian lintas aset (saham, kripto, emas, reksadana, deposito, tabungan rupiah dan valas, utang, piutang), semuanya dihitung dalam rupiah.

- Aplikasi: Flutter (web dan Android)
- Backend: Supabase Free (Postgres + RLS + Auth + pg_cron + Edge Functions)
- Dokumen: [PRD](docs/prd.md) · [HLD](docs/hld.md) · [Design system](docs/design-system.md) · [Progres](PROGRESS.md)

## Persiapan

Butuh Flutter **3.47.7** (stable, Dart 3.13.5), Node 20+ untuk Supabase CLI, dan Docker untuk database lokal.

```bash
flutter pub get
cp dart_defines.example.json dart_defines.json   # isi URL dan publishable key Supabase
flutter run -d chrome --dart-define-from-file=dart_defines.json
```

`dart_defines.json` di-ignore git. Tanpa file itu aplikasi tetap jalan dan menampilkan status "Belum dikonfigurasi".

## Database lokal

```bash
npx supabase start      # Postgres + Auth lokal lewat Docker
npx supabase test db    # test pgTAP di supabase/tests
npx supabase stop
```

## Pemeriksaan sebelum commit

```bash
flutter analyze
flutter test
npx supabase test db
```

CI menjalankan ketiganya, ditambah build web dan pemindaian secret (gitleaks).
