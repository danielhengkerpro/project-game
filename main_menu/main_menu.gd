extends Node2D

# ==============================================================================
# 1. PALET WARNA & KONFIGURASI SCENE TUJUAN
# ==============================================================================
var colors = {
	"bg_dark": Color("#12141d"),
	"bg_panel": Color("#1a1d2b"),
	"coral": Color("#ff6b6b"),
	"teal": Color("#4ecdc4"),
	"yellow": Color("#ffe66d"),
	"purple": Color("#a29bfe"),
	"text_main": Color("#f1f2f6"),
	"text_muted": Color("#8395a7")
}

# Path halaman menu. "mulai bermain" memakai level pertama dari GameConfig.
var target_scenes := {
	"level_select": "res://main_menu/level_select.tscn",
	"how_to_play": "res://tutor_bermain/cara_bermain.tscn",
	"settings": "res://main_menu/settings.tscn"
}

var last_level_label: String = "Mulai dari Level 1"

# Variabel Animasi Latar Rekursi
var zoom_progress: float = 0.0
var anim_speed: float = 0.25
var zoom_direction: int = 1
var smooth_mouse_offset: Vector2 = Vector2.ZERO

# Variabel Audio Procedural
var audio_player: AudioStreamPlayer
var audio_playback: AudioStreamGeneratorPlayback
var is_muted: bool = false
var sfx_volume: float = 0.85

# UI Layer & Toast Notifikasi
var ui_layer: CanvasLayer
var toast_label: Label
var toast_panel: PanelContainer

func _ready() -> void:
	is_muted = GameConfig.muted
	sfx_volume = GameConfig.sfx_volume
	last_level_label = "Mulai dari " + str(GameConfig.first_playable_level()["title"])
	_setup_audio()
	_build_main_menu()

# ==============================================================================
# 2. RENDER LATAR BELAKANG REKURSI TAK TERBATAS (_draw di Node2D)
# ==============================================================================
func _process(delta: float) -> void:
	zoom_progress = fmod(zoom_progress + anim_speed * zoom_direction * delta + 1.0, 1.0)
	
	var viewport_size = get_viewport_rect().size
	if viewport_size.x > 0 and viewport_size.y > 0:
		var norm_mouse = (get_global_mouse_position() / viewport_size) - Vector2(0.5, 0.5)
		var target_offset = norm_mouse * 90.0
		smooth_mouse_offset = smooth_mouse_offset.lerp(target_offset, 6.0 * delta)
	
	queue_redraw()

func _draw() -> void:
	var vp_size = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp_size), colors["bg_dark"], true)
	
	var center = Vector2(vp_size.x * 0.68, vp_size.y * 0.5) + smooth_mouse_offset
	var total_layers = 11
	var max_dim = max(vp_size.x, vp_size.y) * 1.65
	var scale_factor = 0.56
	var palette = [colors["coral"], colors["teal"], colors["yellow"], colors["purple"]]
	
	for i in range(total_layers - 1, -1, -1):
		var effective_idx = float(i) - zoom_progress
		var box_size = max_dim * pow(scale_factor, effective_idx)
		
		if box_size < 4.0:
			continue
			
		var col: Color = palette[i % palette.size()]
		var alpha = clamp((box_size / max_dim) * 1.4, 0.08, 1.0)
		var angle = (effective_idx * 0.08) + sin(zoom_progress * TAU) * 0.02
		
		draw_set_transform(center, angle, Vector2.ONE)
		
		var half = box_size / 2.0
		var rect = Rect2(Vector2(-half, -half), Vector2(box_size, box_size))
		
		var fill_col = col
		fill_col.a = 0.04 * alpha
		draw_rect(rect, fill_col, true)
		
		var border_col = col
		border_col.a = alpha
		var line_w = max(1.5, box_size * 0.012)
		draw_rect(rect, border_col, false, line_w)
		
		# Celah masuk di sisi kiri kotak
		var entrance_h = box_size * 0.24
		var notch_rect = Rect2(Vector2(-half - line_w, -entrance_h / 2.0), Vector2(line_w * 2.5, entrance_h))
		draw_rect(notch_rect, colors["bg_dark"], true)
		
		if box_size > 160.0:
			var grid_col = Color(1, 1, 1, 0.04 * alpha)
			var step = box_size / 4.0
			for g in range(-1, 2):
				draw_line(Vector2(g * step, -half), Vector2(g * step, half), grid_col, 1.0)
				draw_line(Vector2(-half, g * step), Vector2(half, g * step), grid_col, 1.0)
	
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ==============================================================================
# 3. PEMBANGUNAN UI MAIN MENU (Via CanvasLayer agar pas di Node2D)
# ==============================================================================
func _build_main_menu() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 56)
	margin.add_theme_constant_override("margin_right", 56)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 28)
	ui_layer.add_child(margin)
	
	var root_vbox = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 24)
	margin.add_child(root_vbox)
	
	# --- TOP BAR ---
	var top_bar = HBoxContainer.new()
	top_bar.custom_minimum_size = Vector2(0, 40)
	root_vbox.add_child(top_bar)
	
	top_bar.add_child(_create_pill_label("● KEDALAMAN: ∞", colors["teal"]))
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)
	
	var top_actions = HBoxContainer.new()
	top_actions.add_theme_constant_override("separation", 10)
	top_bar.add_child(top_actions)
	
	var dir_btn = _create_top_button("↻ ARAH REKURSI")
	dir_btn.pressed.connect(func():
		zoom_direction *= -1
		_play_tone(620.0, 0.1)
		_show_toast("Arah Rekursi: Masuk ke Dalam" if zoom_direction == 1 else "Arah Rekursi: Keluar Ruang")
	)
	top_actions.add_child(dir_btn)
	
	var mute_btn = _create_top_button("🔊 SUARA: ON" if not is_muted else "🔇 SUARA: OFF")
	mute_btn.pressed.connect(func():
		is_muted = !is_muted
		GameConfig.muted = is_muted
		GameConfig.save_settings()
		mute_btn.text = "🔇 SUARA: OFF" if is_muted else "🔊 SUARA: ON"
		if not is_muted: _play_tone(523.25, 0.1)
	)
	top_actions.add_child(mute_btn)
	
	# --- KONTEN TENGAH (JUDUL & TOMBOL NAVIGASI) ---
	var center_box = VBoxContainer.new()
	center_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_box.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_child(center_box)
	
	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 36)
	center_box.add_child(content_vbox)
	
	var title_box = VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 8)
	content_vbox.add_child(title_box)
	
	var edition_lbl = Label.new()
	edition_lbl.text = "[ EDISI PARADOKS ]"
	edition_lbl.add_theme_color_override("font_color", colors["purple"])
	edition_lbl.add_theme_font_size_override("font_size", 13)
	title_box.add_child(edition_lbl)
	
	var title_lbl = Label.new()
	title_lbl.text = "PARABOX: REKURSI"
	title_lbl.add_theme_color_override("font_color", colors["text_main"])
	title_lbl.add_theme_font_size_override("font_size", 54)
	title_box.add_child(title_lbl)
	
	var sub_lbl = Label.new()
	sub_lbl.text = "Dorong kotak ke dalam dirinya sendiri. Pecahkan ruang & logika."
	sub_lbl.add_theme_color_override("font_color", colors["text_muted"])
	sub_lbl.add_theme_font_size_override("font_size", 15)
	title_box.add_child(sub_lbl)
	
	# Daftar Tombol Menu Utama
	var nav_vbox = VBoxContainer.new()
	nav_vbox.custom_minimum_size = Vector2(400, 0)
	nav_vbox.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	nav_vbox.add_theme_constant_override("separation", 12)
	content_vbox.add_child(nav_vbox)
	
	_add_menu_button(nav_vbox, "▶  MULAI BERMAIN", last_level_label, colors["coral"], 440.0, func():
		_go_to_scene(str(GameConfig.first_playable_level()["path"]), "Memuat Level...")
	)
	
	_add_menu_button(nav_vbox, "⊞  PILIH LEVEL", "", colors["teal"], 523.25, func():
		_go_to_scene(target_scenes["level_select"], "Membuka Halaman Pilih Level...")
	)
	
	_add_menu_button(nav_vbox, "?   CARA BERMAIN", "", colors["yellow"], 587.33, func():
		_go_to_scene(target_scenes["how_to_play"], "Membuka Tutorial Bermain...")
	)
	
	_add_menu_button(nav_vbox, "⚙  PENGATURAN", "", colors["purple"], 659.25, func():
		_go_to_scene(target_scenes["settings"], "Membuka Halaman Pengaturan...")
	)
	
	_add_menu_button(nav_vbox, "✕   KELUAR", "", colors["text_muted"], 329.63, func():
		get_tree().quit()
	)
	
	# --- FOOTER ---
	var footer = HBoxContainer.new()
	root_vbox.add_child(footer)
	var ver_lbl = Label.new()
	ver_lbl.text = "VERSI 1.0.4 • GODOT 4 ENGINE"
	ver_lbl.add_theme_color_override("font_color", colors["text_muted"])
	ver_lbl.add_theme_font_size_override("font_size", 12)
	footer.add_child(ver_lbl)
	
	_build_toast()

# ==============================================================================
# 4. PERPINDAHAN SCENE & HELPER UI
# ==============================================================================
func _go_to_scene(scene_path: String, fallback_msg: String) -> void:
	if ResourceLoader.exists(scene_path):
		get_tree().change_scene_to_file(scene_path)
	else:
		_show_toast("%s (Scene '%s' belum dibuat)" % [fallback_msg, scene_path])

func _add_menu_button(parent: Control, title: String, subtitle: String, accent: Color, hover_freq: float, callback: Callable) -> void:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 64 if subtitle != "" else 52)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.text = "   " + title + ("\n      " + subtitle if subtitle != "" else "")
	btn.add_theme_font_size_override("font_size", 17)
	btn.add_theme_color_override("font_color", colors["text_main"])
	btn.add_theme_color_override("font_hover_color", accent)
	
	var normal_sb = StyleBoxFlat.new()
	normal_sb.bg_color = Color(colors["bg_panel"], 0.88)
	normal_sb.border_width_left = 4
	normal_sb.border_width_top = 1
	normal_sb.border_width_right = 1
	normal_sb.border_width_bottom = 1
	normal_sb.border_color = Color(1, 1, 1, 0.12)
	normal_sb.set_corner_radius_all(10)
	
	var hover_sb = normal_sb.duplicate()
	hover_sb.bg_color = Color(accent, 0.16)
	hover_sb.border_color = accent
	hover_sb.border_width_left = 8
	
	btn.add_theme_stylebox_override("normal", normal_sb)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("pressed", hover_sb)
	
	btn.mouse_entered.connect(func(): _play_tone(hover_freq, 0.06))
	btn.pressed.connect(func():
		_play_tone(hover_freq * 1.25, 0.12)
		callback.call()
	)
	parent.add_child(btn)

func _create_pill_label(txt: String, col: Color) -> PanelContainer:
	var pc = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(colors["bg_panel"], 0.85)
	sb.border_color = Color(1, 1, 1, 0.15)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	pc.add_theme_stylebox_override("panel", sb)
	var lbl = Label.new()
	lbl.text = txt
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_font_size_override("font_size", 12)
	pc.add_child(lbl)
	return pc

func _create_top_button(txt: String) -> Button:
	var b = Button.new()
	b.text = "  " + txt + "  "
	b.add_theme_font_size_override("font_size", 12)
	return b

func _build_toast() -> void:
	toast_panel = PanelContainer.new()
	toast_panel.visible = false
	toast_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast_panel.position.y -= 60
	var t_sb = StyleBoxFlat.new()
	t_sb.bg_color = colors["bg_panel"]
	t_sb.border_color = colors["teal"]
	t_sb.set_border_width_all(2)
	t_sb.set_corner_radius_all(8)
	t_sb.set_content_margin_all(12)
	toast_panel.add_theme_stylebox_override("panel", t_sb)
	
	toast_label = Label.new()
	toast_label.add_theme_color_override("font_color", colors["text_main"])
	toast_panel.add_child(toast_label)
	ui_layer.add_child(toast_panel)

func _show_toast(msg: String) -> void:
	toast_label.text = msg
	toast_panel.visible = true
	await get_tree().create_timer(2.4).timeout
	if is_instance_valid(toast_panel):
		toast_panel.visible = false

# ==============================================================================
# 5. AUDIO SYNTHESIZER
# ==============================================================================
func _setup_audio() -> void:
	audio_player = AudioStreamPlayer.new()
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.1
	audio_player.stream = gen
	add_child(audio_player)
	audio_player.play()
	audio_playback = audio_player.get_stream_playback()

func _play_tone(freq: float, duration: float) -> void:
	if is_muted or sfx_volume <= 0.0 or audio_playback == null:
		return
	var sample_rate = 22050.0
	var frames = int(sample_rate * duration)
	var phase = 0.0
	var increment = freq / sample_rate
	for i in range(frames):
		if audio_playback.get_frames_available() <= 0:
			break
		var env = (1.0 - float(i) / frames) * 0.15 * sfx_volume
		var sample = sin(phase * TAU) * env
		audio_playback.push_frame(Vector2(sample, sample))
		phase = fmod(phase + increment, 1.0)
