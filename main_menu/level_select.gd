extends Node2D

# ==============================================================================
# HALAMAN PILIH LEVEL
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

func _is_level_unlocked(index: int) -> bool:
	if index == 0:
		return true
	var level_id: String = GameConfig.levels[index]["id"]
	if level_id == "tutorial":
		return true
	var previous_id: String = GameConfig.levels[index - 1]["id"]
	if previous_id == "tutorial":
		return true
	return GameConfig._level_index(previous_id) <= GameConfig._level_index(GameConfig.last_completed_id)

func _play(freq: float, dur: float) -> void:
	var vol: float = 0.0 if GameConfig.muted else GameConfig.sfx_volume
	MenuUI.play_tone(audio_playback, freq, dur, vol)

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

	var counter := MenuUI.make_label(
		"%d LEVEL" % GameConfig.levels.size(),
		12,
		MenuUI.PALETTE["teal"]
	)
	header.add_child(counter)

	# --- Judul ---
	root.add_child(MenuUI.make_label("PILIH LEVEL", 40, MenuUI.PALETTE["text_main"]))
	root.add_child(MenuUI.make_label(
		"Pilih ruangan yang mau kamu pecahkan.",
		15,
		MenuUI.PALETTE["text_muted"]
	))

	# --- Daftar level ---
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)

	var freqs: Array = [440.0, 493.88, 523.25, 587.33, 659.25]
	var idx: int = 0

	for lv in GameConfig.levels:
		var level_path: String = lv["path"]
		var level_title: String = lv["title"]
		var level_sub: String = lv["subtitle"]
		var accent: Color = MenuUI.accent_color(lv["accent"])
		var freq: float = freqs[idx % freqs.size()]
		var exists: bool = ResourceLoader.exists(level_path)
		var unlocked: bool = _is_level_unlocked(idx)

		if not exists:
			level_sub += "   (scene belum ada)"

		var btn := MenuUI.make_menu_button(level_title, level_sub, accent)
		btn.disabled = not exists or not unlocked
		btn.mouse_entered.connect(func(): _play(freq, 0.06))
		btn.pressed.connect(func():
			_play(freq * 1.25, 0.12)
			if ResourceLoader.exists(level_path):
				get_tree().change_scene_to_file(level_path)
		)
		list.add_child(btn)
		idx += 1

	# --- Footer ---
	var footer := HBoxContainer.new()
	root.add_child(footer)
	footer.add_child(MenuUI.make_label(
		"ESC untuk kembali ke menu",
		12,
		MenuUI.PALETTE["text_muted"]
	))
