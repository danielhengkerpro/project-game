# PARABOX: REKURSI

Puzzle kotak-dalam-kotak. Kamu menggeser kotak, dan kotak itu punya ruangan sendiri di dalamnya — masuk ke dalam kotak berarti pindah ke ruangan lain, dan posisimu di ruangan lama tetap tersimpan.

Dibuat dengan **Godot 4.7** (GDScript, renderer GL Compatibility).

## Cara Main

- **WASD / Panah** — geser pemain
- **Z / Backspace** — undo
- **R** — reset level
- **ESC** — kembali ke menu
- **Enter / Spasi** — lanjut (di layar menang)
- **F11** — layar penuh

Tujuan tiap level: tutup semua lubang tujuan (`G`) dengan kotak, lalu berdiri di atas penanda pemain (`P`).

## Isi Proyek

| Folder | Keterangan |
| --- | --- |
| `main_menu/` | Menu utama, pilih level, pengaturan |
| `tutor_bermain/` | Tutorial interaktif |
| `level1/` | Level 1 — "Gua Kotak" |
| `level2/` | Level 2 — "Gua Bersarang" |
| `autoload/` | `GameConfig` (pengaturan & daftar level) dan `Sfx` (efek suara prosedural) |
| `asset/` | Sprite sheet mentah |
| `addons/godot_ai/` | Plugin Godot AI (MIT), dipakai autoload `_mcp_game_helper` |

Level 1 dan Level 2 sengaja tidak berbagi core logic — masing-masing punya skrip sendiri supaya bisa diubah bebas tanpa saling merusak.

Semua efek suara dibuat langsung di kode (tidak ada file audio), jadi repo ini ringan.

## Menjalankan

1. Unduh **Godot 4.7** (versi standard, bukan .NET).
2. Buka folder proyek ini lewat Godot Project Manager, atau dari terminal:

   ```bash
   godot --path .
   ```

3. Tekan **F5** untuk mulai dari menu utama.

Proyek langsung bisa dijalankan tanpa setup tambahan. Folder `.godot/` (cache impor) tidak ikut di-commit dan akan dibuat ulang otomatis oleh Godot.

## Ekspor

`export_presets.cfg` sudah berisi preset **Windows Desktop**. Butuh export template Godot 4.7 yang sesuai.

## Lisensi

Kode game di repo ini bebas dipakai untuk belajar. Plugin `addons/godot_ai/` adalah proyek pihak ketiga dengan lisensi MIT — lihat `addons/godot_ai/LICENSE`.
