# 🍲 SaveBite: Food Waste Management

Aplikasi mobile (Flutter) penanggulangan pemborosan makanan (*food waste*) yang terintegrasi dengan situs web Django SaveBite di PWS melalui web service Django REST Framework. Dibuat untuk mata kuliah Pemrograman Berbasis Platform (PBP), Kelas D, Kelompok 8, sebagai Proyek Akhir Semester.

## 🔗 Tautan Penting

- **Desain UI/UX (Figma, view-only):** [Desain UI seluruh modul dan design system](https://www.figma.com/design/Qz00q3qJVwqCvgUgkwAJ8A/Design-System)
- **Tautan Rilis APK:** [Belum ada]
- **Deployment situs web (PWS):** [reshandy-taftazani-savebite.pws.cs.ui.ac.id](https://reshandy-taftazani-savebite.pws.cs.ui.ac.id)

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

SaveBite hadir sebagai solusi interaktif berbasis *mobile* untuk menanggulangi masalah tersebut. Aplikasi ini membantu pengguna memaksimalkan pemanfaatan bahan makanan melalui fitur rencana penyelamatan makanan, pencarian resep darurat berbahan sisa, hingga ruang komunitas untuk saling berbagi resep dan sisa bahan makanan. Dengan mencatat jejak makanan secara konsisten, SaveBite bertujuan membangun kebiasaan konsumsi yang lebih bijak dan berkelanjutan.

## 🎯 Target Pengguna & Peran Pengguna (User Roles)

### Target Pengguna

- **Anak Kost & Mahasiswa:** Individu dengan bahan makanan terbatas yang sering kebingungan mengolah sisa bahan di kulkas.
- **Rumah Tangga / Pemula Masak:** Individu yang ingin menghemat pengeluaran belanja harian dan mengurangi limbah organik rumah tangga.

### Peran Pengguna

- **Pengunjung Umum (Guest / Unauthenticated):**
  - Dapat menelusuri katalog resep publik.
  - Dapat melihat posting board tawaran/permintaan makanan komunitas.
  - *Tidak dapat* membuat atau mengubah data, maupun mengelola data pribadi.
- **Pengguna Terdaftar (Authenticated User):**
  - Menyimpan resep favorit (*bookmark*) dan menambahkan catatan pribadi.
  - Membuat dan mengelola *rescue plan* untuk bahan makanan miliknya.
  - Membagikan resep kreasi sendiri ke komunitas.
  - Membuat atau merespons permintaan bahan makanan di *request board*.
  - Mengisi dan memantau jurnal jejak makanan harian.

## 📦 Rincian Modul (Implementasi CRUD Lengkap)

Setiap modul dikerjakan oleh satu anggota dan terdiri dari halaman-halaman Flutter yang terhubung ke endpoint Django REST Framework (DRF) milik modul tersebut. Seluruh operasi CRUD dijalankan melalui endpoint API pada situs web Django.

### 1. Katalog Resep Bahan Sisa (TheMealDB API): Muhammad Ilhami Yasya

**Deskripsi:** Modul untuk mencari inspirasi resep masakan berdasarkan sisa bahan yang hampir kedaluwarsa.
**Model Dasar:** Menyimpan data resep favorit/*bookmark* dari API beserta catatan kustomisasi pengguna.
**Fitur CRUD:**

- **Create:** Menyimpan (*bookmark*) resep hasil pencarian dari TheMealDB ke daftar favorit pengguna di database Django.
- **Read:** Menampilkan hasil pencarian dari TheMealDB dan daftar resep yang sudah di-*bookmark*.
- **Update:** Mengedit catatan atau tips pribadi pada resep yang telah disimpan.
- **Delete:** Menghapus resep dari daftar *bookmark*.

### 2. Food Rescue Planner: Mutia Muthmainnah

**Deskripsi:** Perencana aksi untuk menyelamatkan bahan makanan dengan target dan metode yang jelas (misalnya dimasak atau diawetkan).
**Model Dasar:** Menyimpan nama bahan, jumlah, target tanggal, metode aksi, dan status progres (On Going, Success, Failed).
**Fitur CRUD:**

- **Create:** Membuat *rescue plan* baru dengan detail nama, jumlah, target, dan metode aksi.
- **Read:** Melihat daftar *rescue plan* beserta status progresnya.
- **Update:** Mengubah jumlah, target tanggal, metode aksi, atau status (menjadi Success/Failed).
- **Delete:** Menghapus rencana yang sudah dibatalkan atau tidak relevan.

**Integrasi:** *Rescue plan* yang berstatus Success atau Failed terhubung otomatis ke modul Jurnal Jejak Makanan (Georgius) untuk pencatatan akhir.

### 3. Resep Komunitas: Silvia Lalita Damayanti

**Deskripsi:** Ruang berbagi (*feed*) tempat pengguna mempublikasikan resep kreasi dari bahan sisa untuk menginspirasi pengguna lain.
**Model Dasar:** Menyimpan judul resep, deskripsi, daftar bahan sisa, langkah-langkah, dan relasi ke pembuat (*author*).
**Fitur CRUD:**

- **Create:** Menambahkan dan mempublikasikan resep kreasi sendiri.
- **Read:** Menjelajahi resep yang dibagikan pengguna lain dalam bentuk linimasa (*feed*).
- **Update:** Mengedit detail resep (judul, bahan, cara masak) yang dibuat sendiri.
- **Delete:** Menghapus resep pribadi dari *feed* komunitas.

### 4. Food Rescue Request Board: Reshandy Taftazani Aulya

**Deskripsi:** Papan interaktif bergaya forum bagi komunitas lokal untuk meminta sisa bahan makanan dalam jumlah kecil agar tidak perlu membeli baru.
**Model Dasar:** Menyimpan detail permintaan bahan, relasi peminta, dan status pemenuhan (Pending, Terpenuhi).
**Fitur CRUD:**

- **Create:** Memposting permintaan sisa bahan makanan yang spesifik.
- **Read:** Menampilkan papan berisi daftar permintaan bahan makanan dari pengguna lain.
- **Update:** Pengguna lain merespons dengan menekan tombol "Saya Punya!", dan pembuat post dapat mengubah status menjadi "Terpenuhi".
- **Delete:** Menghapus posting permintaan jika sudah tidak dibutuhkan atau sudah dibeli sendiri.

### 5. Jurnal Jejak Makanan: Georgius Satria Adibrata

**Deskripsi:** Modul rekam jejak pribadi (*tracker*) untuk menghitung dan mengevaluasi persentase makanan yang berhasil diselamatkan atau terbuang.
**Model Dasar:** Menyimpan log harian berupa nama makanan, status konsumsi (Terselamatkan/Terbuang), dan catatan riwayat makanan.
**Fitur CRUD:**

- **Create:** Mencatat log riwayat makanan harian beserta status akhirnya.
- **Read:** Menampilkan log riwayat secara kronologis serta ringkasan persentase keberhasilan (*success rate*).
- **Update:** Mengedit catatan atau memperbaiki input status dan jumlah yang salah.
- **Delete:** Menghapus baris catatan riwayat dari jurnal.

## 🔌 Daftar Endpoint Django REST Framework

Base URL: `https://reshandy-taftazani-savebite.pws.cs.ui.ac.id`


| Modul | Method | Endpoint | Fungsi |
| ----- | ----- | ----- | ----- |
| Autentikasi | POST | `/login/`, `/register/`, `/logout/` *(sesi Django; target API mobile diselaraskan dengan tim)* | Login, registrasi, dan logout pengguna |
| 1. Katalog Resep | GET / POST | `/api/bookmarks/` | Daftar dan tambah *bookmark* |
| 1. Katalog Resep | PUT / DELETE | `/api/bookmarks/<id>/` | Ubah catatan dan hapus *bookmark* |
| 2. Food Rescue Planner | GET / POST | `/api/rescue-plans/` | Daftar dan tambah *rescue plan* |
| 2. Food Rescue Planner | PUT / DELETE | `/api/rescue-plans/<id>/` | Ubah dan hapus *rescue plan* |
| 3. Resep Komunitas | GET / POST | `/api/community-recipes/` | Daftar dan tambah resep komunitas |
| 3. Resep Komunitas | PUT / DELETE | `/api/community-recipes/<id>/` | Ubah dan hapus resep |
| 4. Request Board | GET / POST | `/api/v1/requests/` | Daftar (filter `q`, `status`, `mine`, `sort`, pagination 20) dan tambah permintaan (dengan header `Idempotency-Key`) |
| 4. Request Board | GET / DELETE | `/api/v1/requests/<id>/` | Detail permintaan (publik) dan hapus permintaan (khusus owner, `204`) |
| 4. Request Board | GET / POST | `/api/v1/requests/<id>/offers/` | Daftar penawar (khusus owner, pagination 20) dan kirim penawaran bantuan (non-owner, body `{}`) |
| 4. Request Board | PATCH | `/api/v1/requests/<id>/selection/` | Pilih atau ganti penawar terpilih (khusus owner, `{"offer_id": <int>}`) |
| 4. Request Board | PATCH | `/api/v1/requests/<id>/status/` | Tandai permintaan terpenuhi (khusus owner, `{"status": "fulfilled"}`) |
| 4. Request Board | GET | `/api/v1/request-creations/<uuid:key>/` | Cek status idempotensi pembuatan permintaan setelah timeout |
| 5. Jurnal Jejak Makanan | GET / POST | `/jurnal/api/v1/food-logs/` | Daftar log makanan milik pengguna (filter query, status, date_from, date_to, page) dan tambah log makanan |
| 5. Jurnal Jejak Makanan | GET / PUT / PATCH / DELETE | `/jurnal/api/v1/food-logs/<id>/` | Detail, ubah (penuh/sebagian), dan hapus log makanan |
| 5. Jurnal Jejak Makanan | GET | `/jurnal/api/v1/food-logs/summary/` | Ringkasan jumlah dan persentase makanan terselamatkan/terbuang |

## 🔗 Alur Integrasi Data (Flutter & Django REST Framework)

1. **Pusat data di web Django (PWS):** Seluruh data aplikasi (akun pengguna, *bookmark* resep, *rescue plan*, resep komunitas, *request board*, dan jurnal) tersimpan di database situs web Django SaveBite yang sudah di-*deploy* di PWS. Aplikasi Flutter tidak menyimpan data statis; semua data berasal dari server.
2. **Web service (Django REST Framework):** Situs web Django menyediakan endpoint API menggunakan **Django REST Framework** (*serializer* dan *view/viewset*) untuk mengonversi data dari database menjadi format **JSON** serta memproses permintaan autentikasi dan manipulasi data.
3. **Komunikasi asinkron di Flutter:** Aplikasi Flutter mengirim permintaan HTTP secara asinkron (menggunakan package seperti `pbp_django_auth` dan `http`) ke endpoint API Django untuk mengambil, menambah, mengubah, maupun menghapus data. Sesi login dikelola melalui cookie yang dikirim bersama setiap permintaan.
4. **Penyajian UI:** Respons JSON yang diterima Flutter di-*parsing* ke dalam model Dart dan ditampilkan secara dinamis pada halaman masing-masing modul. Perubahan data di situs web akan terlihat di aplikasi, begitu pula sebaliknya.
