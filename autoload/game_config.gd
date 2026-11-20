extends Node

# ==============================================================================
# GAME CONFIG (Autoload)
# Menyimpan pengaturan yang dipakai lintas scene + daftar level yang bisa dimainkan.
# ==============================================================================

const SETTINGS_PATH: String = "user://settings.cfg"

signal fullscreen_changed(value: bool)

var muted: bool = false
var sfx_volume: float = 0.85
var fullscreen: bool = false

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
	}
]

func _ready() -> void:
	load_settings()

# Level pertama yang bukan tutorial (dipakai tombol "Mulai Bermain").
func first_playable_level() -> Dictionary:
	for lv in levels:
		if lv["id"] != "tutorial":
			return lv
	return levels[0]

# ------------------------------------------------------------------ settings
func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	muted = bool(cfg.get_value("audio", "muted", muted))
	sfx_volume = float(cfg.get_value("audio", "sfx_volume", sfx_volume))
	fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
	_apply_fullscreen()

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "muted", muted)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.save(SETTINGS_PATH)

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
