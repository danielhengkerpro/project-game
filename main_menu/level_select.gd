extends Node2D

# ==============================================================================
# HALAMAN PILIH LEVEL
# ==============================================================================

const MENU_PATH: String = "res://main_menu/main_menu.tscn"

var zoom_progress: float = 0.0
var anim_speed: float = 0.25
var spin_angle: float = 0.0
var spin_speed: float = 0.09
var zoom_direction: int = 1
var smooth_mouse_offset: Vector2 = Vector2.ZERO

var audio_player: AudioStreamPlayer
var audio_playback

func _ready() -> void:
	var tone: Array = MenuUI.create_tone_player(self)
	audio_player = tone[0]
	audio_playback = tone[1]
	_build()

# ------------------------------------------------------------------ latar belakang
func _process(delta: float) -> void:
	zoom_progress = fmod(zoom_progress + anim_speed * zoom_direction * delta + 4.0, 4.0)
	spin_angle = fmod(spin_angle + spin_speed * zoom_direction * delta + TAU, TAU)

	var vp: Vector2 = get_viewport_rect().size
	if vp.x > 0.0 and vp.y > 0.0:
		var m_pos: Vector2 = get_global_mouse_position()
		var target_off := Vector2.ZERO
		if is_finite(m_pos.x) and is_finite(m_pos.y) and absf(m_pos.x) <= vp.x * 2.0 and absf(m_pos.y) <= vp.y * 2.0:
			var norm_mouse: Vector2 = ((m_pos / vp) - Vector2(0.5, 0.5)).clamp(Vector2(-0.6, -0.6), Vector2(0.6, 0.6))
			target_off = norm_mouse * 72.0
		smooth_mouse_offset = smooth_mouse_offset.lerp(target_off, 6.0 * delta)

	queue_redraw()

func _draw() -> void:
	MenuUI.draw_recursive_bg(self, zoom_progress, smooth_mouse_offset, true, spin_angle)

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

func _is_level_completed(level_id: String) -> bool:
	if level_id == "tutorial":
		return false
	var done_idx: int = GameConfig._level_index(GameConfig.last_completed_id)
	var cur_idx: int = GameConfig._level_index(level_id)
	return done_idx >= 0 and cur_idx >= 0 and cur_idx <= done_idx

func _play(freq: float, dur: float) -> void:
	var vol: float = 0.0 if GameConfig.muted else GameConfig.sfx_volume
	MenuUI.play_tone(audio_playback, freq, dur, vol)

# ------------------------------------------------------------------ UI
func _build() -> void:
	var ui_layer := CanvasLayer.new()
	add_child(ui_layer)

	var margin := MarginContainer.new()
	margin.theme = MenuUI.create_menu_theme()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 56)
	margin.add_theme_constant_override("margin_right", 56)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 26)
	ui_layer.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	# --- Header ---
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 40)
	root.add_child(header)

	var back_btn := MenuUI.make_icon_pill_button("back", "KEMBALI", MenuUI.PALETTE["cream"])
	back_btn.pressed.connect(func():
		_play(329.63, 0.08)
		_go_back()
	)
	header.add_child(back_btn)

	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)

	var completed_count: int = 0
	var playable_total: int = 0
	for lv in GameConfig.levels:
		if lv["id"] != "tutorial":
			playable_total += 1
			if _is_level_completed(lv["id"]):
				completed_count += 1

	var counter := MenuUI.make_label(
		"%d / %d SELESAI" % [completed_count, playable_total],
		12,
		MenuUI.PALETTE["teal"],
		false,
		true
	)
	header.add_child(counter)

	# --- Judul ---
	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 2)
	root.add_child(title_box)

	title_box.add_child(MenuUI.make_label("Pilih Level", 40, MenuUI.PALETTE["cream"], true, false))
	title_box.add_child(MenuUI.make_label(
		"Selesaikan ruangan secara berurutan untuk membuka lapisan berikutnya.",
		14,
		MenuUI.PALETTE["text_muted"]
	))

	# --- Grid 2 kolom agar ringkas & rapi ---
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)

	var freqs: Array = [440.0, 493.88, 523.25, 587.33, 659.25]
	var idx: int = 0
	var num_level: int = 1

	for lv in GameConfig.levels:
		var level_id: String = lv["id"]
		var level_path: String = lv["path"]
		var level_sub: String = lv["subtitle"]
		var accent: Color = MenuUI.accent_color(lv["accent"])
		var freq: float = freqs[idx % freqs.size()]
		var exists: bool = ResourceLoader.exists(level_path)
		var unlocked: bool = _is_level_unlocked(idx)
		var completed: bool = _is_level_completed(level_id)

		var badge: String = "TUT" if level_id == "tutorial" else "%02d" % num_level
		if level_id != "tutorial":
			num_level += 1

		var status_text: String = level_sub
		var right_icon: String = "play"
		if not exists:
			status_text += "  •  Belum tersedia"
			right_icon = "lock"
		elif not unlocked:
			status_text = "Terkunci — selesaikan level sebelumnya"
			right_icon = "lock"
		elif completed:
			status_text += "  •  Selesai"
			right_icon = "check"

		var btn := MenuUI.make_menu_button(
			lv["title"],
			status_text,
			accent,
			"",
			badge,
			right_icon
		)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 68)
		btn.disabled = not exists or not unlocked
		if not btn.disabled:
			btn.mouse_entered.connect(func(): _play(freq, 0.06))
			btn.pressed.connect(func():
				_play(freq * 1.25, 0.12)
				if ResourceLoader.exists(level_path):
					get_tree().change_scene_to_file(level_path)
			)
		grid.add_child(btn)
		idx += 1

	# --- Footer ---
	var footer := HBoxContainer.new()
	root.add_child(footer)
	footer.add_child(MenuUI.make_label(
		"ESC untuk kembali ke menu",
		11,
		MenuUI.PALETTE["text_muted"],
		false,
		true
	))
