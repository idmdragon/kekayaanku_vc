# Progres Kekayaanku

Terakhir diperbarui: 12 Oktober 2026.

## Tahap

| Tahap | Status | Catatan |
|---|---|---|
| 1. PRD | Disetujui | `docs/prd.md` v1.4 |
| 2. HLD | Disetujui | `docs/hld.md` |
| 3. Design system + sketsa + mockup | Disetujui (12 Okt 2026) | `docs/design-system.md` v1.0 |
| 4. Setup repo, CLAUDE.md, PROGRESS.md, CI | Sedang berjalan | Kerangka Flutter, theme token, Supabase CLI, CI |
| 5. Vertical slice | Belum mulai | Lihat di bawah |

## Tahap 4: isi setup
- [x] Flutter 3.47.7 (web + Android), dependensi dikunci di `pubspec.lock`
- [x] Theme token dari design system: warna (dark/light × aksen amber/lime/biru), tipografi Geist, spasi, radius, breakpoint, ikon Lucide
- [x] Format angka rupiah berbasis `Decimal` + test
- [x] Test kontras WCAG untuk semua kombinasi tema
- [x] Supabase CLI (`supabase/config.toml`, folder migrasi, test pgTAP awal)
- [x] CI: analyze, test, build web, `supabase test db`, gitleaks
- [x] Workflow deploy GitHub Pages (menunggu keputusan repo publik/privat, aktif lewat variabel `PAGES_ENABLED`)
- [ ] Ilham membuat project Supabase (region Singapura) dan mengisi secret

## Tahap 5: spike lebih dulu (HLD bagian 13)
- [ ] S-1 pg_cron + pg_net di Free memanggil Edge Function
- [ ] S-2 Yahoo chart endpoint (`BBCA.JK`, `^JKSE`, `BTC-IDR`, `IDR=X`)
- [ ] S-3 Harga buyback Galeri24 dari HTML mentah

## Tahap 5: urutan slice (HLD bagian 14)
1. [ ] Fondasi: auth, profil, kantong (portofolio), RLS + test RLS
2. [ ] Tabungan IDR + kas kantong + cashflow modal + snapshot + Overview net worth
3. [ ] Saham: instrumen, harga Yahoo, beli/jual, avg, break-even, realized P/L, preset fee
4. [ ] Kripto dan valas (kurs)
5. [ ] Emas (Galeri24) dan reksadana (NAV manual + pengingat)
6. [ ] Deposito, utang, piutang
7. [ ] Performa unit + pembanding IHSG/BTC + rentang grafik
8. [ ] Statistik (realized, unrealized, rentang kustom), ekspor CSV, backup, keep-alive, hardening

## Ditunda (dikerjakan di slice terkait)
- Bundel font emoji untuk ikon kantong (konsistensi lintas platform), slice 1
- Workflow keep-alive harian dan backup mingguan terenkripsi `age`, slice 8
- Edge Functions Deno (`fetch-prices`, `refresh-quotes`, `add-instrument`, `health`) dan job `deno test` di CI, mulai spike S-1/S-2
- Layar status setup sementara (`lib/features/setup`) dihapus saat slice 1 membawa layar login

## Keputusan terbuka
- Repo `idmdragon/kekayaanku_vc` privat, sedangkan GitHub Pages di akun GitHub Free butuh repo publik **[PERLU DIVERIFIKASI]**. Menunggu pilihan Ilham.
