# 🍲 SaveBite: Food Waste Management

Aplikasi mobile (Flutter) penanggulangan pemborosan makanan (*food waste*) yang terintegrasi dengan situs web Django PWS.

## 🔗 Tautan Penting

- **Desain UI/UX (Figma):** [Tautan Prototipe Desain Figma](https://www.figma.com/design/Qz00q3qJVwqCvgUgkwAJ8A/Design-System?t=ncBA4Ym5KGjHdbwo-1)
- **Tautan Rilis APK:** [Belum ada]
- **Deployment (PWS):** [Tautan Deployment PWS](https://reshandy-taftazani-savebite.pws.cs.ui.ac.id)

## 👥 Anggota Kelompok & Pembagian Modul

Kelas / Kelompok: PBP D / Kelompok 8

| Nama | NPM | Modul yang Dikerjakan |
| ----- | ----- | ----- |
| Muhammad Ilhami Yasya | 2506593891 | Modul 1: Katalog Resep Bahan Sisa *(Integrasi TheMealDB)* |
| Mutia Muthmainnah | 2506625230 | Modul 2: Food Rescue Planner *(Manajemen Rencana Penyelamatan)* |
| Silvia Lalita Damayanti | 2506621863 | Modul 3: Resep Komunitas *(Platform Berbagi Resep Sisa)* |
| Reshandy Taftazani Aulya | 2506547651 | Modul 4: Food Rescue Request Board *(Papan Permintaan Bahan)* |
| Georgius Satria Adibrata | 2506589976 | Modul 5: Jurnal Jejak Makanan *(Pencatatan Riwayat & Analitik)* |

## 📖 Deskripsi Aplikasi & Manfaat bagi Masyarakat

Pemborosan makanan (*food waste*) merupakan salah satu isu lingkungan dan finansial terbesar saat ini. Banyak bahan makanan yang sebenarnya masih layak konsumsi namun terbuang sia-sia karena kurangnya perencanaan atau ide pengelolaannya.

SaveBite hadir sebagai solusi interaktif (versi *mobile* yang terintegrasi dengan situs web Django PWS) untuk menanggulangi masalah tersebut. Aplikasi ini membantu pengguna memaksimalkan pemanfaatan bahan makanan melalui fitur rencana penyelamat makanan, pencarian resep darurat berbahan sisa, hingga ruang komunitas untuk saling berbagi resep dan sisa bahan makanan. Dengan mencatat jejak makanan secara konsisten, SaveBite bertujuan membangun kebiasaan konsumsi yang lebih bijak dan berkelanjutan.

## 🎯 Target Pengguna & Peran Pengguna (User Roles)

### Target Pengguna

- **Anak Kost & Mahasiswa:** Individu dengan bahan makanan terbatas yang sering kebingungan mengolah sisa bahan di kulkas.
- **Rumah Tangga / Pemula Masak:** Individu yang ingin menghemat pengeluaran belanja harian dan mengurangi limbah organik rumah tangga.

### Peran Pengguna

- **Pengunjung Umum (Guest / Unauthenticated):**
  - Dapat menelusuri katalog resep publik.
  - Dapat melihat posting board tawaran/permintaan makanan komunitas.
  - *Tidak dapat* berinteraksi langsung atau mengelola inventaris pribadi.
- **Pengguna Terdaftar (Authenticated User):**
  - Mengelola kulkas/inventaris pribadi dan menyimpan resep favorit.
  - Membagikan resep kreasi sendiri ke komunitas.
  - Membuat atau merespons tawaran/permintaan bahan makanan di board.
  - Mengisi dan memantau jurnal jejak makanan harian.

## 📦 Rincian Modul (Implementasi CRUD Lengkap)

*Setiap modul dikembangkan secara independen pada aplikasi mobile Flutter dan terhubung ke endpoint Django REST Framework (DRF) milik masing-masing modul:*

### 1. Katalog Resep Bahan Sisa (TheMealDB API) — Ilham

**Deskripsi:** Modul cerdas untuk mencari inspirasi resep masakan berdasarkan sisa bahan yang hampir kedaluwarsa.  
**Model Dasar:** Menyimpan data resep favorit/bookmark dari API beserta catatan kustomisasi pengguna.  
**Fitur CRUD:**

- **Create:** Menyimpan (bookmark) resep hasil pencarian dari API ke dalam daftar favorit lokal.
- **Read:** Menampilkan hasil fetch pencarian dari API TheMealDB dan membaca daftar resep yang sudah di-bookmark.
- **Update:** Mengedit catatan atau tips pribadi pada resep yang telah disimpan.
- **Delete:** Menghapus resep dari daftar bookmark.

### 2. Food Rescue Planner — Mutia

**Deskripsi:** Perencana aksi untuk menyelamatkan bahan makanan dengan target dan metode yang jelas (misal: dimasak, diawetkan).  
**Model Dasar:** Menyimpan nama bahan, jumlah, target tanggal, metode aksi, dan status progres (On Going, Success, Failed).  
**Fitur CRUD:**

- **Create:** Membuat rescue plan baru dengan detail nama, jumlah, target, dan metode aksi.
- **Read:** Melihat daftar rescue plan yang aktif beserta status progresnya.
- **Update:** Mengubah jumlah, target tanggal, metode aksi, atau status (menjadi Success/Failed).
- **Delete:** Menghapus rencana yang sudah dibatalkan atau tidak relevan.

**Integrasi:** Rescue plan yang berstatus Success atau Failed akan terhubung otomatis ke modul Jurnal Jejak Makanan (Geo) untuk pencatatan akhir.

### 3. Resep Komunitas — Lalita

**Deskripsi:** Ruang berbagi (feed) tempat pengguna mempublikasikan resep kreasi dari bahan sisa untuk menginspirasi pengguna lain.  
**Model Dasar:** Menyimpan judul resep, deskripsi, daftar bahan sisa, langkah-langkah, dan relasi ke pembuat (Author).  
**Fitur CRUD:**

- **Create:** Menambahkan dan mempublikasikan resep kreasi sendiri.
- **Read:** Menjelajahi resep-resep yang dibagikan oleh pengguna lain dalam bentuk linimasa (feed).
- **Update:** Mengedit detail resep (judul, bahan, cara masak) yang telah dibuat sendiri.
- **Delete:** Menghapus resep pribadi dari feed komunitas.

### 4. Food Rescue Request Board — Sandy

**Deskripsi:** Papan interaktif bergaya forum bagi komunitas lokal untuk meminta sisa bahan makanan dalam jumlah kecil agar tidak perlu membeli baru.  
**Model Dasar:** Menyimpan detail permintaan bahan, relasi peminta, dan status pemenuhan (Pending, Terpenuhi).  
**Fitur CRUD:**

- **Create:** Memposting permintaan/kebutuhan sisa bahan makanan spesifik.
- **Read:** Menampilkan papan board berisi daftar pencarian bahan makanan dari pengguna lain.
- **Update:** Interaksi mengubah status; pengguna lain merespons dengan menekan tombol "Saya Punya!", dan pembuat post dapat mengubah status menjadi "Terpenuhi".
- **Delete:** Menghapus posting permintaan jika sudah tidak butuh atau sudah dibeli sendiri.

### 5. Jurnal Jejak Makanan — Geo

**Deskripsi:** Modul rekam jejak pribadi (tracker) untuk menghitung dan mengevaluasi persentase makanan yang berhasil diselamatkan atau terbuang.  
**Model Dasar:** Menyimpan log harian berupa nama makanan, status konsumsi (Terselamatkan/Terbuang), dan catatan riwayat makanan.  
**Fitur CRUD:**

- **Create:** Mencatat log riwayat makanan harian beserta status akhirnya.
- **Read:** Menampilkan log riwayat secara kronologis serta ringkasan persentase keberhasilan (success rate).
- **Update:** Mengedit catatan atau memperbaiki input status dan jumlah yang salah.
- **Delete:** Menghapus baris catatan riwayat dari jurnal.

## 🔗 Alur Integrasi Data (Flutter & Django REST Framework)

- **Pusat Data di Web Django (PWS):** Seluruh data aplikasi (akun pengguna, *bookmark* resep, *rescue plan*, resep komunitas, *request board*, dan jurnal) tetap tersimpan di database situs web Django SaveBite yang telah di-*deploy* di PWS.
- **Web Service (Django REST Framework):** Situs web Django menyediakan *endpoint* API menggunakan **Django REST Framework** (*serializer* dan *view/viewset*) untuk mengonversi data dari database menjadi format **JSON** serta memproses permintaan autentikasi dan manipulasi data.
- **Komunikasi Asinkron di Flutter:** Aplikasi *mobile* Flutter mengirimkan permintaan HTTP secara asinkron (menggunakan *package* seperti `pbp_django_auth` / `http`) ke *endpoint* API Django untuk mengambil, menambah, mengubah, maupun menghapus data.
- **Penyajian UI:** Respons JSON yang diterima oleh Flutter di-parsing ke dalam model Dart dan ditampilkan secara dinamis pada masing-masing halaman modul.
