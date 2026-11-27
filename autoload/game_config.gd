extends Node

# ==============================================================================
# GAME CONFIG (Autoload)
# Menyimpan pengaturan yang dipakai lintas scene + daftar level yang bisa dimainkan.
# ==============================================================================

const SETTINGS_PATH: String = "user://settings.cfg"
const PROGRESS_PATH: String = "user://progress.json"
const PROGRESS_VERSION: int = 1

signal fullscreen_changed(value: bool)
signal settings_changed

var muted: bool = false
var sfx_volume: float = 0.85
var music_muted: bool = false
var music_volume: float = 0.35
var fullscreen: bool = false

# Id level terakhir yang diselesaikan. "" berarti belum ada progres.
var last_completed_id: String = ""

# Urutan di sini = urutan tampil di halaman "Pilih Level".
var levels: Array = [
	{
		"id": "tutorial",
		"title": "TUTORIAL",
		"subtitle": "Dasar: kotak & ruangan bersarang",
		"path": "res://tutor_bermain/cara_bermain.tscn",
		"accent": "yellow"
	},
	{
		"id": "level1",
		"title": "LEVEL 1",
		"subtitle": "Gua Kotak",
		"path": "res://level1/level1.tscn",
		"accent": "coral"
	},
	{
		"id": "level2",
		"title": "LEVEL 2",
		"subtitle": "Gua Bersarang",
		"path": "res://level2/level2.tscn",
		"accent": "teal"
	},
	{
		"id": "level3",
		"title": "LEVEL 3",
		"subtitle": "Lorong Dimensi",
		"path": "res://level3/level3.tscn",
		"accent": "purple"
	},
	{
		"id": "level4",
		"title": "LEVEL 4",
		"subtitle": "Dua Kotak Biru",
		"path": "res://level4/level4.tscn",
		"accent": "white"
	},
	{
		"id": "level5",
		"title": "LEVEL 5",
		"subtitle": "Paradoks Rekursif",
		"path": "res://level5/level5.tscn",
		"accent": "purple"
	},
	{
		"id": "level6",
		"title": "LEVEL 6",
		"subtitle": "Tiga Dimensi",
		"path": "res://level6/level6.tscn",
		"accent": "teal"
	},
	{
		"id": "level7",
		"title": "LEVEL 7",
		"subtitle": "Rantai Rekursi",
		"path": "res://level7/level7.tscn",
		"accent": "coral"
	},
	{
		"id": "level8",
		"title": "LEVEL 8",
		"subtitle": "Jembatan Paradoks",
		"path": "res://level8/level8.tscn",
		"accent": "yellow"
	},
	{
		"id": "level9",
		"title": "LEVEL 9",
		"subtitle": "Empat Dimensi",
		"path": "res://level9/level9.tscn",
		"accent": "teal"
	},
	{
		"id": "level10",
		"title": "LEVEL 10",
		"subtitle": "Puncak Rekursi (Final)",
		"path": "res://level10/level10.tscn",
		"accent": "coral"
	}
]

func _ready() -> void:
	load_settings()
	load_progress()

# Level pertama yang bukan tutorial.
func first_playable_level() -> Dictionary:
	for lv in levels:
		if lv["id"] != "tutorial":
			return lv
	return levels[0]

# ------------------------------------------------------------------ progres
func _level_index(id: String) -> int:
	for i in range(levels.size()):
		if levels[i]["id"] == id:
			return i
	return -1

# Level yang harus dibuka tombol "Mulai Bermain".
# Kosong berarti semua level yang terdaftar sudah selesai (placeholder "tamat").
func next_playable_level() -> Dictionary:
	var idx: int = _level_index(last_completed_id)
	if idx < 0:
		return first_playable_level()
	var next_idx: int = idx + 1
	while next_idx < levels.size():
		if levels[next_idx]["id"] != "tutorial":
			return levels[next_idx]
		next_idx += 1
	return {}

# Dipanggil tiap kali pemain menyelesaikan level. Hanya boleh maju, supaya
# mengulang tutorial tidak menimpa progres yang sudah lebih jauh.
func complete_level(id: String) -> void:
	var idx: int = _level_index(id)
	if idx < 0 or idx <= _level_index(last_completed_id):
		return
	last_completed_id = id
	_save_progress()

# Tulis file sementara dulu, simpan salinan lama sebagai .bak, lalu rename.
# Kalau crash di tengah tulis, loader masih punya file yang utuh.
func _save_progress() -> void:
	var tmp: String = PROGRESS_PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Gagal membuka file progres: %s" % error_string(FileAccess.get_open_error()))
		return
	var data := {"version": PROGRESS_VERSION, "last_completed": last_completed_id}
	f.store_string(JSON.stringify(data))
	f.close()
	if FileAccess.file_exists(PROGRESS_PATH):
		DirAccess.rename_absolute(PROGRESS_PATH, PROGRESS_PATH + ".bak")
	var err: Error = DirAccess.rename_absolute(tmp, PROGRESS_PATH)
	if err != OK:
		push_warning("Gagal menyimpan progres: %s" % error_string(err))

func load_progress() -> void:
	last_completed_id = ""
	for path in [PROGRESS_PATH, PROGRESS_PATH + ".bak"]:
		if not FileAccess.file_exists(path):
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary:
			continue
		var version: int = int(parsed.get("version", 0))
		if version > PROGRESS_VERSION:
			continue
		var id: String = str(parsed.get("last_completed", ""))
		if _level_index(id) >= 0:
			last_completed_id = id
			return

# ------------------------------------------------------------------ settings
func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	muted = bool(cfg.get_value("audio", "muted", muted))
	sfx_volume = float(cfg.get_value("audio", "sfx_volume", sfx_volume))
	music_muted = bool(cfg.get_value("audio", "music_muted", music_muted))
	music_volume = float(cfg.get_value("audio", "music_volume", music_volume))
	fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
	_apply_fullscreen()
	settings_changed.emit()

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "muted", muted)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "music_muted", music_muted)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.save(SETTINGS_PATH)
	settings_changed.emit()

func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply_fullscreen()
	save_settings()
	fullscreen_changed.emit(fullscreen)

func _apply_fullscreen() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

# F11 = pintasan layar penuh, dipakai kalau tombol di menu sulit diklik.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			set_fullscreen(not fullscreen)
			get_viewport().set_input_as_handled()
