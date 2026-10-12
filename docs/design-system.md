# Design System: Kekayaanku

| | |
|---|---|
| Status | **v1.0, disetujui Ilham (12 Oktober 2026)** sebagai akhir Tahap 3. Implementasi di `lib/core/theme/` |
| Tahap | 3 dari 5 (design system + mockup) |
| Tanggal | 12 Oktober 2026 |
| Arah | **B · Grafik dulu + Kantong** (dipilih Ilham, 12 Okt), beranda mengikuti rujukan Oraivo, bottom navigation 5 tab, ikon profesional, emoji per kantong, gambar aset opsional |
| Sketsa | [Sketsa Layar Kekayaanku](https://claude.ai/artifact/AyeeFFdrX3943e3LJNc4XA) (gambaran kasar 6 layar, memakai 3 gambar rujukan dari Ilham) |
| Mockup | [Mockup Kekayaanku](https://claude.ai/artifact/FqxRE1tg7b79wF4qcNKLbh) (v2, bisa diklik, mengikuti sketsa v9; tema gelap/terang dan aksen amber/lime/biru) |
| Rujukan | [Arah Desain Kekayaanku](https://claude.ai/artifact/H2jYycnUbw2diLu4YUjUui) |

Dokumen ini adalah sumber kebenaran untuk semua kode UI di Tahap 5. Setiap nilai di sini menjadi token di `lib/core/theme/`; tidak ada warna, ukuran, atau jarak yang ditulis langsung di widget (skill `flutter-anti-slop-ui`).

---

## 1. Kepribadian

**Fokus · hangat · terpercaya.**

- **Fokus:** layar dibuka dengan satu angka dan satu grafik. Sisanya mengalah.
- **Hangat:** kantong berwarna dengan emoji pilihan user membuat app terasa milik pribadi, bukan terminal bank.
- **Terpercaya:** ikon garis yang konsisten, angka monospace yang rata, dan sumber setiap harga selalu ditampilkan (mis. "Yahoo · 16:15 WIB"). Rasa profesionalnya mengikuti app seperti tiket.com: rapi, ikon seragam, tanpa dekorasi berlebihan.

Rujukan yang membentuknya: tiga gambar rujukan dari Ilham (kartu hero beraksen, toggle Aset/Utang, donut alokasi, grafik performa dua garis, kartu abu gelap bersudut besar), Robinhood (grafik di depan), Copilot (grafik bisa digeser), Bank Jago (kantong per tujuan), Gojek (bottom sheet untuk menu dan aksi), tiket.com (ikon dan kerapian).

**Yang dihindari:** gradien ungu/biru, glassmorphism, kartu seragam dengan bayangan yang sama di semua tempat, emoji sebagai ikon antarmuka, animasi dekoratif, dan teks generik.

## 2. Warna

Gelap adalah tampilan utama (arah B). Terang dirancang setara, bukan sekadar dibalik. Mode mengikuti sistem, dan bisa dipilih manual di Pengaturan.

### 2.1 Token peran

Nilai di bawah disamakan dengan mockup yang disetujui (netral hangat, bukan biru-abu). Di mode terang, `positive`, `negative`, `warning`, dan aksen Amber digelapkan sedikit di Tahap 4 agar semua teks mencapai kontras 4,5:1 terhadap `bg`, `surface`, dan `surface2`; ini dijaga oleh `test/core/theme/contrast_test.dart`.


| Token | Gelap | Terang | Dipakai untuk |
|---|---|---|---|
| `bg` | `#0D0D0E` | `#F6F5F2` | Latar layar |
| `surface` | `#1A1A1C` | `#FFFFFF` | Daftar, sheet, sidebar |
| `surface2` | `#252528` | `#EFEEEA` | Input, chip aktif, tombol sekunder |
| `fg` | `#F2F2F0` | `#18181A` | Teks utama, angka |
| `muted` | `#8E8E93` | `#66666C` | Label, teks sekunder, garis disetor |
| `line` | `#2B2B2F` | `#E3E1DC` | Pemisah, grid grafik |
| `accent` | Amber `#F0A447` (bawaan) · Lime `#C8F06A` · Biru `#5AA2FF` | Amber `#A0550A` · Lime `#4F7A0F` · Biru `#1F6FD1` | Garis net worth, tombol utama, fokus. **Dipilih user** di Profil → Tampilan (diputuskan Ilham 12 Okt) |
| `onAccent` | Amber `#1D1306` · Lime `#18220A` · Biru `#06162B` | `#FFFFFF` | Teks di atas aksen |
| `accentSoft` | aksen 14% | aksen 10% | Latar ikon peringatan, chip terpilih |
| `positive` | `#5CC38F` | `#17784A` | Naik, untung |
| `negative` | `#EF7A6D` | `#B23B2F` | Turun, rugi, utang |
| `warning` | `#F0B04A` | `#8F5D00` | Harga basi, NAV basi, jatuh tempo |
| `scrim` | hitam 60% | tinta 38% | Latar di belakang bottom sheet |

- Garis pembanding memakai `compare` (`#9AA8FF` gelap / `#4F5FD6` terang); saat aksen Biru dipakai, `compare` berganti ke kuning `#E7C35A` / `#B7791F` agar dua garis tetap mudah dibedakan.
- Aksen hanya untuk **satu** hal per layar yang paling penting (garis net worth, tombol utama). Hijau/merah adalah warna semantik, bukan aksen.
- Kontras teks minimal 4.5:1 terhadap latarnya, dan dicek otomatis di test (golden + kalkulasi kontras token).
- Kontras `muted` di atas `surface2` (mode terang) sudah dicek: 4,9:1.

### 2.2 Warna kantong

Delapan warna, dipilih user per kantong. Dipakai sebagai **tint** (16% di atas `surface`, 24% saat hover, 30% untuk kotak emoji), tidak pernah sebagai warna teks. Angka di dalam kantong tetap `fg`.

| Nama | Hex |
|---|---|
| Langit | `#7FB2FF` |
| Aprikot | `#F6A85C` |
| Lavender | `#B79CFF` |
| Emas | `#E7C35A` |
| Mint | `#5CC9A7` |
| Jambu | `#F28AA6` |
| Laut | `#8FD0E8` |
| Batu | `#A9B4C2` |

### 2.3 Grafik
- Net worth: garis `accent` 2 px + area gradien `accent` 32% → 0%.
- Disetor bersih: garis tangga putus-putus `muted`. Total disetor: putus-putus `positive`. Total ditarik: putus-putus `negative`.
- Pembanding (IHSG dll.): garis `compare` 1,6 px; kantong/portofolio: `accent`.
- Grid: dua garis horizontal `line`, tanpa sumbu Y berlabel di mobile (nilai muncul di tooltip saat digeser). Web menampilkan label sumbu Y.
- Titik akhir selalu ditandai lingkaran 4 px.

## 3. Tipografi

| Peran | Huruf | Catatan |
|---|---|---|
| Teks, judul, dan angka | **Geist** (400, 500, 600, 700) | Satu huruf untuk semua teks (diseragamkan Ilham, 12 Okt). Angka memakai `FontFeature.tabularFigures()` agar kolom rata kanan tetap lurus |

Di-bundle sebagai aset (`assets/fonts/Geist-Variable.ttf`, lisensi OFL, dari repo google/fonts) agar tidak bergantung internet. Tidak memakai paket `google_fonts`.

### Skala

| Token | Ukuran / tinggi baris | Bobot | Dipakai untuk |
|---|---|---|---|
| `display` | 36 / 40 (web 42) | 600, tracking −3% | Net worth di beranda |
| `headline` | 30 / 34 | 600 | Nilai kantong, harga aset |
| `title` | 17 / 22 | 600 | Judul sheet, nama aset |
| `titleSm` | 15 / 20 | 600 | Judul seksi, top bar |
| `body` | 14 / 20 | 400 | Teks umum |
| `bodySm` | 13 / 18 | 400 | Teks sekunder |
| `label` | 12 / 16 | 500 | Label field, chip, meta |
| `numLg` | 17 / 22 tabular | 600 | Nilai di kartu kantong |
| `num` | 14 / 20 tabular | 500 | Angka di daftar |
| `numSm` | 12 / 16 tabular | 500 | Persentase, P/L |

- Format angka `id-ID`: `Rp731.812.400`, persen `+0,44%`, minus memakai tanda minus `−` (U+2212), bukan tanda hubung.
- Ringkasan memakai satuan "jt" atau "M" (miliar) di kartu, dan angka penuh di detail.
- Mendukung text scaling sistem sampai 130% tanpa teks terpotong.

## 4. Jarak, radius, elevasi

- **Jarak** (`AppSpacing`): 4 · 8 · 12 · 16 · 24 · 32 · 48. Gutter layar 16 (mobile), 28 (web).
- **Radius** (`AppRadius`): `sm` 8 (fokus, tag) · `md` 12 (tombol ikon, avatar aset) · `lg` 16 (input, daftar kecil, tombol) · `xl` 20 (kartu kantong) · `sheet` 26 (sudut atas bottom sheet) · `pill` 999 (chip).
- **Elevasi:** hampir datar. Bayangan hanya untuk elemen yang mengambang: bottom sheet, tombol Catat, tooltip grafik. Daftar dan kartu dibedakan dengan warna permukaan, bukan bayangan.
- **Target sentuh:** minimal 48×48 (tombol ikon 44 + area sentuh 48).

## 5. Ikon

- **Lucide** untuk semua ikon antarmuka: satu set garis, stroke 1.75, ukuran 20 (umum), 16 (inline), 22 (aksi di sheet Catat).
- Paket Flutter: `lucide_icons_flutter` (dikunci di `pubspec.lock` saat Tahap 4). Cadangannya `phosphor_flutter` (resmi), dengan ikon dipetakan ulang satu per satu lewat `AppIcons` agar penggantian cukup di satu file.
- Semua ikon diakses lewat `AppIcons.home`, `AppIcons.wallet`, dst.; widget tidak mengimpor paket ikon langsung.
- **Emoji tidak dipakai sebagai ikon antarmuka.** Emoji hanya identitas kantong yang dipilih user (dan pos utang/piutang di beranda).

| Fungsi | Ikon Lucide |
|---|---|
| Menu | `menu` |
| Beranda | `house` |
| Kantong | `wallet` |
| Utang & piutang | `hand-coins` |
| Statistik | `chart-column` |
| Riwayat snapshot | `history` |
| Perlu perhatian | `bell` |
| Pengaturan | `settings` |
| Catat / tambah | `plus` |
| Beli / jual | `circle-plus` / `circle-minus` |
| Setor / tarik | `arrow-down-to-line` / `arrow-up-from-line` |
| Update harga, sumber harga | `refresh-cw` |
| Pindah kantong | `arrow-left-right` |
| Sembunyikan nilai | `eye` / `eye-off` |
| Peringatan | `triangle-alert`, `clock`, `landmark` |

## 6. Emoji kantong dan gambar aset

### 6.1 Emoji kantong
- Setiap kantong punya satu emoji (wajib, default sesuai jenis isi: 📈 saham, 🪙 kripto, 🥇 emas, 🛟 dana darurat) dan satu warna dari 2.2.
- Pemilih emoji: 12 saran yang relevan dengan keuangan, plus kolom cari emoji lengkap.
- Emoji dirender dengan font emoji yang sama di semua platform (**Noto Color Emoji** di-bundle) agar tampilan web, Android, dan iOS konsisten. **[PERLU DIVERIFIKASI]** dampak ukuran bundle web; alternatifnya memakai emoji sistem dan menerima perbedaan gaya antar platform.

### 6.2 Gambar aset
Setiap aset (saham, koin, emas, reksadana, rekening) punya avatar persegi 40 px (56 px di detail) dengan tiga pilihan:

1. **Logo otomatis:** dari sumber logo bila tersedia untuk ticker atau koin tersebut. **[PERLU DIVERIFIKASI]** sumber logo yang gratis dan boleh dipakai (logo emiten IDX dan koin kripto). Jika tidak ada sumber yang aman, opsi ini disembunyikan di MVP.
2. **Unggah gambar:** PNG/JPG maksimal 1 MB, dipotong persegi dan dikecilkan ke 256 px di perangkat sebelum diunggah. Disimpan di Supabase Storage (bucket privat per user, RLS), sehingga perlu tambahan di HLD (lihat 10).
3. **Inisial (default):** kode ticker atau dua huruf nama di atas warna pilihan.

## 7. Navigasi dan tata letak

### 7.1 Mobile (lebar < 600)
Diubah Ilham (12 Okt): **bottom navigation**, menggantikan burger.
- **Empat tab + tombol Tambah di tengah** (v3, 12 Okt): **Beranda · Kantong · [＋ Tambah] · Statistik · Riwayat**. Tab aktif ditandai pil `accentSoft` di belakang ikon dan label tebal. Tombol Tambah berupa lingkaran aksen 50 px yang sedikit menonjol ke atas.
- **Tambah** membuka bottom sheet berisi Transaksi (Beli, Jual, Setor, Tarik), Lainnya (Update harga, Pindah kantong, Utang/piutang, Kantong baru), dan pintasan "Terakhir dipakai". Kartu utama beranda tidak lagi berisi tombol aksi.
- **Foto profil** di kiri atas setiap tab membuka **halaman Profil** tersendiri, berisi grup Keuangan (Utang & piutang, Perlu perhatian, Harga & kurs manual, Preset fee broker, Pembanding) dan Aplikasi (Tampilan, Ekspor CSV, Akun & keamanan, Keluar).
- **Beranda berjudul "Overview"** (v9): kartu net worth, grafik dengan pemilih pembanding (IHSG · BTC · Tidak ada) dan rentang waktu, lalu donut alokasi (per kantong atau jenis aset). Tidak ada ringkasan bulanan dan daftar kantong di beranda.
- **Ikon notifikasi (bel) hanya di Beranda** (v4). Tab lain menampilkan avatar dan judul saja.
- **Tab Kantong** punya pengalih tampilan **daftar / grid** di kanan atas; pilihan diingat per user. Grid 2 kolom di mobile, 3–4 kolom di web.
- **Detail kantong**: kartu atas berisi nilai, porsi dari total, perubahan hari ini, serta Modal · Unrealized · Kas. Di bawahnya grafik vs pembanding, lalu tab **Aset · Transaksi · Info**. Daftar aset punya satu tampilan, **Daftar** (bawaan, mengikuti referensi Ilham 12 Okt) berupa tabel 4 kolom, masing-masing dua baris: *Kode / Lot · Modal / Avg · Nilai pasar / Harga kini · P/L / %*. Harga kini berwarna hijau atau merah dibanding avg. Judul kolom bisa diketuk untuk mengurutkan, ditandai panah hijau. Lencana `!` kuning menandai aset yang perlu perhatian (harga atau NAV basi, suspensi). Satuan menyesuaikan jenis aset: lot, koin, gram (buyback/g), atau unit (NAV). Heatmap dihapus (12 Okt). Tab detail kantong: **Aset · Riwayat P/L · Transaksi · Info**. Riwayat P/L berisi grafik total P/L dengan realized kumulatif, mode per hari, dan rincian per bulan. Kartu kantong (daftar dan grid) menampilkan Modal · Unrealized · Tunai di bawah nilai. Di detail aset, tombol Beli/Jual ada di bawah layar.
- **Buat kantong** (layar penuh): pratinjau kartu kantong di atas yang berubah langsung, lalu Nama (wajib), Emoji (15 saran + papan emoji lengkap), Warna (8 warna kantong), Kas kantong (sakelar, mata uang IDR/USD/USDT, saldo awal sebagai saldo pembuka), dan opsional Preset fee, Pembanding, Catatan. Setelah dibuat, detail kantong menampilkan state kosong dengan tiga langkah: Tambah aset, Pindahkan dari kantong lain, Setor ke kas.
- **Warna kantong** dipakai sebagai gradasi di kartu nilai kantong (detail kantong) dan kartu kantong di tab Kantong (daftar dan grid), sehingga kantong mudah dikenali di mana pun. Gradasi: `color-mix(kantong 46% → 14%)` di atas `surface`, dengan teks label ikut diwarnai tipis. Kontras teks utama tetap ≥ 4,5:1.
- **Tambah aset**: pilih jenis (9 ikon Lucide dalam grid 3 kolom, kantong tujuan sebagai chip di atas), lalu form per jenis. Form valas/tunai punya pilihan mata uang, bentuk (rekening/tunai), jumlah, dan **kotak konversi rupiah** yang langsung berubah (warna `posSoft`), plus kurs beli opsional untuk P/L kurs. Form beli saham menampilkan ringkasan fee, total dari kas, dan avg baru sebelum simpan.
- **Sheet Tambah** hanya berisi dua baris aksi (Transaksi dan Lainnya), tanpa "Terakhir dipakai".
- **Rentang waktu** memakai label bahasa Inggris 1W · 1M · 3M · 6M · YTD · 1Y · All · ikon kalender (Custom), default 1W.
- Form transaksi tetap tampil sebagai bottom sheet (hingga 88% tinggi layar), ditutup dengan geser ke bawah, ketuk scrim, atau tombol tutup.
- Layar turunan (detail kantong, detail aset, komposisi) memakai tombol kembali di kiri atas; bottom navigation tetap tampil di layar tingkat atas.

### 7.2 Tablet (600–1024)
- Sama seperti mobile, tetapi konten dibatasi lebar 640 dan kantong 3 kolom.

### 7.3 Web / lebar (> 1024)
- Kelima tab menjadi **sidebar tetap** 240 px (ikon + label), dengan tombol "Tambah" di bagian atas sidebar dan avatar Profil di bagian bawahnya. Bottom navigation disembunyikan.
- Konten dua kolom: grafik dan ringkasan di kiri (1,5 bagian), kantong dan perhatian di kanan (1 bagian).
- Bottom sheet menjadi **panel samping kanan** 420 px.
- State hover dan fokus keyboard terlihat di semua elemen interaktif. Shortcut: `N` membuka Tambah, `Esc` menutup panel.

## 8. Komponen

| Komponen | Isi dan aturan |
|---|---|
| `NetWorthHero` | Label + tombol sembunyikan nilai, angka `display`, perubahan hari ini (warna semantik) dan konteks ("hari ini"). Saat disembunyikan, semua nilai uang menjadi `Rp ••••••` di seluruh app. |
| `NetWorthChart` | Area + garis tambahan; geser/hover menampilkan tooltip: tanggal, net worth, disetor bersih, hasil. Mendukung resampling mingguan (> 2 tahun). |
| `RangeSelector` | 1M, 1B, 3B, 6B, YTD, 1T, Semua (+ Kustom lewat sheet tanggal). Rentang terakhir diingat. |
| `LineToggles` | Chip: Disetor bersih (default aktif), Total disetor, Total ditarik. |
| `KantongCard` | Kotak emoji bertint, nama, nilai (`numLg`), perubahan hari ini, meta kecil kanan atas ("11 aset"). Kartu lebar penuh untuk kantong terakhir jika jumlahnya ganjil. Kartu "+ Kantong baru" bergaris putus-putus. |
| `DebtReceivableMini` | Dua kartu kecil: piutang (+) dan utang (−, merah). |
| `AttentionList` | Peringatan NAV basi, deposito jatuh tempo, harga basi, snapshot gagal; ikon dengan latar `accentSoft`. |
| `AssetRow` | Avatar aset, nama + meta (lot, avg), nilai + P/L%. |
| `StatGrid` | Grid 2 kolom label/nilai (lot, avg, break-even, unrealized, estimasi bersih jika dijual). |
| `PriceSourceNote` | Ikon `refresh-cw` + "Terisi dari Yahoo · 16:15 WIB · bisa diubah" di bawah setiap input harga. |
| `ReasonChips` | TP / Cut Loss / Lainnya, wajib pada jual. |
| `PLSummary` | Ringkasan realized P/L bersih di form jual: hasil kotor, fee + pajak jual, modal, fee beli terkait, total. |
| `KantongEditor` | Pratinjau langsung, nama, pemilih emoji, pemilih warna. |
| `AssetImagePicker` | Tiga opsi gambar (6.2) dengan pratinjau. |
| `StaleBadge` | Pil kecil `warning` untuk harga/NAV basi. |
| `AppBottomSheet` | Pegangan, judul + tombol tutup, konten bergulir, tombol utama di bawah. Menjadi panel samping di web. |

## 9. State wajib

Setiap layar data punya keempat state ini (bisa dilihat di mockup lewat "State beranda"):

| State | Perilaku |
|---|---|
| **Memuat** | Skeleton berbentuk sama dengan konten (angka besar, grafik, kartu kantong), shimmer 1,2 detik; dimatikan jika user memilih kurangi gerakan. |
| **Kosong** | Pesan spesifik dan satu aksi: "Belum ada kantong. Kantong mengelompokkan aset sesuka Anda…" + "Buat kantong pertama". Net worth tampil Rp0 dengan penjelasan kapan snapshot pertama tercatat. |
| **Error** | Banner yang bisa dipulihkan, yang menyebut apa yang gagal dan akibatnya ("Harga saham gagal diperbarui pukul 17:30. Snapshot hari ini memakai harga pukul 12:00.") + "Coba lagi". Data terakhir tetap tampil. |
| **Sebagian / basi** | `StaleBadge` di aset yang harganya basi; grafik tetap tampil. |
| **Offline** | Banner "Anda sedang offline. Menampilkan data terakhir pukul …"; tombol Catat dinonaktifkan dengan alasan. |

## 10. Dampak ke PRD dan HLD

- **PRD:** kantong = nama tampilan untuk portofolio kustom (6.11), ditambah emoji dan warna per kantong; gambar aset opsional (logo otomatis, unggah, atau inisial); tombol sembunyikan nilai.
- **HLD:** tambah **Supabase Storage** untuk gambar aset (Free plan: 1 GB, unggahan maks 50 MB; gambar dikecilkan ke 256 px ≈ 20–40 KB, jadi ribuan gambar muat). Bucket `asset-images` privat dengan path `user_id/…` dan policy RLS storage. Kolom baru: `portfolios.emoji`, `portfolios.color_key`, `holdings.image_kind` (`initial`/`upload`/`logo`), `holdings.image_path`, `holdings.color_key`.

## 11. Gerak

- Durasi 150–250 ms, kurva `easeOutCubic`.
- Hanya untuk menjelaskan perubahan: sheet naik dari bawah (mobile) atau masuk dari kanan (web), tooltip grafik mengikuti jari, transisi angka saat rentang grafik diganti (crossfade 150 ms).
- Menghormati pengaturan "kurangi gerakan" di sistem.

## 12. Implementasi di Flutter (gambaran untuk Tahap 5)

```
lib/core/theme/
  app_colors.dart      // ThemeExtension<AppColors>: bg, surface, surface2, fg, muted, line, accent, …, kantong[8]
  app_typography.dart  // TextTheme + ThemeExtension<AppNumberStyles> (num, numSm, numLg)
  app_spacing.dart     // AppSpacing.s4 … s48, AppRadius, AppElevation
  app_icons.dart       // pemetaan Lucide
  app_theme.dart       // ThemeData light/dark dari token di atas
lib/shared/widgets/    // komponen di Bagian 8
```

Aturan review: tidak ada `Colors.*`, hex, atau angka jarak langsung di luar `lib/core/theme/`; setiap layar data punya keempat state; dicek di lebar 390 dan 1280, terang dan gelap; `flutter analyze` bersih.

## 13. Keputusan dan asumsi

| Kode | Ringkasan |
|---|---|
| DS-1 | Mobile memakai bottom navigation 4 tab + tombol Tambah di tengah; web memakai sidebar tetap |
| DS-2 | Lucide sebagai set ikon tunggal, diakses lewat `AppIcons` |
| DS-3 | Hanya Geist (angka tabular), di-bundle. Geist Mono dihapus (12 Okt) |
| DS-4 | Emoji hanya untuk identitas kantong; font emoji di-bundle untuk konsistensi |
| DS-5 | Gambar aset: inisial default, unggah ke Supabase Storage, logo otomatis jika sumbernya aman |
| DS-6 | Gelap sebagai tampilan utama, terang setara; default mengikuti sistem |
| DS-7 | Aksen bawaan Amber; user bisa ganti ke Lime atau Biru (disimpan di `profiles`) |
