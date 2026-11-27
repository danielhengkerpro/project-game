extends Node2D

# ==============================================================================
# HALAMAN PENGATURAN
# Semua perubahan langsung disimpan lewat autoload GameConfig.
# ==============================================================================

const MENU_PATH: String = "res://main_menu/main_menu.tscn"

var zoom_progress: float = 0.0
var anim_speed: float = 0.25
var zoom_direction: int = 1
var smooth_mouse_offset: Vector2 = Vector2.ZERO

var audio_player: AudioStreamPlayer
var audio_playback

func _ready() -> void:
	var tone: Array = MenuUI.create_tone_player(self)
	audio_player = tone[0]
	audio_playback = tone[1]
	_build()

# ------------------------------------------------------------------ background
func _process(delta: float) -> void:
	zoom_progress = fmod(zoom_progress + anim_speed * zoom_direction * delta + 1.0, 1.0)

	var vp: Vector2 = get_viewport_rect().size
	if vp.x > 0.0 and vp.y > 0.0:
		var norm_mouse: Vector2 = (get_global_mouse_position() / vp) - Vector2(0.5, 0.5)
		smooth_mouse_offset = smooth_mouse_offset.lerp(norm_mouse * 90.0, 6.0 * delta)

	queue_redraw()

func _draw() -> void:
	MenuUI.draw_recursive_bg(self, zoom_progress, smooth_mouse_offset)

# ------------------------------------------------------------------ input
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_go_back()

func _go_back() -> void:
	if ResourceLoader.exists(MENU_PATH):
		get_tree().change_scene_to_file(MENU_PATH)

func _play(freq: float, dur: float) -> void:
	var vol: float = 0.0 if GameConfig.muted else GameConfig.sfx_volume
	MenuUI.play_tone(audio_playback, freq, dur, vol)

# Baris pengaturan: label ikut bisa diklik, toggle-nya sedikit diperbesar.
func _siapkan_baris(label: Label, chk: CheckButton) -> void:
	chk.custom_minimum_size = Vector2(52, 28)
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	label.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT:
			chk.button_pressed = not chk.button_pressed
	)

# ------------------------------------------------------------------ UI
func _build() -> void:
	var ui_layer := CanvasLayer.new()
	add_child(ui_layer)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 56)
	margin.add_theme_constant_override("margin_right", 56)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 28)
	ui_layer.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	# --- Header ---
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 40)
	root.add_child(header)

	var back_btn := Button.new()
	back_btn.text = "  ◀  KEMBALI  "
	back_btn.add_theme_font_size_override("font_size", 13)
	back_btn.pressed.connect(func():
		_play(329.63, 0.08)
		_go_back()
	)
	header.add_child(back_btn)

	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)

	root.add_child(MenuUI.make_label("PENGATURAN", 40, MenuUI.PALETTE["text_main"]))
	root.add_child(MenuUI.make_label(
		"Perubahan langsung tersimpan.",
		15,
		MenuUI.PALETTE["text_muted"]
	))

	# --- Panel isi ---
	var panel := MenuUI.make_panel()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(panel)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 24)
	panel.add_child(rows)

	# --- Suara on/off ---
	var sound_row := HBoxContainer.new()
	rows.add_child(sound_row)

	var sound_lbl := MenuUI.make_label("Suara", 16, MenuUI.PALETTE["text_main"])
	sound_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sound_row.add_child(sound_lbl)

	var sound_chk := CheckButton.new()
	sound_chk.button_pressed = not GameConfig.muted
	sound_chk.toggled.connect(func(on: bool):
		GameConfig.muted = not on
		GameConfig.save_settings()
		if on:
			_play(523.25, 0.1)
	)
	sound_row.add_child(sound_chk)
	_siapkan_baris(sound_lbl, sound_chk)

	# --- Volume SFX ---
	var vol_row := HBoxContainer.new()
	vol_row.add_theme_constant_override("separation", 14)
	rows.add_child(vol_row)

	var vol_lbl := MenuUI.make_label("Volume SFX", 16, MenuUI.PALETTE["text_main"])
	vol_lbl.custom_minimum_size = Vector2(140, 0)
	vol_row.add_child(vol_lbl)

	var vol_value := MenuUI.make_label(
		"%d%%" % int(round(GameConfig.sfx_volume * 100.0)),
		15,
		MenuUI.PALETTE["teal"]
	)
	vol_value.custom_minimum_size = Vector2(56, 0)
	vol_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var vol_slider := HSlider.new()
	vol_slider.min_value = 0.0
	vol_slider.max_value = 100.0
	vol_slider.step = 1.0
	vol_slider.value = GameConfig.sfx_volume * 100.0
	vol_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vol_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vol_slider.custom_minimum_size = Vector2(0, 24)
	vol_slider.value_changed.connect(func(v: float):
		GameConfig.sfx_volume = v / 100.0
		vol_value.text = "%d%%" % int(round(v))
		GameConfig.save_settings()
	)
	vol_row.add_child(vol_slider)
	vol_row.add_child(vol_value)

	# --- Musik latar on/off ---
	var music_row := HBoxContainer.new()
	rows.add_child(music_row)

	var music_lbl := MenuUI.make_label("Musik Latar", 16, MenuUI.PALETTE["text_main"])
	music_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_row.add_child(music_lbl)

	var music_chk := CheckButton.new()
	music_chk.button_pressed = not GameConfig.music_muted
	music_chk.toggled.connect(func(on: bool):
		GameConfig.music_muted = not on
		GameConfig.save_settings()
	)
	music_row.add_child(music_chk)
	_siapkan_baris(music_lbl, music_chk)

	# --- Volume musik latar ---
	var music_vol_row := HBoxContainer.new()
	music_vol_row.add_theme_constant_override("separation", 14)
	rows.add_child(music_vol_row)

	var music_vol_lbl := MenuUI.make_label("Volume Musik", 16, MenuUI.PALETTE["text_main"])
	music_vol_lbl.custom_minimum_size = Vector2(140, 0)
	music_vol_row.add_child(music_vol_lbl)

	var music_vol_value := MenuUI.make_label(
		"%d%%" % int(round(GameConfig.music_volume * 100.0)),
		15,
		MenuUI.PALETTE["teal"]
	)
	music_vol_value.custom_minimum_size = Vector2(56, 0)
	music_vol_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var music_vol_slider := HSlider.new()
	music_vol_slider.min_value = 0.0
	music_vol_slider.max_value = 100.0
	music_vol_slider.step = 1.0
	music_vol_slider.value = GameConfig.music_volume * 100.0
	music_vol_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_vol_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	music_vol_slider.custom_minimum_size = Vector2(0, 24)
	music_vol_slider.value_changed.connect(func(v: float):
		GameConfig.music_volume = v / 100.0
		music_vol_value.text = "%d%%" % int(round(v))
		GameConfig.save_settings()
	)
	music_vol_row.add_child(music_vol_slider)
	music_vol_row.add_child(music_vol_value)

	# --- Layar penuh ---
	var fs_row := HBoxContainer.new()
	rows.add_child(fs_row)

	var fs_lbl := MenuUI.make_label("Layar Penuh", 16, MenuUI.PALETTE["text_main"])
	fs_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fs_row.add_child(fs_lbl)

	var fs_chk := CheckButton.new()
	fs_chk.button_pressed = GameConfig.fullscreen
	fs_chk.toggled.connect(func(on: bool):
		GameConfig.set_fullscreen(on)
		_play(587.33, 0.08)
	)
	fs_row.add_child(fs_chk)
	_siapkan_baris(fs_lbl, fs_chk)
	GameConfig.fullscreen_changed.connect(func(on: bool):
		if is_instance_valid(fs_chk):
			fs_chk.set_pressed_no_signal(on)
	)

	# --- Footer ---
	var footer := HBoxContainer.new()
	root.add_child(footer)
	footer.add_child(MenuUI.make_label(
		"ESC untuk kembali ke menu",
		12,
		MenuUI.PALETTE["text_muted"]
	))
