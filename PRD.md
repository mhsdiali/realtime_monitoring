# PRD - Aplikasi Android Monitoring Suhu dan Kelembapan Gudang SPPG

Versi 0.1 (draf awal prototipe) - 14 November 2026

## Cara membaca dokumen ini

Setiap butir penting diberi tag berikut.

- [KEPUTUSAN] sudah diputuskan pemilik proyek.
- [USULAN] usulan penulis PRD yang belum disetujui.
- [PERLU DIKONFIRMASI] belum diketahui, jangan ditebak atau dikarang.

Untuk coding agent, kerjakan per milestone pada bagian 10, jangan melompat ke milestone berikutnya sebelum yang sekarang lulus uji, dan jangan mengarang nilai yang bertag PERLU DIKONFIRMASI.

## 1. Ringkasan produk

Aplikasi Android berbasis Flutter untuk petugas SPPG Lenteng Timur 2 (Desa Lenteng Timur, Kecamatan Lenteng, Kabupaten Sumenep). Aplikasi memantau suhu dan kelembapan gudang bahan pangan secara real-time, mengirim notifikasi saat kondisi abnormal, dan memungkinkan petugas mengendalikan AC secara manual lewat sinyal IR.

Latar masalah. Kelembapan gudang saat ini hanya dibaca dari hygrometer manual sekitar sekali sehari dan tidak dicatat. Bahan seperti sayur dan tahu cukup sering rusak karena AC bermasalah.

Proyek ini bagian dari skripsi "Sistem Monitoring Suhu dan Kelembapan Secara Real-Time pada Gudang Bahan Pangan Berbasis IoT di SPPG Lenteng Timur 2".

## 2. Ruang lingkup

Termasuk cakupan.

1. Login dan logout.
2. Dashboard real-time (suhu, kelembapan, status keseluruhan, status perangkat).
3. Riwayat dan grafik.
4. Pengaturan threshold.
5. Kontrol AC manual (menyalakan, mematikan, mengubah suhu).
6. Notifikasi push FCM.

Di luar cakupan.

1. iOS [KEPUTUSAN] hanya Android.
2. Kontrol AC otomatis berdasarkan ambang batas [KEPUTUSAN] kontrol AC sepenuhnya manual.
3. Lebih dari satu peran pengguna dan pendaftaran mandiri.
4. Banyak node. MVP hanya 1 node di gudang basah ber-AC. Gudang kering, chiller, dan freezer adalah rencana lanjutan dan akan mengubah struktur RTDB.
5. Firmware ESP32 dibahas dokumen terpisah; PRD ini hanya mendefinisikan kontrak datanya. Cloud Functions tidak dipakai karena project tetap Spark; notifikasi ditangani notification worker di VPS [KEPUTUSAN].

Export riwayat ke CSV disebut di rancangan awal tetapi belum dibahas pada arsitektur Firebase [PERLU DIKONFIRMASI].

## 3. Pengguna dan akses

1. Satu peran saja bernama petugas (admin sama dengan petugas) [KEPUTUSAN].
2. Akun petugas dibuat manual lewat console Firebase Authentication. Pendaftaran mandiri tidak tersedia di aplikasi dan dimatikan di pengaturan Authentication [KEPUTUSAN].
3. Metode login yang dipakai adalah email dan kata sandi [KEPUTUSAN].
4. ESP32 memakai akun Firebase Authentication khusus perangkat. Akun ini sudah dibuat dan UID-nya dipakai di aturan keamanan [KEPUTUSAN].

## 4. Arsitektur

```
ESP32 + SHT31 + IR  <-->  Firebase RTDB  <-->  Aplikasi Flutter (Android)
                               |
                   Notification worker (VPS) ---> FCM ---> Aplikasi Flutter
```

1. Backend memakai Firebase (project "Monitoring SPPG" dengan project ID `monitoring-sppg-81246`) pada paket Spark karena kendala billing [KEPUTUSAN]. Tidak ada REST API atau server backend; satu-satunya proses server adalah notification worker di VPS untuk mengirim FCM [KEPUTUSAN]. Rancangan lama Laravel dan MySQL tidak dipakai lagi.
2. Aplikasi membaca data lewat RTDB listener, bukan polling [KEPUTUSAN].
3. ESP32 mengirim data maksimal tiap 5 detik. Perangkat dianggap offline bila tidak ada pembaruan lebih dari 30 detik [KEPUTUSAN].
4. Perintah AC ditulis aplikasi ke node khusus di RTDB lalu dibaca ESP32, tanpa lewat Cloud Functions [KEPUTUSAN].
5. Waktu berasal dari NTP di ESP32 dan disimpan sebagai epoch milidetik [KEPUTUSAN].
6. Tiga tugas notifikasi dijalankan notification worker VPS [KEPUTUSAN].
   1. Saat `monitoring/latest` berubah, bandingkan dengan `thresholds` dan `alert_state`, kirim FCM hanya saat status berubah, lalu perbarui `alert_state`.
   2. Terjadwal tiap 1 menit, periksa `last_seen` dengan batas 30 detik, kirim notifikasi offline sekali memakai penanda `offline_notified`.
   3. Terjadwal harian, hapus entri `history` yang lebih tua dari 7 hari.
7. Status offline pada tampilan aplikasi dinilai aplikasi sendiri secara real-time, sedangkan notifikasi offline dikirim worker terjadwal (pendekatan hybrid) [KEPUTUSAN].

## 5. Model data RTDB (prototipe versi pertama, sudah dibeku)

```
ROOT
├── monitoring
│   ├── latest
│   │   ├── temperature
│   │   ├── humidity
│   │   └── timestamp
│   └── history
│       └── {timestamp}
│           ├── temperature
│           ├── humidity
│           └── timestamp
├── thresholds
│   ├── temperature
│   │   ├── min
│   │   └── max
│   └── humidity
│       ├── min
│       └── max
├── alert_state
│   ├── status
│   ├── active_parameters
│   └── updated_at
├── alert_history
│   └── {alert_id}
│       ├── status
│       ├── active_parameters
│       ├── temperature
│       ├── humidity
│       ├── timestamp
│       └── reading_timestamp
├── devices
│   ├── status
│   │   ├── last_seen
│   │   └── offline_notified
│   └── ac_control
│       ├── commands
│       │   └── {command_id}
│       │       ├── action
│       │       ├── setpoint
│       │       ├── enabled
│       │       └── created_at
│       └── acknowledgements
│           └── {command_id}
│               ├── status
│               ├── processed_at
│               └── error_message
└── fcm_tokens
    └── {uid}
        └── {token_id}
            ├── token
            └── updated_at
```

Kontrak nilai.

| Node | Tipe dan satuan | Catatan |
|---|---|---|
| `temperature` | angka, derajat Celsius | |
| `humidity` | angka, persen RH | |
| `timestamp`, `last_seen`, `created_at`, `processed_at`, `updated_at` | angka, epoch milidetik | Tampilkan dalam WIB di aplikasi |
| `thresholds/.../min dan max` | angka | Acuan area AC suhu 16 sampai 20 dan kelembapan 40 sampai 60 |
| `alert_state/status` | teks, normal atau abnormal | |
| `alert_history/status` | teks, hanya `abnormal` | Ditulis worker saat status berubah dari normal ke abnormal [KEPUTUSAN] |
| `active_parameters` | daftar nama parameter | Node hilang berarti daftar kosong (RTDB tidak menyimpan array kosong) |
| `reading_timestamp` | angka, epoch milidetik | Waktu pembacaan `latest` yang memicu peringatan; opsional |
| `action` | teks, lima nilai | `turn_on`, `turn_off`, `set_temperature`, `set_jet`, dan `set_swing` [KEPUTUSAN] |
| `setpoint` | angka, derajat Celsius | Hanya ada pada `set_temperature`. Rentang 16–30 °C [KEPUTUSAN] |
| `enabled` | boolean | Hanya ada pada `set_jet` dan `set_swing`. `true` mengaktifkan, `false` menonaktifkan [KEPUTUSAN] |
| `acknowledgements/status` | teks, hanya `transmitted` | Artinya modul IR sudah memancarkan sinyal, bukan AC pasti berubah [KEPUTUSAN]. Bila perintah tidak dikenal, ack hanya berisi `error_message` tanpa `status` |
| `error_message` | teks, opsional | Diisi firmware saat menerima perintah yang tidak dikenal [KEPUTUSAN] |
| `{command_id}` dan `{token_id}` | kunci acak dari Firebase | [KEPUTUSAN] untuk `token_id`, [USULAN] untuk `command_id` |
| `offline_notified` | boolean | Hanya dipakai Cloud Functions |

Aturan data.

1. `history` ditulis ESP32 tiap 30 menit dan disimpan 7 hari, sekitar 336 entri [KEPUTUSAN]. `latest` diperbarui tiap 5 detik.
2. Worker menulis `alert_history` hanya saat transisi normal → abnormal dan menghapus entri lebih tua dari 7 hari [KEPUTUSAN].
3. ESP32 menulis `latest` sebagai satu objek utuh.
4. `commands` dan `acknowledgements` dihapus segera setelah ack diproses; firmware menghapus keduanya [KEPUTUSAN].

Matriks akses target.

| Node | ESP32 | Petugas | Worker |
|---|---|---|---|
| `monitoring/latest` dan `history` | tulis | baca | baca dan hapus (history) |
| `thresholds` | tidak ada | baca dan tulis | baca |
| `alert_state` | tidak ada | baca | tulis |
| `alert_history` | tidak ada | baca | tulis dan hapus |
| `devices/status/last_seen` | tulis | baca | baca |
| `devices/status/offline_notified` | tidak ada | tidak ada | baca dan tulis |
| `ac_control/commands` | baca dan hapus | tulis dan baca | tidak ada |
| `ac_control/acknowledgements` | tulis dan hapus | baca | tidak ada |
| `fcm_tokens/{uid}` | tidak ada | baca dan tulis oleh pemilik uid | baca |

Retensi `commands` dan `acknowledgements`: dihapus segera setelah ack [KEPUTUSAN].

## 6. Kebutuhan fungsional

### F1 Autentikasi

1. Layar login dengan email dan kata sandi. Tidak ada tombol daftar.
2. Sesi tetap tersimpan setelah aplikasi ditutup. Logout mengembalikan ke layar login.
3. Pesan galat berbahasa Indonesia dan tidak membocorkan apakah email terdaftar [USULAN].
4. Saat logout, token FCM perangkat ini dihapus dari `fcm_tokens` [USULAN].

Selesai bila login valid masuk ke dashboard, login salah menampilkan pesan, dan logout membersihkan sesi.

### F2 Dashboard real-time

1. Menampilkan suhu, kelembapan, waktu pembacaan terakhir (WIB), status keseluruhan, dan parameter yang abnormal dari `active_parameters`.
2. Data diperbarui lewat listener tanpa tombol refresh.
3. Status online atau offline perangkat dihitung dari selisih waktu sekarang dengan `last_seen`, offline bila lebih dari 30 detik [KEPUTUSAN].
4. Waktu sekarang memakai server time offset dari Firebase, bukan jam ponsel [USULAN]. Evaluasi diulang berkala (usulan tiap 5 detik) karena saat perangkat mati tidak ada data baru yang memicu pembaruan.
5. Saat offline, nilai terakhir tetap tampil dengan penanda usang dan kontrol AC dinonaktifkan [USULAN].
6. Indikator koneksi aplikasi ke Firebase [USULAN].

Selesai bila data dari simulator tampil dan berubah otomatis, serta status berganti ke offline setelah simulator dihentikan lebih dari 30 detik.

### F3 Riwayat dan grafik

1. Grafik suhu dan kelembapan dari `monitoring/history` beserta 5 peringatan abnormal terakhir dari `alert_history` [KEPUTUSAN].
2. Pengambilan data memakai query berdasarkan kunci timestamp dan tidak mengunduh seluruh node tanpa batas [USULAN].
3. Tampilan kosong yang jelas bila belum ada data.
4. Pilihan rentang waktu grafik 6 jam, 24 jam, dan 7 hari [KEPUTUSAN].
5. Setiap peringatan menampilkan parameter yang abnormal, nilai suhu dan kelembapan, serta waktu kejadian dalam WIB [KEPUTUSAN].

Selesai bila grafik menampilkan entri simulator dengan sumbu waktu WIB.

### F4 Pengaturan threshold

1. Menampilkan dan mengubah min dan max suhu serta kelembapan di `thresholds`.
2. Validasi di sisi aplikasi. Min harus lebih kecil dari max, suhu berada pada rentang 10 sampai 40 [USULAN selaras batas suhu dari pemilik proyek], kelembapan 0 sampai 100.
3. Konfirmasi sebelum menyimpan dan pesan sukses atau gagal.
4. Perubahan berlaku pada evaluasi Cloud Functions berikutnya.
5. Nilai awal 16–20 °C dan 40–60% ditampilkan sebagai prefill; petugas menyimpan lewat aplikasi [KEPUTUSAN].

Selesai bila nilai tersimpan ke RTDB, dan nilai tidak valid ditolak sebelum dikirim.

### F5 Kontrol AC manual

AC bermerk SHARP, sinyal IR dari LED IR langsung tanpa relay, library firmware IRremoteESP8266 [KEPUTUSAN]. Aksi yang tersedia: menyalakan, mematikan, set suhu, mode JET/Non JET, dan Swing/Non Swing. JET dipetakan ke turbo dan Swing ke ayunan vertikal (toggle) pada firmware [KEPUTUSAN].

Alur.

1. Petugas memilih aksi.
2. Aplikasi memeriksa perangkat online. Bila offline, perintah tidak dikirim dan tidak diantrekan, petugas diminta mengulang [KEPUTUSAN].
3. Aplikasi menulis `commands/{command_id}` berisi `action`, `setpoint` (khusus set suhu), `enabled` (khusus JET/Swing), dan `created_at`. Waktu dibuat memakai timestamp server [USULAN].
4. Status tampil menunggu. Aplikasi mendengarkan `acknowledgements/{command_id}`.
5. Bila `transmitted` muncul, tampil dipancarkan.
6. Bila tidak ada konfirmasi dalam 5 detik, tampil belum terkirim dan petugas diminta mengulang [KEPUTUSAN].
7. Teks antarmuka tidak boleh menyatakan AC berhasil berubah, hanya sinyal dipancarkan [KEPUTUSAN].
8. Tombol dinonaktifkan selama menunggu agar tidak terkirim ganda, dan mematikan AC meminta konfirmasi [USULAN].
9. Perintah usang yang masih tersisa di `commands` tetap dieksekusi saat ESP32 kembali online [KEPUTUSAN].

Selesai bila semua aksi menghasilkan node `commands`, dan simulator yang menulis `acknowledgements` mengubah status di layar. Pilihan JET/Swing di aplikasi hanya menandai perintah terakhir, bukan status AC yang sebenarnya.

### F6 Notifikasi push

1. Notifikasi dikirim notification worker VPS lewat FCM saat status berubah dan saat perangkat offline.
2. Aplikasi meminta izin notifikasi (wajib untuk Android 13 ke atas) dan membuat channel notifikasi.
3. Token FCM disimpan ke `fcm_tokens/{uid}/{token_id}` berisi `token` dan `updated_at`. Bila token yang sama sudah ada, hanya perbarui `updated_at`, dan perbarui saat token berganti [KEPUTUSAN].
4. Notifikasi harus muncul saat aplikasi terbuka, di latar belakang, dan tertutup. Saat terbuka gunakan notifikasi lokal. Mengetuk notifikasi membuka dashboard.
5. Notifikasi dikirim saat normal → abnormal dan abnormal → normal, tanpa pengingat berkala, memakai teks judul/isi yang disetujui [KEPUTUSAN].

Selesai bila pesan uji FCM sampai ke ponsel dalam tiga kondisi aplikasi.

### F7 Umum

1. Bahasa antarmuka Indonesia, zona waktu WIB.
2. Navigasi bawah dengan empat tab yaitu Beranda, Riwayat, Kontrol AC, Pengaturan [KEPUTUSAN].

## 7. Kebutuhan non-fungsional

1. Hanya Android. Versi Android minimum API 33 (Android 13) [KEPUTUSAN].
2. Tidak ada kredensial server di aplikasi, hanya konfigurasi klien Firebase. Kredensial Admin hanya berada di notification worker VPS [KEPUTUSAN].
3. Listener hanya untuk node yang dibutuhkan layar aktif dan dilepas saat tidak dipakai [USULAN].
4. Project tetap Spark; notification worker memakai VPS yang sudah ada. Pantau biaya dan uptime VPS [KEPUTUSAN].
5. Penanganan koneksi putus dan keadaan kosong di setiap layar.

## 8. Aturan keamanan RTDB (langkah 1, node monitoring)

Akun perangkat sudah dibuat dan UID-nya dipakai di aturan berikut. Aturan `devices/status/last_seen` ditambahkan saat M3, `thresholds` saat M5, `ac_control` saat M6, serta `fcm_tokens`, `alert_state`, dan `alert_history` saat M7.

```json
{
  "rules": {
    ".read": false,
    ".write": false,
    "monitoring": {
      ".read": "auth != null",
      "latest": {
        ".write": "auth != null && auth.uid === 'VH3AIXTF47NIdjjdqNdRzMgGLQK2'",
        ".validate": "newData.hasChildren(['temperature', 'humidity', 'timestamp'])",
          "temperature": { ".validate": "newData.isNumber() && newData.val() >= -10 && newData.val() <= 60" },
        "humidity": { ".validate": "newData.isNumber() && newData.val() >= 0 && newData.val() <= 100" },
        "timestamp": { ".validate": "newData.isNumber()" },
        "$other": { ".validate": false }
      },
      "history": {
        "$ts": {
          ".write": "auth != null && auth.uid === 'VH3AIXTF47NIdjjdqNdRzMgGLQK2' && !data.exists()",
          ".validate": "newData.hasChildren(['temperature', 'humidity', 'timestamp'])",
        "temperature": { ".validate": "newData.isNumber() && newData.val() >= -10 && newData.val() <= 60" },
          "humidity": { ".validate": "newData.isNumber() && newData.val() >= 0 && newData.val() <= 100" },
          "timestamp": { ".validate": "newData.isNumber()" },
          "$other": { ".validate": false }
        }
      }
    }
  }
}
```

## 9. Teknologi dan struktur proyek

Mesin pengembangan MacBook Apple Silicon [KEPUTUSAN]. Aplikasi memakai Flutter 3.44.4 dengan package name Android `id.sppg.monitoring` [KEPUTUSAN]. Versi Android minimum API 33 (Android 13) [KEPUTUSAN].

Paket yang dipakai [KEPUTUSAN].

1. `firebase_core`, `firebase_auth`, `firebase_database`, `firebase_messaging`.
2. `flutter_local_notifications` untuk notifikasi saat aplikasi terbuka.
3. `fl_chart` untuk grafik. Format WIB dibuat di `core/time/` tanpa `intl`.
4. FlutterFire CLI untuk konfigurasi Firebase.
5. Notification worker Node.js di VPS memakai `firebase-admin` [KEPUTUSAN].

Struktur folder per fitur [KEPUTUSAN].

```
lib/
├── main.dart
├── app.dart
├── core/time/       (format WIB)
└── features/
    ├── auth/
    ├── dashboard/
    ├── history/
    ├── thresholds/
    ├── ac_control/
    ├── notifications/
    └── home/
```

Pengembangan dan pengujian klien memakai project Firebase asli pada emulator Android Pixel 8 [KEPUTUSAN]. Notifikasi otomatis dijalankan notification worker Node.js di VPS [KEPUTUSAN]. Sebelum alat tiba, data disuplai skrip simulator ESP32 terpisah yang menulis `latest` tiap 5 detik dan `history` tiap 30 menit [USULAN].

## 10. Rencana pengerjaan bertahap

Setiap milestone kecil, bisa diuji, dan harus lulus sebelum lanjut.

| Milestone | Isi | Selesai bila |
|---|---|---|
| M0 | Proyek Flutter dan koneksi Firebase | Aplikasi kosong berjalan di perangkat dan terhubung ke Firebase |
| M1 | Autentikasi (F1) | Login dan logout berfungsi dengan akun manual |
| M2 | Dashboard dengan simulator (F2) | Data tampil dan berubah otomatis |
| M3 | Deteksi offline (bagian F2) | Status berganti offline setelah 30 detik tanpa data |
| M4 | Riwayat dan grafik (F3) | Grafik menampilkan data simulator |
| M5 | Threshold (F4) | Nilai tersimpan dan validasi bekerja, aturan keamanan `thresholds` sudah ada |
| M6 | Kontrol AC (F5) | Perintah on/off, suhu, JET, dan Swing tercatat dan status mengikuti simulator, aturan keamanan `ac_control` sudah ada |
| M7 | Notifikasi (F6) | Pesan sampai di tiga kondisi aplikasi, notification worker VPS sudah berjalan |
| M8 | Uji terpadu dengan perangkat keras | Alur lengkap berjalan dengan ESP32 asli |

## 11. Kebutuhan pengujian skripsi

1. Selisih pembacaan sensor SHT31. Alat pembanding selain hygrometer manual SPPG belum ada.
2. Keberhasilan pengiriman data. Berhasil bila data diterima dan tersimpan di database.
3. Keberhasilan notifikasi. Berhasil bila notifikasi muncul di ponsel saat kondisi abnormal.
4. Waktu respons kendali AC diukur dengan stopwatch sampai status dipancarkan, tiap jenis perintah 10 kali, dengan bunyi bip AC sebagai indikator.
5. Pengujian lapangan 2 minggu (10 hari operasional, Senin sampai Jumat).

## 12. Risiko

1. Validasi suhu -10 sampai 60 pada aturan keamanan tetap menolak pembacaan di luar rentang tersebut; bila terjadi, `latest` berhenti diperbarui dan sistem tampak offline. Rentang ini dipilih agar pembacaan ekstrem tetap tercatat dan dapat memicu abnormal [KEPUTUSAN].
2. Jam ponsel yang keliru memengaruhi penilaian offline, karena itu gunakan server time offset.
3. ESP32 yang mengirim terlalu sering menambah pemakaian dan biaya.
4. Perintah AC usang bisa dieksekusi saat ESP32 kembali online.
5. Karena pendaftaran dimatikan, akun hilang atau terlupa harus dibuat ulang lewat console.

## 13. Daftar PERLU DIKONFIRMASI

1. Export CSV masih masuk cakupan atau tidak.
2. Kesesuaian dengan Use Case BAB III hasil revisi.