# Progres Kekayaanku

Terakhir diperbarui: 12 Oktober 2026.

## Tahap

| Tahap | Status | Catatan |
|---|---|---|
| 1. PRD | Disetujui | `docs/prd.md` v1.4 |
| 2. HLD | Disetujui | `docs/hld.md` |
| 3. Design system + sketsa + mockup | Disetujui (12 Okt 2026) | `docs/design-system.md` v1.0 |
| 4. Setup repo, CLAUDE.md, PROGRESS.md, CI | Selesai (PR #1) | Kerangka Flutter, theme token, Supabase CLI, CI |
| 5. Vertical slice | Berjalan: slice 2 selesai, menunggu merge | Lihat di bawah |

## Tahap 4: isi setup
- [x] Flutter 3.47.7 (web + Android), dependensi dikunci di `pubspec.lock`
- [x] Theme token dari design system: warna (dark/light × aksen amber/lime/biru), tipografi Geist, spasi, radius, breakpoint, ikon Lucide
- [x] Format angka rupiah berbasis `Decimal` + test
- [x] Test kontras WCAG untuk semua kombinasi tema
- [x] Supabase CLI (`supabase/config.toml`, folder migrasi, test pgTAP awal)
- [x] CI: analyze, test, build web, `supabase test db`, gitleaks
- [x] Workflow deploy GitHub Pages (Ilham memilih repo publik; aktif setelah variabel `PAGES_ENABLED=true`)
- [ ] Ilham membuat project Supabase (region Singapura) dan mengisi secret
- [ ] Di dashboard Supabase: panjang minimal kata sandi 8, Site URL dan Redirect URL ke `https://idmdragon.github.io/kekayaanku_vc/`

## Tahap 5: spike lebih dulu (HLD bagian 13)
- [ ] S-1 pg_cron + pg_net di Free memanggil Edge Function (butuh project Supabase)
- [ ] S-2 Yahoo chart endpoint (`BBCA.JK`, `^JKSE`, `BTC-IDR`, `IDR=X`)
- [ ] S-3 Harga buyback Galeri24 dari HTML mentah

Catatan 12 Okt: lingkungan kerja Claude tidak bisa menjangkau Yahoo dan Galeri24 (diblokir proxy), jadi S-2 dan S-3 dijalankan dari Edge Function setelah project Supabase ada.

## Tahap 5: urutan slice (HLD bagian 14)
1. [x] Fondasi: auth, profil, kantong (portofolio), RLS + test RLS
   - DB: `profiles`, `portfolios`, trigger signup (profil + kantong "Utama"), `reorder_portfolios`, `delete_account`; 31 assert pgTAP
   - App: masuk, daftar, lupa/ubah kata sandi; navigasi bawah (HP) dan sidebar (web); tab Kantong daftar/grid; buat, ubah, arsipkan, hapus, urutkan kantong; Profil (tampilan tema + aksen, akun, hapus akun); Overview/Statistik/Riwayat masih state kosong
   - Belum: saldo awal kas kantong (butuh tabel holdings, slice 2)
2. [x] Tabungan IDR + kas kantong + cashflow modal + snapshot + Overview net worth
   - DB: `holdings`, `transactions`, `holding_positions`, `snapshots`, `snapshot_items`, `snapshot_portfolios`; RPC setor/tarik/set saldo/ubah transaksi; koreksi cashflow (H-2); snapshot harian + performa unit; `dashboard_summary`, `snapshot_history`; 77 assert pgTAP
   - App: Tambah aset (uang rupiah aktif, jenis lain "segera"), detail aset (set saldo, setor, tarik, edit/hapus transaksi), kas kantong + saldo awal kas, Overview (net worth, perubahan hari ini, grafik net worth vs disetor bersih, alokasi), Riwayat per bulan
   - Setelah merge: jalankan `supabase/migrations/20261013090000_holdings_cashflow_snapshots.sql` di SQL Editor dan aktifkan ekstensi `pg_cron` agar snapshot 18:00 WIB berjalan
3. [ ] Saham: instrumen, harga Yahoo, beli/jual, avg, break-even, realized P/L, preset fee
4. [ ] Kripto dan valas (kurs)
5. [ ] Emas (Galeri24) dan reksadana (NAV manual + pengingat)
6. [ ] Deposito, utang, piutang
7. [ ] Performa unit + pembanding IHSG/BTC + rentang grafik
8. [ ] Statistik (realized, unrealized, rentang kustom), ekspor CSV, backup, keep-alive, hardening

## Ditunda (dikerjakan di slice terkait)
- Bundel font emoji untuk ikon kantong (konsistensi lintas platform): belum, emoji memakai font sistem/Noto bawaan Flutter web
- Workflow keep-alive harian dan backup mingguan terenkripsi `age`, slice 8
- Edge Functions Deno (`fetch-prices`, `refresh-quotes`, `add-instrument`, `health`) dan job `deno test` di CI, mulai spike S-1/S-2
- Layar status setup kini hanya tampil jika build tidak punya konfigurasi Supabase

## Keputusan
- 12 Okt: saldo awal aset yang ditambah setelah snapshot pertama dihitung setoran (PRD A-42, pilihan Ilham).
- 12 Okt: perubahan hari ini tidak memasukkan setor/tarik sejak snapshot terakhir (PRD A-43, disetujui Ilham).
- 12 Okt: repo dijadikan publik agar web bisa di GitHub Pages (pilihan Ilham).
