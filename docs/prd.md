# PRD: Kekayaanku (Personal Net Worth Tracker)

| | |
|---|---|
| Status | **v1.4** (v1.0 disetujui Ilham 12 Oktober 2026; v1.1 menambah hasil review desain). Riwayat perubahan di Bagian 17. |
| Tahap | 1 dari 5 (PRD) |
| Tanggal | 12 Oktober 2026 |
| Platform | Flutter (web + Android + iOS, satu codebase) |
| Dokumen berikutnya | `docs/hld.md` (Tahap 2), `docs/design-system.md` (Tahap 3) |

Konvensi penanda dalam dokumen ini:

- **[ASUMSI A-n]**: keputusan yang saya ambil karena belum ditentukan di spesifikasi. Bisa dibatalkan.
- **[PERLU DIVERIFIKASI]**: aturan atau angka keuangan (pajak, fee, bunga) yang wajib bisa dikonfigurasi dan harus dicek ulang terhadap regulasi atau ketentuan broker/bank yang berlaku. Angka default di dokumen ini hanya titik awal, bukan sumber kebenaran.
- **Q-n**: pertanyaan yang sudah dijawab Ilham (lihat Bagian 14).

---

## 1. Ringkasan

Kekayaanku adalah aplikasi untuk melacak kekayaan bersih (net worth) pribadi lintas jenis aset: emas fisik, kripto, saham Indonesia, reksadana, deposito, tabungan IDR, dan tabungan valas. Sistem mengambil **snapshot otomatis setiap hari pukul 18:00 WIB (11:00 UTC)**, menyimpannya permanen, lalu menampilkan grafik historis net worth dan performa yang dibandingkan dengan satu garis pembanding (mis. IHSG atau BTC) secara adil terhadap setoran/penarikan modal.

Aplikasi dirancang **multi-user sejak awal**: setiap data pengguna terisolasi oleh Row Level Security, sedangkan data harga dan kurs bersifat global.

## 2. Masalah dan tujuan

**Masalah.** Aset tersebar di sekuritas, exchange kripto, bank, dan brankas pribadi. Tidak ada satu tempat yang menunjukkan total kekayaan dalam IDR, bagaimana perkembangannya dari hari ke hari, dan apakah keputusan investasi lebih baik dibanding sekadar memegang indeks atau BTC.

**Tujuan produk (MVP):**

1. G1. Satu angka net worth dalam IDR yang akurat dan bisa ditelusuri ke tiap aset.
2. G2. Riwayat net worth harian yang tidak berubah setelah tercatat (snapshot permanen).
3. G3. Performa yang jujur: dipisahkan dari efek setoran/penarikan modal (metode unit), dan bisa dibandingkan dengan pembanding pilihan.
4. G4. Pencatatan transaksi yang cocok dengan angka sekuritas (avg price tanpa fee) sekaligus menunjukkan realita bersih (break-even, estimasi bersih jika dijual, realized P/L setelah fee).
5. G5. Tetap berfungsi walaupun sumber harga otomatis gagal (fallback input manual di semua titik).

**Indikator keberhasilan (untuk pemakaian pribadi):**

- Snapshot harian tercatat ≥ 99% hari sejak mulai tracking (gagal hanya bila sistem down, dan terlihat jelas di grafik).
- Avg price dan jumlah lot saham sama persis dengan aplikasi sekuritas setelah transaksi dimasukkan.
- Input satu transaksi selesai < 30 detik dengan harga terisi otomatis.
- Biaya operasional Rp0 (tier gratis).

## 3. Non-tujuan (di luar MVP)

- Notifikasi harga TP/Cut Loss (disebut eksplisit di spesifikasi).
- Sinkronisasi otomatis dengan sekuritas, bank, atau exchange (semua transaksi diinput manual).
- Perhitungan dan pelaporan pajak tahunan (SPT).
- Rekomendasi investasi atau sinyal trading.
- Berbagi data antar pengguna (mis. akun keluarga bersama). Struktur multi-user hanya untuk isolasi.
- Jadwal amortisasi otomatis (cicilan KPR/kendaraan dengan bunga efektif/anuitas). Utang di MVP dicatat sebagai saldo sisa (lihat 6.2.8).
- Aksi korporasi saham otomatis (stock split, right issue, bonus). **[ASUMSI A-2]** Dapat ditangani manual lewat transaksi penyesuaian. Dividen dicatat manual (lihat 6.3).
- Mata uang selain IDR dan USD (struktur data sudah siap).
- Aset lain (properti, obligasi/SBN, P2P, kendaraan). Struktur jenis aset harus bisa ditambah.

## 4. Pengguna

**Persona utama: investor ritel Indonesia** yang memegang beberapa jenis aset, aktif di saham (punya lebih dari satu portofolio, mis. "Investing" dan "Trading"), memakai web di laptop dan mobile di ponsel.

**[ASUMSI A-3]** Bahasa antarmuka MVP: Bahasa Indonesia, format angka `id-ID` (titik sebagai pemisah ribuan, koma desimal), zona waktu tampilan WIB. Struktur teks disiapkan untuk lokalisasi.

## 5. Konsep inti dan glosarium

| Istilah | Arti |
|---|---|
| **Aset (holding)** | Satu posisi yang dilacak: mis. "Emas Antam di brankas", "BBCA di portofolio Investing", "Deposito Bank X #1". |
| **Kategori** | Jenis pos (tetap, ditentukan sistem): Emas, Kripto, Saham, Reksadana, Deposito, Tabungan IDR, Tabungan Valas, Piutang (aset), dan Utang (liabilitas). |
| **Net worth** | Total aset (termasuk piutang yang dihitung) dikurangi total utang, dalam IDR. |
| **Portofolio** | Kelompok bebas buatan user yang boleh berisi aset jenis apa pun, mis. "Kripto", "Saham Trading", "Saham Investing", "Dana Darurat". Punya kas sendiri dan preset fee opsional. Lihat 6.11. |
| **Transaksi** | Beli, jual, setor, tarik, penyesuaian, atau opening balance pada suatu aset. |
| **Opening balance** | Posisi awal saat mulai tracking: jumlah, avg price, tanggal mulai. Menggantikan pengetikan ulang riwayat. |
| **Cashflow modal** | Uang yang masuk dari luar sistem (setoran) atau keluar dari sistem (penarikan). Berbeda dari perpindahan internal. |
| **Snapshot** | Catatan permanen kondisi pada satu tanggal pukul 18:00 WIB. |
| **Nilai per unit (NAV unit)** | Nilai kekayaan dibagi jumlah unit internal; dasar perhitungan performa yang netral terhadap cashflow. |
| **Pembanding (benchmark)** | Satu seri harga (IHSG, BTC, USD/IDR, ticker kustom, atau manual) untuk dibandingkan dengan performa. |
| **Provider harga** | Komponen pengambil harga yang bisa diganti (Yahoo Finance utama, manual sebagai fallback). |

## 6. Ruang lingkup fungsional

### 6.1 Akun dan multi-user

- F-AUTH-1. Daftar, masuk, keluar, reset kata sandi. Metode MVP: **email + kata sandi** saja (diputuskan Ilham, 12 Okt). Magic link dan login Google di luar MVP.
- F-AUTH-2. Setiap baris data milik user menyimpan `user_id` dan dilindungi RLS: user hanya bisa membaca/menulis datanya sendiri.
- F-AUTH-3. Data global (harga, kurs, daftar instrumen, seri pembanding preset) dapat dibaca semua user yang login, tetapi hanya ditulis oleh proses sistem.
- F-AUTH-4. **[ASUMSI A-5]** Harga/NAV yang diinput manual oleh user disimpan **per user** (tidak mengubah data global), agar input satu user tidak memengaruhi user lain.
- F-AUTH-5. Pengaturan per user: zona waktu (default WIB), ambang pengingat NAV, preset broker, pembanding default.
- F-AUTH-6. Hapus akun beserta seluruh data (kewajiban privasi dasar).

### 6.2 Jenis aset, piutang, dan utang (MVP)

Ringkasan per kategori:

| Kategori | Satuan jumlah | Sumber harga | Avg price | Valas |
|---|---|---|---|---|
| Emas fisik | keping per merek + pecahan (gram) | Harga **buyback** otomatis harian per merek dan pecahan (Antam, UBS, Galeri24/Pegadaian), bisa ditimpa manual | Ya, per gram | Tidak |
| Kripto (BTC, ETH, SOL, dll.) | jumlah koin (hingga 8 desimal) | Pasar via provider (Yahoo `XXX-IDR` atau `XXX-USD` × kurs) | Ya | Tidak (nilai IDR) |
| Saham Indonesia | lembar (input dalam lot, 1 lot = 100 lembar) | Pasar via provider (ticker `.JK`) | Ya | Tidak |
| Reksadana | unit | NAV input manual + pengingat basi | Ya (NAV rata-rata) | **[ASUMSI A-6]** IDR saja di MVP |
| Deposito | nominal IDR | Dihitung sistem | Tidak | **[ASUMSI A-7]** IDR saja di MVP |
| Tabungan IDR | saldo IDR | Manual | Tidak | Tidak |
| Tabungan valas | saldo mata uang asal (USD) | Kurs mid-market otomatis, bisa ditimpa | Ya (kurs rata-rata) | Ya |
| Piutang (aset) | saldo sisa | Manual | Tidak | Struktur siap |
| Utang (pengurang) | saldo sisa | Manual | Tidak | Struktur siap |

#### 6.2.1 Emas fisik
- Merek MVP (dijawab Ilham, 12 Okt): **Antam**, **UBS**, dan **Galeri24 (emas Pegadaian)**. Daftar merek disimpan sebagai data agar bisa ditambah.
- Field: merek, pecahan (gram per keping, mis. 0,5 / 1 / 2 / 5 / 10 / 25 / 50 / 100), jumlah keping, avg price per gram, tanggal mulai, catatan. Total gram = pecahan × keping.
- Nilai = jumlah keping × harga buyback **per keping** untuk merek dan pecahan tersebut. Harga buyback per gram sedikit berbeda antar pecahan (dicek 12 Okt 2026: Galeri24 1 g Rp2.386.000 vs 10 g Rp2.381.900/g), sehingga nilai per pecahan lebih akurat daripada satu harga per gram.
- Jika pecahan tidak tersedia di sumber (atau harganya Rp0, artinya tidak dibeli kembali), dipakai harga per gram dari pecahan terdekat × total gram, dengan penanda "estimasi".
- F-GOLD-1. **Harga buyback otomatis** lewat provider `GoldBuybackProvider` (implementasi dari abstraksi provider harga, 6.10). Sumber utama: halaman harga emas Galeri24 (anak usaha Pegadaian), yang memuat harga jual dan buyback per pecahan untuk Galeri24, Antam, dan UBS sekaligus. Sumber cadangan yang bisa ditambah: situs Logam Mulia (Antam).
- F-GOLD-2. **Bukan realtime.** Sumber memperbarui harga sekitar sekali sehari (halaman menulis "Diperbarui <tanggal>"). Sistem mengambil harga beberapa kali sehari (mis. 08:30, 12:00, dan 17:30 WIB sebelum snapshot) dan menyimpan tanggal pembaruan dari sumber.
- F-GOLD-3. Harga buyback manual tetap bisa diinput kapan saja (per merek dan pecahan) dan diutamakan untuk tanggal itu (aturan prioritas 6.10).
- F-GOLD-4. Transaksi beli (merek, pecahan, keping, harga per keping atau per gram, biaya opsional) dan jual (keping, harga, biaya, alasan). Form jual terisi otomatis dengan harga buyback terakhir.
- **[ASUMSI A-8]** Sumber berupa halaman web tanpa API resmi, jadi diambil dengan scraping. Ini rapuh (struktur halaman bisa berubah) dan ketentuan penggunaan situs perlu dicek **[PERLU DIVERIFIKASI]**. Jika gagal, harga terakhir dipakai dengan penanda basi, dan user bisa input manual.

#### 6.2.2 Kripto
- Mencakup banyak koin (BTC, ETH, SOL, dll.), karena portofolio kripto user bisa berisi macam-macam koin. BTC tetap menjadi preset pembanding.
- Field: koin (simbol, mis. BTC, ETH, SOL), jumlah (presisi hingga 8 desimal), avg price (IDR per koin), lokasi (mis. exchange/wallet, teks bebas).
- Nilai = jumlah × harga koin dalam IDR.
- **[ASUMSI A-9]** Harga diambil sebagai `XXX-IDR` bila tersedia di provider; jika tidak, `XXX-USD × kurs USD/IDR` hari itu. Metode yang dipakai dicatat di snapshot. Koin yang tidak ada di Yahoo memakai harga manual.
- Fee dan pajak transaksi kripto bisa diisi per transaksi dan ada preset per exchange. **[PERLU DIVERIFIKASI]** tarif PPh/PPN kripto yang berlaku.

#### 6.2.3 Saham Indonesia
- Saham ditempatkan di portofolio kustom (6.11), mis. "Saham Trading" dan "Saham Investing". Satu ticker bisa ada di beberapa portofolio, dihitung terpisah.
- Input dalam **lot**; disimpan dalam lembar (1 lot = 100 lembar). **[ASUMSI A-10]** Saham odd lot (kurang dari 100 lembar, mis. hasil aksi korporasi) didukung lewat input lembar pada transaksi penyesuaian.
- Posisi dihitung dari transaksi beli/jual (plus opening balance), bukan diinput langsung.
- Nilai net worth = harga pasar terakhir × jumlah lembar (aturan yang sudah diputuskan).
- Halaman posisi menampilkan: lot, avg price, harga terakhir, nilai pasar, unrealized P/L (kotor), **harga break-even**, dan **estimasi bersih jika dijual hari ini**.

#### 6.2.4 Reksadana
- Field: nama produk, manajer investasi/platform (teks), jumlah unit, avg NAV, NAV terakhir + tanggal NAV.
- Nilai = unit × NAV terakhir.
- Transaksi: beli (nominal, NAV, unit; dua dari tiga mengisi yang ketiga), jual/redeem (unit atau nominal, NAV, biaya, alasan).
- F-MF-1. Pengingat NAV basi: jika tanggal NAV terakhir lebih lama dari ambang (default **7 hari**, bisa diatur per user dan per produk), tampil penanda di daftar aset dan banner di dashboard. **[ASUMSI A-11]** MVP: pengingat di dalam aplikasi saja, bukan push/email.

#### 6.2.5 Deposito
- Field: bank, pokok, bunga % p.a., tanggal mulai, tenor (bulan), ARO (tidak / ARO pokok saja, bunga dicairkan / ARO pokok + bunga, dipilih per deposito), opsi "bunga bersih setelah pajak" (ya/tidak), tarif pajak bunga (default 20%, **[PERLU DIVERIFIKASI]**), basis hari (default actual/365, **[PERLU DIVERIFIKASI]**, berbeda antar bank).
- Nilai dihitung sistem setiap hari (lihat Bagian 7.6).
- Saat jatuh tempo tanpa ARO: deposito berstatus "Jatuh tempo", nilai tetap pokok + bunga terakhir sampai user mencatat pencairan (ke tabungan atau penarikan).
- Saat jatuh tempo dengan ARO: periode baru dimulai otomatis dengan suku bunga yang sama (bisa diubah user).

#### 6.2.6 Uang rupiah (tabungan atau tunai)
- Field: nama, bentuk (**rekening** atau **tunai**), saldo. Bentuk hanya label; cara hitungnya sama.
- Cara update: **[ASUMSI A-12]** dua cara, (a) "set saldo" langsung (paling cepat untuk pemakaian sehari-hari), dan (b) catat setor/tarik. **[ASUMSI A-38]** Saat "set saldo", selisihnya dianggap cashflow modal (kenaikan = setoran, mis. gaji; penurunan = penarikan, mis. belanja), kecuali user menandainya sebagai bunga/hasil (masuk performa). Lihat 7.7.

#### 6.2.7 Tabungan valas
- Bentuk: **rekening** atau **tunai** (label saja). Mata uang MVP (diperluas Ilham 12 Okt): USD, SGD, JPY, EUR, AUD, MYR, SAR, ditambah mata uang lain lewat "+ Lainnya". **[PERLU DIVERIFIKASI]** Ketersediaan kurs harian setiap pasangan di Yahoo (mis. `JPYIDR=X`); jika tidak ada, kurs diturunkan lewat USD (`JPY→USD→IDR`) atau diisi manual.
- Form tambah menampilkan **nilai rupiah secara langsung** (jumlah × kurs hari itu) sebelum disimpan, beserta sumber dan waktu kurs.
- Saldo disimpan dalam mata uang asal. Setor/tarik dicatat dalam mata uang asal beserta kurs saat transaksi (untuk avg kurs).
- Nilai IDR = saldo × kurs mid-market mata uang tersebut terhadap IDR hari itu (otomatis dari provider, bisa ditimpa manual per user per tanggal).
- Avg kurs = rata-rata tertimbang kurs pembelian valas (lihat 7.1).

#### 6.2.8 Utang (liabilitas, pengurang net worth)
- Field: nama (mis. "KPR Bank X", "Kartu kredit Y", "Pinjaman ke Budi"), jenis (KPR, kendaraan, kartu kredit, paylater, pinjaman pribadi, lainnya), mata uang (IDR; USD siap struktur), saldo sisa, tanggal mulai, catatan. Opsional: bunga % p.a., cicilan per bulan, tanggal jatuh tempo bulanan, tenor/tanggal lunas (untuk informasi dan pengingat, bukan perhitungan otomatis).
- Nilai net worth = **− saldo sisa** (dalam IDR; utang valas dikonversi dengan kurs hari itu).
- Transaksi:
  - **Terima pinjaman**: saldo utang naik. Jika uangnya masuk ke aset yang dilacak (mis. tabungan), dicatat bersamaan sebagai perpindahan internal (net worth tidak berubah).
  - **Bayar**: saldo utang turun sebesar porsi pokok; porsi bunga/biaya dicatat terpisah sebagai **beban** (mengurangi net worth, bukan cashflow modal). Sumber pembayaran bisa aset yang dilacak (internal) atau dari luar sistem.
  - **Set saldo**: menyamakan saldo sisa dengan tagihan/statement (paling praktis untuk kartu kredit).
  - **Pinjaman bertambah** (mis. pemakaian kartu kredit untuk belanja): saldo naik; net worth turun.
- **[ASUMSI A-34]** MVP tidak menghitung bunga utang otomatis; saldo sisa diperbarui user (bayar atau set saldo). Bunga otomatis/amortisasi di luar MVP.
- F-DEBT-1. Pengingat jatuh tempo cicilan (di dalam aplikasi) bila tanggal jatuh tempo bulanan diisi.

#### 6.2.9 Piutang (aset, penambah net worth)
- Field: nama peminjam/pihak, mata uang (IDR; USD siap struktur), saldo sisa, tanggal mulai, perkiraan tanggal kembali (opsional), status, catatan.
- Status: **Lancar**, **Diragukan**, **Dihapus (write-off)**.
- **[ASUMSI A-35]** Setiap piutang punya opsi "hitung dalam net worth" (default ya) dan persentase yang dihitung (default 100%). Piutang berstatus Diragukan otomatis menyarankan untuk tidak dihitung, tetapi keputusan tetap di user. Status Dihapus = nilai 0 dan dicatat sebagai kerugian.
- Nilai net worth = saldo sisa × persentase dihitung (IDR, valas dikonversi kurs hari itu).
- Transaksi:
  - **Beri pinjaman**: piutang naik. Jika uangnya dari aset yang dilacak, ini perpindahan internal (net worth tetap).
  - **Terima pembayaran**: piutang turun. Uang masuk ke aset yang dilacak (internal) atau ke luar sistem.
  - **Bunga/imbalan diterima** (opsional): pendapatan, menambah net worth.
  - **Hapus (write-off)**: saldo sisa jadi 0, dicatat sebagai kerugian (bukan penarikan modal).

### 6.3 Transaksi

- F-TX-1. Jenis transaksi: Opening balance, Beli, Jual, Setor, Tarik, Penyesuaian (koreksi jumlah tanpa harga, mis. aksi korporasi), Dividen (nominal bersih, manual; menambah kas portofolio sebagai hasil investasi, bukan cashflow modal), dan Pindah antar portofolio (6.11).
- F-TX-2. Setiap transaksi: tanggal, aset, jumlah, harga per satuan (jika relevan), fee beli/jual, pajak, catatan.
- F-TX-3. **Jual** wajib memilih alasan: `TP`, `Cut Loss`, atau `Lainnya`. User mengisi harga jual dan fee (terisi otomatis dari preset broker, bisa diedit). Sistem menghitung realized P/L bersih.
- F-TX-4. Jual tidak boleh melebihi jumlah yang dimiliki pada tanggal transaksi (validasi).
- F-TX-5. Transaksi bisa diedit/dihapus. Avg price, posisi, dan realized P/L dihitung ulang dari seluruh riwayat transaksi aset tersebut. **Snapshot masa lalu tidak ikut berubah** (lihat 6.6).
- F-TX-6. **[ASUMSI A-13]** Transaksi dengan tanggal mundur (backdate) diperbolehkan untuk koreksi, tetapi tidak sebelum tanggal opening balance aset tersebut.
- F-TX-7. Form harga: saat dibuka, harga terisi otomatis dari sumber terakhir (harga provider terbaru atau input manual terakhir), dengan label sumber dan waktu, dan bisa ditimpa.

### 6.4 Opening balance
- F-OB-1. Saat menambah aset yang sudah dimiliki: isi jumlah, avg price (atau avg kurs/NAV), dan tanggal mulai tracking.
- F-OB-2. Opening balance diperlakukan sebagai lot pembelian awal untuk avg price.
- F-OB-3. **[ASUMSI A-14]** Opening balance **tidak** dihitung sebagai setoran modal di riwayat, melainkan sebagai modal awal: nilai pasar seluruh opening balance pada tanggal mulai menjadi titik awal unit (nilai per unit awal). Ini membuat performa dihitung sejak mulai tracking, bukan sejak pembelian asli. Disetujui (Q-6).

### 6.5 Preset fee broker
- F-FEE-1. User membuat preset per broker/exchange: fee beli (%), fee jual (%), pajak jual (%), biaya minimum (opsional), pembulatan (opsional).
- F-FEE-2. Preset dipasang ke portofolio (opsional) dan bisa ditimpa per aset; nilainya mengisi otomatis form transaksi dan bisa diubah per transaksi.
- F-FEE-3. Sistem menyediakan template awal yang bisa diedit, semuanya bertanda **[PERLU DIVERIFIKASI]**:
  - Saham IDX: fee beli ±0,15%, fee jual ±0,25% (termasuk PPh final penjualan saham 0,1%). Angka tiap broker berbeda, termasuk pungutan bursa/KPEI/PPN.
  - Kripto: fee exchange dan PPh/PPN kripto sesuai ketentuan terbaru.
  - Reksadana: biaya subscription/redemption (umumnya 0% di platform online, tergantung produk).
- F-FEE-4. Fee dan pajak yang tersimpan di transaksi adalah angka yang dipakai saat itu; mengubah preset tidak mengubah transaksi lama.

### 6.6 Snapshot harian
- F-SNAP-1. Job terjadwal setiap hari **18:00 WIB (11:00 UTC)** menghitung, untuk setiap user aktif:
  - nilai per kategori dan **per portofolio** (IDR), total aset, total utang, total net worth, total dana disetor bersih kumulatif,
  - jumlah unit dan nilai per unit,
  - kurs yang dipakai (mis. USD/IDR) dan harga per instrumen yang dipakai beserta sumber dan tanggal harganya,
  - **[ASUMSI A-15]** rincian nilai per aset (untuk drill-down grafik per kategori/aset). Bisa dikurangi jika batas penyimpanan tier gratis ketat (diputuskan di HLD).
- F-SNAP-2. Snapshot **permanen**: grafik membaca snapshot, tidak menghitung ulang masa lalu. Mengedit transaksi lama tidak mengubah snapshot lama.
- F-SNAP-3. Harga untuk snapshot = harga terakhir yang tersedia saat job berjalan. Di hari bursa libur atau provider gagal, dipakai harga terakhir yang diketahui, dan snapshot mencatat tanggal harga tersebut (penanda "harga basi").
- F-SNAP-4. Idempoten: satu snapshot per user per tanggal. **[ASUMSI A-16]** Jika job gagal, dicoba ulang otomatis sampai 23:59 WIB hari yang sama. Jika tetap gagal, tanggal itu kosong dan grafik menampilkan celah (tidak diisi rekaan).
- F-SNAP-5. **[ASUMSI A-17]** Tidak ada snapshot untuk tanggal sebelum user mulai tracking. Opening balance bertanggal mundur tidak membuat snapshot historis.
- F-SNAP-6. **[ASUMSI A-18]** Tidak ada tombol "snapshot sekarang" di MVP, agar semua snapshot konsisten pada pukul 18:00. Dashboard tetap menampilkan nilai "live" saat ini yang dihitung on-the-fly dan dibedakan dari snapshot.

### 6.7 Dashboard
- F-DASH-1. Kartu utama: net worth saat ini (live) dengan rincian **total aset − total utang**, perubahan vs snapshot kemarin (IDR dan %), total dana disetor bersih, selisih net worth terhadap dana disetor.
- F-DASH-2. Grafik net worth historis dari snapshot. Rentang waktu (disepakati 12 Okt):
  - Pilihan (label bahasa Inggris, diubah Ilham 12 Okt): **1W, 1M, 3M, 6M, YTD, 1Y, All, Custom** (rentang tanggal bebas lewat kalender).
  - Default **1W**; jika riwayat user kurang dari 1 minggu, default "All". Rentang terakhir yang dipilih diingat per user.
  - Rentang yang lebih panjang dari riwayat tetap bisa dipilih; grafik dimulai dari tanggal snapshot pertama, tanpa data rekaan.
  - Resolusi titik: harian sampai rentang 2 tahun; di atas 2 tahun ditampilkan mingguan (nilai snapshot terakhir tiap minggu). Data harian tetap tersimpan utuh.
  - Grafik performa vs pembanding (F-DASH-4) memakai rentang yang sama dan di-rebase pada awal rentang.
  - Opsi tampilan: total, bertumpuk per kategori, atau bertumpuk per portofolio.
- F-DASH-3. Grafik net worth di home dashboard menggabungkan nilai semua aset, piutang, dan utang per hari (dari snapshot), dengan toggle garis tambahan (permintaan Ilham, 12 Okt):
  - **Dana disetor bersih** (kumulatif setoran − penarikan), aktif secara default.
  - **Total disetor** (kumulatif setoran saja) dan **total ditarik** (kumulatif penarikan saja), nonaktif secara default.
  - Pilihan toggle diingat per user. Tooltip pada satu tanggal menampilkan net worth, dana disetor bersih, dan selisihnya (hasil investasi).
  - Penanda kecil di sumbu waktu untuk hari yang ada setoran/penarikan besar. **[ASUMSI A-40]** "Besar" = di atas ambang yang bisa diatur, default Rp1.000.000.
- F-DASH-4. Grafik performa: nilai per unit di-rebase ke 100 (atau % return) pada awal rentang, bersama garis pembanding yang juga di-rebase. Di beranda (berjudul **Overview**) pembanding dipilih langsung di atas grafik: IHSG, BTC, atau tidak ada (permintaan Ilham 12 Okt). Beranda tidak menampilkan daftar kantong maupun ringkasan bulanan.
- F-DASH-5. Alokasi berupa **diagram lingkaran** (donut) dengan pilihan per kantong (bawaan) atau per kategori aset, ditambah rasio utang terhadap aset. Utang ditampilkan terpisah, tidak dicampur ke diagram alokasi aset.
- F-DASH-6. Peringatan: NAV basi, harga yang sedang memakai fallback/basi, deposito jatuh tempo dalam 7 hari, snapshot yang gagal.
- F-DASH-7. Semua state wajib: loading, kosong (user baru, belum ada snapshot), error (provider gagal), dan sebagian (sebagian harga basi).

### 6.8 Garis pembanding
- F-BM-1. User memilih **satu** pembanding aktif dan bisa menggantinya kapan saja.
- F-BM-2. Sumber: preset (IHSG `^JKSE`, BTC, USD/IDR, buyback emas Antam, LQ45 jika tersedia), ticker Yahoo kustom, atau seri manual (input nilai per tanggal).
- F-BM-3. Harga pembanding diambil harian dan disimpan global (untuk preset dan ticker kustom) atau per user (manual).
- F-BM-4. **[ASUMSI A-19]** Saat user menambah ticker kustom, sistem mengambil riwayat harga ke belakang sejauh rentang snapshot user (data pembanding boleh di-backfill karena itu data pasar, bukan snapshot user).
- F-BM-5. Mode tampilan: rebase 100 pada awal rentang terpilih, atau % return kumulatif.
- F-BM-6. **[ASUMSI A-20]** Pembanding berdenominasi asing (mis. BTC-USD) dibandingkan dalam IDR secara default (dikonversi dengan kurs hari itu), dengan opsi tampil dalam mata uang asal.

### 6.9 Statistik realized P/L
- F-STAT-1. Per portofolio dan per periode (bulan, kuartal, tahun, kustom): total realized P/L bersih, jumlah transaksi jual, **win rate** (persentase jual dengan P/L bersih > 0), rata-rata untung (transaksi menang), rata-rata rugi (transaksi kalah), rasio rata-rata untung/rugi.
- F-STAT-2. Filter berdasarkan alasan (TP, Cut Loss, Lainnya).
- F-STAT-5. Rentang waktu memakai pilihan yang sama dengan grafik (1W, 1M, 3M, YTD, 1Y, All) plus **Custom** (tanggal awal dan akhir bebas).
- F-STAT-6. **Unrealized P/L** ditampilkan di samping realized, dan keduanya dijumlah menjadi total P/L rentang. **[ASUMSI A-41]** Unrealized = nilai pasar dikurangi modal (avg × jumlah) untuk posisi yang masih dipegang pada akhir rentang, diambil dari snapshot hari itu (atau nilai live jika akhir rentang = hari ini). Ini bukan perubahan unrealized selama rentang.
- F-STAT-7. Daftar **aset yang dipegang di rentang itu**: setiap aset yang punya posisi di hari mana pun di antara tanggal awal dan akhir, termasuk yang dibeli atau dijual di tengah rentang. Per aset ditampilkan kantong, lama dipegang di dalam rentang, dan P/L-nya (unrealized jika masih dipegang di akhir rentang, realized jika sudah terjual).
- F-STAT-3. **[ASUMSI A-21]** Statistik berlaku untuk semua aset yang punya avg price (saham, kripto, emas, reksadana, valas), dengan saham sebagai fokus tampilan utama.
- F-STAT-4. **[ASUMSI A-22]** P/L bernilai tepat 0 dihitung bukan menang bukan kalah (dikeluarkan dari pembagi win rate). Lihat aturan di 7.3.

### 6.10 Sumber harga dan kurs
- F-PRICE-1. Semua pengambilan harga melewati antarmuka provider (mis. `PriceProvider.getQuote(symbol)`, `getHistory(symbol, from, to)`), agar Yahoo Finance bisa diganti tanpa mengubah logika lain.
- F-PRICE-2. Yahoo Finance adalah provider utama untuk saham `.JK`, `^JKSE`, kripto, dan USD/IDR (`IDR=X` atau `USDIDR=X`, ditentukan di HLD). Karena Yahoo tidak resmi, kegagalan harus ditangani dengan aman: harga terakhir tetap dipakai, ditandai basi, dan user bisa input manual.
- F-PRICE-3. Pengambilan harga terjadwal sebelum snapshot (mis. 17:30 WIB) dan bisa juga saat user membuka aplikasi (dengan batas frekuensi untuk menghormati tier gratis dan provider).
- F-PRICE-4. Prioritas harga untuk satu user dan satu tanggal: input manual user untuk tanggal itu > harga provider global > harga terakhir yang diketahui (basi).
- F-PRICE-5. Setiap harga menyimpan: simbol, tanggal, nilai, mata uang, sumber, waktu pengambilan.

### 6.11 Portofolio kustom (lintas jenis aset)

Permintaan Ilham (12 Okt): portofolio adalah pengelompokan bebas buatan user, tidak terikat jenis aset. Contoh: "Kripto" (BTC, ETH, SOL), "Saham Trading", "Saham Investing", "Dana Darurat" (tabungan + deposito), "Emas".

- F-PF-1. User membuat, mengganti nama, mengurutkan, mengarsipkan, dan menghapus portofolio (hapus hanya jika kosong). Field: nama, warna/ikon dari token design system, deskripsi opsional, preset fee opsional.
- F-PF-2. **[ASUMSI A-39]** Setiap aset, piutang, dan utang masuk ke **tepat satu** portofolio, agar total semua portofolio = net worth (tidak dobel hitung). User baru mendapat satu portofolio bawaan "Utama" yang bisa diganti nama.
- F-PF-3. Satu portofolio boleh berisi campuran jenis aset. Kategori (jenis aset) tetap ada dan ditentukan sistem karena menentukan cara hitung; portofolio adalah sumbu pengelompokan kedua.
- F-PF-4. **Kas portofolio**: setiap portofolio punya saldo kas opsional yang **selalu dalam rupiah** (diputuskan Ilham 12 Okt), mis. RDN untuk saham atau saldo IDR di exchange kripto. Uang dalam mata uang asing dicatat sebagai aset Valas (6.2.7); saldo stablecoin seperti USDT dicatat sebagai aset Kripto. Beli mengurangi kas, jual dan dividen menambah kas. Setor/tarik ke kas portofolio dari luar sistem = cashflow modal. Kas boleh dinonaktifkan untuk portofolio yang tidak membutuhkannya (mis. emas fisik).
- F-PF-5. Pindah aset antar portofolio (seluruh atau sebagian jumlah) mempertahankan avg price dan tanggal; bagi kedua portofolio ini dicatat sebagai transfer internal yang mengubah unit masing-masing tetapi tidak mengubah dana disetor bersih total.
- F-PF-6. Tampilan: daftar aset bisa dikelompokkan **per portofolio** (default) atau **per kategori**. Dashboard punya alokasi per portofolio dan per kategori.
- F-PF-7. Per portofolio tersedia: total nilai, unrealized dan realized P/L, dana disetor bersih, **performa unit** sendiri (7.8), dan perbandingan dengan pembanding.
- F-PF-8. Statistik realized (6.9) difilter per portofolio.
- F-PF-9. Kartu setiap kantong menampilkan **Modal, Unrealized, dan Tunai** (kas rupiah kantong; "—" jika kas dimatikan) di bawah nilai dan perubahan hari ini (diminta Ilham 12 Okt).
- F-PF-10. **Riwayat P/L** per kantong dan total: grafik total P/L (unrealized + realized kumulatif) dan realized kumulatif per hari dari snapshot, mode perubahan P/L harian, dan rincian per bulan. Setoran/penarikan tidak memengaruhi P/L. Riwayat hanya tersedia sejak tanggal mulai tracking.

## 7. Aturan perhitungan

Semua logika di bagian ini wajib punya unit test (Tahap 5). Contoh angka di bawah akan dijadikan kasus uji.

### 7.1 Avg price (rata-rata tertimbang, tanpa fee)

Berlaku untuk saham, emas (per gram), kripto, reksadana (NAV), valas (kurs). Tidak berlaku untuk tabungan IDR dan deposito.

```
Beli:  avg_baru = (qty_lama × avg_lama + qty_beli × harga_beli) / (qty_lama + qty_beli)
Jual:  avg tidak berubah; qty berkurang
Habis: jika qty menjadi 0, avg direset; pembelian berikutnya memulai avg baru
```

- Fee **tidak** masuk avg, agar sama dengan angka sekuritas.
- Opening balance = satu pembelian dengan `harga_beli = avg yang diinput`.
- Contoh: beli 10 lot @1.000, beli 10 lot @1.200 → avg 1.100. Jual 5 lot → avg tetap 1.100, sisa 15 lot.
- **[ASUMSI A-23]** Presisi: avg saham disimpan dengan desimal penuh, ditampilkan dibulatkan ke 2 desimal. Perhitungan uang memakai tipe desimal (bukan floating point).

### 7.2 Harga break-even

Harga jual per satuan yang membuat P/L bersih = 0, memperhitungkan fee beli (yang sudah dibayar) dan fee + pajak jual (yang akan dibayar):

```
total_biaya_beli = Σ (nilai_beli × fee_beli%)   untuk lot yang masih dipegang (proporsional)
break_even = (qty × avg + total_biaya_beli) / (qty × (1 − fee_jual% − pajak_jual%))
```

- **[ASUMSI A-24]** Fee beli untuk lot yang sudah sebagian terjual dialokasikan proporsional (fee beli rata-rata per satuan × qty sisa). Untuk opening balance, fee beli historis tidak diketahui, sehingga diestimasi dengan fee beli preset portofolio saat ini dan diberi label "estimasi".

### 7.3 Realized P/L bersih (per transaksi jual)

```
hasil_jual_bersih = qty_jual × harga_jual − fee_jual − pajak_jual
modal_terjual     = qty_jual × avg
fee_beli_terkait  = fee_beli_rata2_per_satuan × qty_jual
realized_PL       = hasil_jual_bersih − modal_terjual − fee_beli_terkait
```

- Spesifikasi menulis "jual − avg beli − fee". **[ASUMSI A-25, disetujui]** "Fee" diartikan sebagai fee jual + pajak jual **ditambah** porsi fee beli dari lot yang dijual, supaya realized P/L benar-benar bersih dan konsisten dengan harga break-even. Jika maksudnya hanya fee jual, rumus disederhanakan. Disetujui (Q-7).
- `realized_PL > 0` = menang, `< 0` = kalah, `= 0` = netral.
- Disimpan pada transaksi jual saat dicatat, dan dihitung ulang jika transaksi sebelumnya di aset yang sama diedit.

### 7.4 Estimasi bersih jika dijual hari ini

```
estimasi_bersih = qty × harga_terakhir × (1 − fee_jual% − pajak_jual%)
estimasi_PL     = estimasi_bersih − qty × avg − fee_beli_terkait
```

Hanya informasi di halaman posisi; **tidak** dipakai untuk net worth (net worth tetap harga pasar × jumlah).

### 7.5 Unrealized P/L

```
unrealized_PL_kotor = qty × (harga_terakhir − avg)
unrealized_% = harga_terakhir / avg − 1
```

### 7.6 Deposito

Semua parameter configurable dan **[PERLU DIVERIFIKASI]**: tarif pajak, basis hari, cara bank membulatkan, ambang bebas pajak.

```
bunga_kotor_harian = pokok × bunga_pa / basis_hari         (basis_hari default 365)
bunga_akrual(t)    = bunga_kotor_harian × hari_berjalan(t)   (hari_berjalan ≤ hari tenor)
pajak              = bunga_akrual × tarif_pajak             (default 20%)  jika opsi bunga bersih aktif
nilai(t)           = pokok + bunga_akrual(t) − pajak
```

- **[ASUMSI A-26]** Nilai net worth deposito memakai **bunga akrual harian** (nilai naik pelan setiap hari), bukan menunggu jatuh tempo. Alternatif: nilai = pokok sampai jatuh tempo. Akrual lebih jujur untuk grafik.
- Tenor dalam bulan; tanggal jatuh tempo = tanggal mulai + n bulan (jika tanggal tidak ada di bulan tujuan, pakai hari terakhir bulan). **[PERLU DIVERIFIKASI]** terhadap praktik bank.
- **[PERLU DIVERIFIKASI]** Pajak bunga deposito di Indonesia umumnya 20% dan ada ketentuan pengecualian untuk saldo kecil; MVP menyediakan kolom "dikenai pajak ya/tidak" + tarif, tanpa logika ambang otomatis.
- ARO: mode dipilih per deposito (Q-3). "Pokok saja": bunga periode dicairkan ke aset tujuan (internal, bukan cashflow modal). "Pokok + bunga": pokok periode baru = pokok lama + bunga bersih.

### 7.7 Cashflow modal dan dana disetor bersih

```
dana_disetor_bersih(t) = modal_awal + Σ setoran(≤ t) − Σ penarikan(≤ t)
```

- **Setoran** = uang dari luar sistem masuk ke aset yang dilacak (mis. gaji ditabung, transfer ke RDN). **Penarikan** = uang keluar dari sistem (mis. dipakai belanja).
- Perpindahan internal (jual saham lalu uangnya ke tabungan yang juga dilacak, beli emas dari tabungan yang dilacak) **bukan** cashflow modal.
- **[ASUMSI A-27]** Agar cashflow tercatat benar tanpa harus mencatat dua sisi setiap perpindahan, user mencatat cashflow secara eksplisit sebagai entri "Setor modal" / "Tarik modal" yang ditautkan ke aset tujuan/asal. Transaksi beli/jual aset tidak otomatis dianggap cashflow. Dengan kas portofolio (6.11), beli/jual mengubah kas, dan cashflow modal hanya terjadi saat uang masuk/keluar sistem.
- Setoran valas dicatat dalam mata uang asal dan dikonversi ke IDR dengan kurs hari transaksi untuk dana disetor bersih.

### 7.8 Performa berbasis unit

Mirip cara reksadana menghitung NAV per unit, sehingga setoran/penarikan tidak terlihat sebagai untung/rugi.

```
Hari pertama tracking:  nilai_per_unit = 1.000 (konstanta; tampilan selalu di-rebase)
                        unit = net_worth_awal / 1.000
Setiap snapshot hari t:
  nav_pra_flow = net_worth(t) − cashflow_bersih(t)   ; nilai sebelum cashflow hari itu
  nilai_per_unit(t) = nav_pra_flow / unit(t−1)
  unit(t) = unit(t−1) + cashflow_bersih(t) / nilai_per_unit(t)
Return periode [a, b] = nilai_per_unit(b) / nilai_per_unit(a) − 1
```

- **[ASUMSI A-28]** Cashflow pada tanggal t dianggap terjadi tepat sebelum snapshot 18:00 hari itu, dan diproses dengan nilai per unit yang dihitung dari net worth hari itu dikurangi cashflow tersebut. Cashflow setelah 18:00 dengan tanggal yang sama tetap masuk ke hari itu (unit dihitung ulang untuk snapshot berikutnya bila snapshot hari itu sudah tercatat, lihat 7.9).
- Edge case: net worth bisa ≤ 0 karena utang. **[ASUMSI A-36]** Jika net worth awal ≤ 0, seri performa unit belum dimulai sampai net worth positif; jika di tengah jalan nilai per unit menyentuh ≤ 0, seri performa ditandai "tidak terdefinisi" untuk periode itu dan grafik net worth (IDR) tetap tampil normal. Alternatif yang akan dievaluasi di HLD: menghitung performa unit hanya dari sisi aset investasi (tanpa utang/piutang/tabungan).
- Edge case: jika `unit` menjadi 0 (semua ditarik), seri performa berhenti; setoran berikutnya memulai unit baru dengan nilai per unit terakhir (tidak reset ke 1.000), agar grafik tetap menyambung.
- **[ASUMSI A-29]** Performa unit dihitung di level **total net worth** dan **per portofolio kustom**. Cashflow portofolio = setor/tarik ke portofolio itu dari luar sistem, ditambah transfer masuk/keluar antar portofolio (dinilai dengan harga pasar hari itu). Per kategori tidak di MVP.

### 7.9 Cashflow yang dicatat terlambat

Karena snapshot permanen, setoran yang dicatat dengan tanggal mundur tidak mengubah snapshot lama. **[ASUMSI A-30]** Setoran tersebut masuk ke `cashflow_bersih` snapshot **berikutnya** (bukan tanggal aslinya) agar seri unit tetap konsisten, dan diberi catatan di riwayat. Dana disetor bersih pada tampilan riwayat memakai tanggal asli.

### 7.10 Utang, piutang, dan cashflow modal

```
net_worth(t) = Σ nilai_aset(t) + Σ nilai_piutang_dihitung(t) − Σ saldo_utang(t)
```

| Kejadian | Net worth | Cashflow modal? |
|---|---|---|
| Ambil pinjaman, uang masuk tabungan yang dilacak | tetap | Tidak (internal) |
| Bayar pokok utang dari tabungan yang dilacak | tetap | Tidak (internal) |
| Bayar bunga/biaya utang | turun | Tidak; tercatat sebagai beban (mengurangi performa) |
| Bayar utang dengan uang dari luar sistem (gaji langsung) | naik | **Ya, setoran** |
| Belanja pakai kartu kredit / paylater | turun | **[ASUMSI A-37]** Ya, **penarikan** (konsumsi), agar performa investasi tidak terlihat rugi karena belanja |
| Pinjamkan uang dari tabungan yang dilacak | tetap | Tidak (internal) |
| Piutang dibayar kembali ke tabungan yang dilacak | tetap | Tidak (internal) |
| Piutang dihapus | turun | Tidak; tercatat sebagai kerugian |

- Snapshot menyimpan total aset, total piutang dihitung, total utang, dan net worth secara terpisah.
- Utang dan piutang **tidak** punya avg price dan tidak masuk statistik win rate.

### 7.11 Konversi mata uang
- Nilai IDR aset valas = jumlah × kurs mid-market hari itu (override manual user diutamakan).
- Kurs yang dipakai disimpan di snapshot.
- Avg kurs valas mengikuti 7.1 dengan harga = kurs saat membeli/menyetor valas.
- Realized P/L valas (selisih kurs) dihitung saat valas ditarik/dijual ke IDR, mengikuti 7.3.

## 8. Daftar layar utama (untuk wireframe di Tahap 3)

1. Masuk / daftar / lupa kata sandi.
2. Onboarding: buat portofolio (atau pakai "Utama"), input opening balance cepat per aset, utang, dan piutang, pilih pembanding default.
3. **Dashboard**: kartu net worth, grafik net worth + dana disetor, grafik performa vs pembanding, alokasi per portofolio dan per kategori, peringatan.
4. **Daftar aset** dikelompokkan per portofolio (default) atau per kategori, dengan total dan penanda harga basi/NAV basi.
5. **Detail aset / posisi**: ringkasan, avg, break-even, estimasi bersih jika dijual, riwayat transaksi, grafik nilai aset dari snapshot.
6. **Portofolio**: daftar portofolio kustom; detail berisi posisi campuran, kas, total, realized P/L, performa unit vs pembanding; kelola (buat, ubah, arsip).
7. **Form transaksi** (satu form adaptif per kategori): beli, jual (dengan alasan), setor, tarik, penyesuaian, opening balance.
8. **Statistik realized**: filter portofolio, periode, alasan; win rate, rata-rata untung/rugi.
9. **Utang & piutang**: daftar dengan saldo sisa, status piutang, jatuh tempo cicilan, dan form transaksinya.
10. **Riwayat snapshot**: tabel per tanggal, bisa dibuka rinciannya.
11. **Pengaturan**: preset broker/fee, pembanding, ambang NAV, input harga/kurs manual, profil, hapus akun.

Kebutuhan UI (dirinci di design system): pakai design token tanpa warna/ukuran hardcode, state loading/empty/error di semua layar data, responsif (mobile 1 kolom, web multi-kolom), aksesibel (kontras, ukuran sentuh), angka rata kanan dengan font tabular.

## 9. Kebutuhan non-fungsional

| Kode | Kebutuhan |
|---|---|
| NF-1 Biaya | Seluruh backend dan hosting di tier gratis. Kandidat Supabase (Postgres, Auth, RLS, pg_cron, Edge Functions); batas tier gratis terbaru dicek dan dikonfirmasi di HLD, termasuk risiko project dijeda karena tidak aktif. |
| NF-2 Keamanan | RLS di semua tabel user. Tidak ada secret di repo; semua kunci via environment variable. Kunci service-role hanya di sisi server (job/Edge Function), tidak pernah di app Flutter. |
| NF-3 Privasi | Data keuangan milik user; tidak ada analitik pihak ketiga di MVP. **[ASUMSI A-31]** |
| NF-4 Akurasi | Perhitungan uang memakai desimal (bukan double). Pembulatan hanya saat tampilan, kecuali aturan pembulatan broker/bank yang eksplisit. |
| NF-5 Keandalan | Job snapshot idempoten dan bisa dicoba ulang; kegagalan provider tidak menggagalkan snapshot (pakai harga terakhir + penanda). |
| NF-6 Waktu | Semua timestamp disimpan UTC; tanggal snapshot adalah tanggal kalender WIB. |
| NF-7 Kinerja | Dashboard tampil < 2 detik dengan 3 tahun snapshot harian (±1.100 baris per user). |
| NF-8 Platform | Web (browser modern desktop + mobile) dan Android; iOS bila build tersedia. **[ASUMSI A-32]** Distribusi MVP: web dulu + APK Android untuk pemakaian pribadi; publikasi ke store di luar MVP. |
| NF-9 Ekstensibilitas | Kategori aset, mata uang, provider harga, dan pembanding bisa ditambah tanpa migrasi besar. |
| NF-10 Teruji | Unit test wajib untuk avg price, break-even, realized P/L, deposito, cashflow, dan performa unit. |
| NF-11 Ekspor | **[ASUMSI A-33]** Ekspor CSV transaksi dan snapshot (sederhana) masuk MVP sebagai jaring pengaman data. |

## 10. Data (konseptual, dirinci di HLD)

- **Milik user (RLS):** profil/pengaturan, portofolio, preset broker, aset (holding), transaksi, cashflow, harga manual/NAV manual/kurs manual, seri pembanding manual, snapshot (header + rincian per kategori + per aset), pilihan pembanding.
- **Global (baca semua, tulis sistem):** instrumen (ticker, nama, mata uang, jenis), harga harian, kurs harian, seri pembanding preset/kustom, log pengambilan harga.

## 11. Risiko

| Risiko | Dampak | Mitigasi |
|---|---|---|
| Yahoo Finance atau halaman harga emas berubah/diblokir (tanpa API resmi) | Harga tidak terbarui | Abstraksi provider, harga terakhir + penanda basi, input manual, provider alternatif bisa ditambahkan |
| Batas tier gratis (row, eksekusi fungsi, project dijeda saat tidak aktif) | Snapshot gagal | Cek batas di HLD; job harian menjaga project tetap aktif; monitor kegagalan di dashboard |
| Salah klasifikasi cashflow vs perpindahan internal | Performa unit salah | Alur input yang jelas (kas portofolio, A-27, A-38), riwayat cashflow yang mudah diaudit |
| Aturan pajak/fee berubah | Angka bersih salah | Semua tarif configurable, disimpan per transaksi, ditandai perlu diverifikasi |
| Snapshot permanen tapi transaksi lama dikoreksi | Ketidakcocokan riwayat vs posisi kini | Dijelaskan di UI; ditangani A-30 |

## 12. Rencana rilis

- **MVP (cakupan PRD ini):** semua bagian 6 dan 7.
- **Setelah MVP (kandidat):** notifikasi TP/CL, amortisasi/bunga utang otomatis, dividen dan aksi korporasi otomatis, merek emas tambahan, mata uang tambahan, push/email reminder, berbagi akun keluarga, provider harga kedua.

## 13. Kriteria penerimaan MVP (ringkas)

1. User baru bisa daftar, membuat portofolio, mengisi opening balance untuk semua kategori (7 jenis aset, piutang, utang), dan melihat net worth (aset + piutang − utang) dalam IDR dalam satu sesi.
1a. Total semua portofolio sama persis dengan net worth; memindah aset antar portofolio tidak mengubah net worth maupun avg price.
1b. Harga buyback emas Antam, UBS, dan Galeri24 terambil otomatis per pecahan; jika sumber gagal, harga terakhir dipakai dengan penanda basi.
1c. Home dashboard menampilkan grafik gabungan dengan toggle garis dana disetor bersih, total disetor, dan total ditarik, serta pilihan rentang 1M sampai Kustom.
2. Snapshot 18:00 WIB tercatat otomatis selama 7 hari berturut-turut tanpa intervensi, termasuk saat bursa libur.
3. Avg price saham setelah serangkaian beli/jual sama dengan contoh di 7.1; realized P/L dan break-even sesuai rumus 7.2–7.3 (dibuktikan unit test).
4. Setoran besar di tengah periode tidak membuat grafik performa melonjak (dibuktikan unit test 7.8).
5. Mengganti pembanding langsung memperbarui grafik performa; ketiga jenis sumber (preset, ticker kustom, manual) berfungsi.
6. Mematikan provider harga tidak menggagalkan snapshot; penanda basi muncul dan input manual dipakai.
7. User A tidak bisa membaca data user B (diuji di level database).
8. Tidak ada secret di repository.

## 14. Keputusan dari Ilham (12 Oktober 2026)

Semua pertanyaan terbuka sudah dijawab:

| No | Keputusan |
|---|---|
| Q-1 | Utang mengurangi net worth; piutang ditambahkan sebagai aset (6.2.8, 6.2.9, 7.10). |
| Q-1a | Belanja dengan kartu kredit/paylater dianggap penarikan modal (A-37). |
| Q-2 | Buyback emas otomatis, terbatas Antam, UBS, Galeri24/Pegadaian (6.2.1). |
| Q-3 | Mode ARO dipilih per deposito: pokok saja (bunga dicairkan) atau pokok + bunga. |
| Q-4 | Dividen masuk MVP sebagai transaksi manual "Dividen" (nominal bersih), menambah kas portofolio, bukan cashflow modal. |
| Q-5 | Setiap portofolio punya kas (RDN, saldo exchange); setor/tarik kas = cashflow modal; beli/jual otomatis mengubah kas (6.11). Selisih "set saldo" tabungan = cashflow modal kecuali ditandai bunga (A-38). |
| Q-6 | Performa dihitung sejak mulai tracking; opening balance = modal awal (A-14). |
| Q-7 | Realized P/L bersih memotong fee jual, pajak jual, dan porsi fee beli dari lot yang dijual (A-25). |
| Baru | Portofolio kustom lintas jenis aset (6.11); kripto diperluas ke multi-koin (6.2.2). |

## 15. Daftar asumsi

| Kode | Ringkasan |
|---|---|
| A-1 | (dibatalkan) Net worth = aset + piutang dihitung − utang |
| A-2 | Aksi korporasi ditangani manual (transaksi penyesuaian) |
| A-3 | UI bahasa Indonesia, format id-ID, waktu WIB |
| A-4 | (diputuskan) Auth: email + kata sandi saja |
| A-5 | Harga/NAV/kurs manual tersimpan per user |
| A-6 | Reksadana IDR saja di MVP |
| A-7 | Deposito IDR saja di MVP |
| A-8 | Buyback emas diambil harian via scraping halaman Galeri24, fallback manual |
| A-9 | Harga kripto: XXX-IDR, fallback XXX-USD × kurs, fallback manual |
| A-10 | Odd lot didukung via penyesuaian dalam lembar |
| A-11 | Pengingat NAV basi di dalam aplikasi, default 7 hari |
| A-12 | Tabungan IDR: set saldo atau setor/tarik |
| A-13 | Backdate transaksi boleh, tidak sebelum opening balance |
| A-14 | Opening balance = modal awal, bukan setoran |
| A-15 | Snapshot menyimpan rincian per aset |
| A-16 | Retry snapshot sampai 23:59 WIB, celah dibiarkan jika gagal |
| A-17 | Tidak ada snapshot sebelum mulai tracking |
| A-18 | Tidak ada snapshot manual; dashboard punya nilai live |
| A-19 | Riwayat pembanding kustom di-backfill |
| A-20 | Pembanding asing dibandingkan dalam IDR secara default |
| A-21 | Statistik realized untuk semua aset ber-avg |
| A-22 | P/L = 0 dikeluarkan dari win rate |
| A-23 | Perhitungan uang memakai desimal, pembulatan saat tampil |
| A-24 | Fee beli dialokasikan proporsional; opening balance diestimasi |
| A-25 | Realized P/L mengurangi fee jual, pajak jual, dan porsi fee beli |
| A-26 | Deposito dinilai dengan bunga akrual harian |
| A-27 | Cashflow modal dicatat eksplisit, beli/jual bukan cashflow |
| A-28 | Cashflow hari t diproses sebelum snapshot hari t |
| A-29 | Performa unit untuk total dan per portofolio kustom |
| A-30 | Cashflow terlambat masuk snapshot berikutnya |
| A-31 | Tanpa analitik pihak ketiga |
| A-32 | Distribusi MVP: web + APK Android pribadi |
| A-33 | Ekspor CSV masuk MVP |
| A-34 | Bunga utang tidak dihitung otomatis; saldo sisa diperbarui user |
| A-35 | Piutang punya opsi "hitung dalam net worth" dan persentase |
| A-36 | Performa unit tidak dihitung saat net worth ≤ 0 |
| A-37 | Belanja kartu kredit/paylater dianggap penarikan modal (disetujui) |
| A-38 | Selisih "set saldo" tabungan = cashflow modal kecuali ditandai bunga |
| A-39 | Setiap aset/utang/piutang ada di tepat satu portofolio; bawaan "Utama" |
| A-40 | Penanda setoran/penarikan besar di grafik, ambang default Rp1.000.000 |
| A-41 | Unrealized di Statistik = posisi pada akhir rentang terhadap avg, bukan perubahan selama rentang |
| A-42 | Saldo awal aset yang ditambahkan setelah snapshot pertama dihitung setoran (`external_in`); sebelum snapshot pertama dihitung modal awal (disetujui Ilham, 12 Okt 2026) |
| A-43 | "Perubahan hari ini" di Overview dan kantong = net worth sekarang − net worth snapshot terakhir − cashflow modal sejak snapshot itu, jadi setor/tarik tidak terlihat sebagai untung/rugi (disetujui Ilham, 12 Okt 2026) |

## 16. Daftar aturan keuangan yang perlu diverifikasi

Semua disimpan sebagai konfigurasi (bukan konstanta di kode) dan diberi label di UI:

1. Fee beli/jual saham per broker, termasuk pungutan bursa dan PPN atas komisi.
2. PPh final penjualan saham (umumnya 0,1% dari nilai jual).
3. Pajak dan fee transaksi kripto (PPh/PPN, fee exchange).
4. Biaya subscription/redemption reksadana.
5. Pajak bunga deposito (umumnya 20%) dan ketentuan pengecualian saldo kecil.
6. Basis hari bunga deposito (365/360/actual) dan aturan pembulatan bank.
7. Aturan tanggal jatuh tempo deposito di akhir bulan.
8. Selisih harga jual vs buyback emas (spread) dan pajak penjualan emas jika ada.

## 17. Riwayat perubahan

| Versi | Tanggal | Perubahan |
|---|---|---|
| v0.1 | 12 Okt 2026 | Draft awal dari spesifikasi proyek. |
| v0.2 | 12 Okt 2026 | Utang (pengurang) dan piutang (penambah) masuk MVP. |
| v0.3 | 12 Okt 2026 | Buyback emas otomatis per merek dan pecahan (Antam, UBS, Galeri24/Pegadaian). |
| v0.4 | 12 Okt 2026 | Portofolio kustom lintas jenis aset dengan kas sendiri; kripto multi-koin; semua pertanyaan terbuka dijawab. |
| v0.5 | 12 Okt 2026 | Toggle garis dana disetor/ditarik di home dashboard; pilihan rentang waktu grafik. |
| v1.0 | 12 Okt 2026 | Disetujui Ilham. Dasar untuk Tahap 2 (HLD). |
| v1.4 | 12 Okt 2026 | Beranda jadi Overview: pembanding IHSG/BTC di grafik, alokasi donut per kantong atau jenis, tanpa ringkasan dan daftar kantong (F-DASH-4, F-DASH-5). |
| v1.3 | 12 Okt 2026 | Modal/Unrealized/Tunai di kartu kantong (F-PF-9), riwayat P/L (F-PF-10). |
| v1.2 | 12 Okt 2026 | Kas kantong hanya rupiah (F-PF-4); uang rupiah dan valas punya bentuk rekening/tunai; valas MVP diperluas ke beberapa mata uang dengan konversi rupiah langsung di form (6.2.6, 6.2.7). |
| v1.5 | 12 Okt 2026 | Slice 2: A-42 (saldo awal setelah tracking = setoran, keputusan Ilham) dan A-43 (perubahan hari ini tanpa cashflow), keduanya disetujui Ilham. |
| v1.1 | 12 Okt 2026 | Dari review desain: label rentang bahasa Inggris dengan default 1W (F-DASH-2); Statistik mendapat rentang kustom, unrealized, dan daftar aset yang dipegang (F-STAT-5 s.d. 7, A-41). |
