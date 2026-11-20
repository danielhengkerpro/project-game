# Catatan untuk agen AI / pengembang lanjutan

Repo ini adalah proyek Godot 4.7 **PARABOX: REKURSI**. Nama repo/publik: `project-game`.
Baca file ini sebelum mengubah kode — terutama sebelum menambah level.

## Aturan tetap

- Semua teks UI dan komentar kode **harus bahasa Indonesia**.
- **Level 1 dan Level 2 sengaja punya skrip sendiri-sendiri** (`level1/level_1.gd`, `level2/level2.gd`). Jangan digabung jadi "core" bersama. Duplikasi di sini disengaja.
- Perbedaan visual antara level (hangat) dan menu/tutorial (gelap) juga disengaja. Jangan disamakan.
- Gerakan pemain hanya animasi slide halus. **Jangan menambah dash, kemampuan, atau kontrol baru.**
- Efek suara dibuat prosedural di `autoload/sfx.gd`. Tidak ada file audio; jangan menambah aset audio tanpa alasan.
- `addons/godot_ai/` wajib tetap ada: `project.godot` memuat autoload `_mcp_game_helper` dan plugin ini. Lisensinya MIT.

## Autosave / lanjut bermain

Progres disimpan di `user://progress.json` (bukan di `settings.cfg`) oleh autoload `GameConfig`:

- Format: `{"version": 1, "last_completed": "level1"}`. Hanya menyimpan **id level terakhir yang selesai**, bukan posisi pemain/kotak.
- Penulisan aman: tulis `progress.json.tmp`, pindahkan file lama ke `progress.json.bak`, lalu rename tmp ke `progress.json`. `load_progress()` mencoba file utama lalu `.bak`.
- `GameConfig.complete_level(id)` dipanggil dari `_check_win_condition()` di Level 1, Level 2, dan `check_win_condition()` di tutorial. Fungsi ini **hanya maju**: mengulang level lama tidak menurunkan progres.
- `GameConfig.next_playable_level()` dipakai tombol "Mulai Bermain" di `main_menu/main_menu.gd`.
  - Belum ada progres → Level 1.
  - Level 1 selesai → Level 2.
  - Semua level selesai → tombol berubah jadi **GAMENYA TAMAT** dan hanya menampilkan toast. Ini **placeholder**: ending belum ditentukan.
- Urutan progres = urutan elemen di `GameConfig.levels`. Jangan menganggap urutan array itu arbitrary.

## Checklist menambah level baru

Saat orang lain menambah Level 3 dan seterusnya, lakukan **semua** langkah ini:

1. Buat folder/scene level, misalnya `level3/level3.tscn` dengan skripnya sendiri. Ikuti pola `level2/level2.gd`; jangan refactor Level 1/2.
2. Daftarkan di `autoload/game_config.gd` pada array `levels`, **di urutan yang benar**:
   ```gdscript
   {
       "id": "level3",
       "title": "LEVEL 3",
       "subtitle": "Judul level",
       "path": "res://level3/level3.tscn",
       "accent": "yellow"
   }
   ```
   `id` harus unik. `accent` salah satu dari palet `MenuUI` (`yellow`, `coral`, `teal`, `purple`).
3. Di fungsi menang level baru, panggil `GameConfig.complete_level("level3")`. Tanpa ini, progres tidak tersimpan dan tombol "Mulai Bermain" tidak akan lanjut ke level berikutnya.
4. **Tidak perlu menyentuh `main_menu/main_menu.gd`.** Tombol otomatis membaca `next_playable_level()`. Kalau Level 3 masuk ke daftar `levels`, tombol "GAMENYA TAMAT" otomatis berubah jadi "Lanjut ke LEVEL 3".
5. Halaman "Pilih Level" juga otomatis menampilkan level baru dari `GameConfig.levels`.
6. Kalau kamu **mengubah urutan atau mengganti id** level yang sudah rilis, naikkan `PROGRESS_VERSION` dan tambahkan migrasi di `GameConfig.load_progress()` (misalnya memetakan id lama ke id baru). Jangan diam-diam membuang save lama.

## Cara cek cepat

- Buka proyek di Godot 4.7, tekan F5, selesaikan Level 1, keluar ke menu, tekan "Mulai Bermain" → harus masuk Level 2.
- Ulangi setelah Level 2 → tombol harus bertuliskan "GAMENYA TAMAT".
- Cek file `user://progress.json` dibuat dan `.bak` muncul setelah menyelesaikan level kedua.
- Verifikasi headless: jalankan scene dengan `godot --headless --path . --quit-after 2 res://main_menu/main_menu.tscn`. Ingat: `--script` tidak melihat autoload, jadi pakai scene, bukan skrip mentah.

## Sejarah singkat

- `level1` = "Gua Kotak", `level2` = "Gua Bersarang". Target pemain `P` Level 2 ada di ruang `outer` (1,1) supaya pemain keluar dari kotak sebelum menang.
- Solusi referensi: Level 1 49 langkah, Level 2 54 langkah.
- Tombol "Mulai Bermain" dulu memanggil `first_playable_level()`; sekarang memakai progres. Jangan kembalikan ke perilaku lama.
