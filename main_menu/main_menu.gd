extends Node2D

# ==============================================================================
# MENU UTAMA - PARABOX REQUIEM
# ==============================================================================

var target_scenes := {
	"level_select": "res://main_menu/level_select.tscn",
	"how_to_play": "res://tutor_bermain/cara_bermain.tscn",
	"settings": "res://main_menu/settings.tscn"
}

var next_level: Dictionary = {}
var start_button_title: String = "MULAI BERMAIN"
var start_button_sub: String = "Mulai dari Level 1"

var zoom_progress: float = 0.0
var anim_speed: float = 0.25
var spin_angle: float = 0.0
var spin_speed: float = 0.09
var zoom_direction: int = 1
var smooth_mouse_offset: Vector2 = Vector2.ZERO

var audio_player: AudioStreamPlayer
var audio_playback

var ui_layer: CanvasLayer
var toast_label: Label
var toast_panel: PanelContainer

func _ready() -> void:
	next_level = GameConfig.next_playable_level()
	if next_level.is_empty():
		start_button_title = "GAMENYA TAMAT"
		start_button_sub = "Semua 10 level telah diselesaikan"
	else:
		var awalan: String = "Lanjut ke " if GameConfig.last_completed_id != "" else "Mulai dari "
		start_button_sub = awalan + str(next_level["title"])
	var tone: Array = MenuUI.create_tone_player(self)
	audio_player = tone[0]
	audio_playback = tone[1]
	_build_main_menu()

# ==============================================================================
# LATAR BELAKANG TAKTIL REKURSIF
# ==============================================================================
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
	MenuUI.draw_recursive_bg(self, zoom_progress, smooth_mouse_offset, false, spin_angle)

# ==============================================================================
# PEMBANGUNAN UI MENU UTAMA
# ==============================================================================
func _build_main_menu() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)

	var margin := MarginContainer.new()
	margin.theme = MenuUI.create_menu_theme()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_right", 52)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 26)
	ui_layer.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 20)
	margin.add_child(root_vbox)

	# --- Baris Atas ---
	var top_bar := HBoxContainer.new()
	top_bar.custom_minimum_size = Vector2(0, 40)
	root_vbox.add_child(top_bar)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	var top_actions := HBoxContainer.new()
	top_actions.add_theme_constant_override("separation", 10)
	top_bar.add_child(top_actions)

	var dir_btn := MenuUI.make_icon_pill_button("loop", "ARAH", MenuUI.PALETTE["yellow"])
	dir_btn.pressed.connect(func():
		zoom_direction *= -1
		_play(620.0, 0.1)
		_show_toast("Arah Rekursi: Masuk ke Dalam" if zoom_direction == 1 else "Arah Rekursi: Keluar Ruang")
	)
	top_actions.add_child(dir_btn)

	var mute_btn := MenuUI.make_icon_pill_button(
		"sound_off" if GameConfig.muted else "sound_on",
		"SUARA: OFF" if GameConfig.muted else "SUARA: ON",
		MenuUI.PALETTE["teal"]
	)
	mute_btn.pressed.connect(func():
		GameConfig.muted = !GameConfig.muted
		GameConfig.save_settings()
		var ic := mute_btn.get_meta("icon_node") as MenuUI.MenuIcon
		var lbl := mute_btn.get_meta("label_node") as Label
		if ic != null:
			ic.icon_name = "sound_off" if GameConfig.muted else "sound_on"
			ic.queue_redraw()
		if lbl != null:
			lbl.text = "SUARA: OFF" if GameConfig.muted else "SUARA: ON"
		if not GameConfig.muted:
			_play(523.25, 0.1)
	)
	top_actions.add_child(mute_btn)

	# --- Konten Tengah (Logo & Tombol Navigasi) ---
	var center_box := VBoxContainer.new()
	center_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_box.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_child(center_box)

	var content_vbox := VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 30)
	center_box.add_child(content_vbox)

	# Header Judul dengan Emblem Kotak Parabox
	var brand_row := HBoxContainer.new()
	brand_row.add_theme_constant_override("separation", 18)
	content_vbox.add_child(brand_row)

	var emblem := BrandEmblem.new()
	emblem.custom_minimum_size = Vector2(64, 64)
	emblem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brand_row.add_child(emblem)

	var title_col := VBoxContainer.new()
	title_col.add_theme_constant_override("separation", 0)
	title_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brand_row.add_child(title_col)

	var title_lbl := MenuUI.make_label("PARABOX", 54, MenuUI.PALETTE["cream"], true, false)
	title_col.add_child(title_lbl)

	var sub_title := MenuUI.make_label("REQUIEM", 19, MenuUI.PALETTE["purple"], false, true)
	title_col.add_child(sub_title)

	var tagline := MenuUI.make_label(
		"Dorong kotak ke dalam dirinya sendiri. Pecahkan ruang dan logika.",
		15,
		MenuUI.PALETTE["text_muted"]
	)
	content_vbox.add_child(tagline)

	# Daftar Tombol Navigasi
	var nav_vbox := VBoxContainer.new()
	nav_vbox.custom_minimum_size = Vector2(400, 0)
	nav_vbox.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	nav_vbox.add_theme_constant_override("separation", 11)
	content_vbox.add_child(nav_vbox)

	var start_icon := "star" if next_level.is_empty() else "play"
	var start_btn := MenuUI.make_primary_button(start_button_title, start_button_sub, start_icon)
	start_btn.mouse_entered.connect(func(): _play(440.0, 0.06))
	start_btn.pressed.connect(func():
		_play(550.0, 0.12)
		if next_level.is_empty():
			_show_toast("Selamat! Kamu telah menamatkan seluruh 10 level PARABOX REQUIEM!")
			return
		_go_to_scene(str(next_level["path"]), "Memuat Level...")
	)
	nav_vbox.add_child(start_btn)

	_add_nav_button(nav_vbox, "Pilih Level", "", MenuUI.PALETTE["teal"], "grid", 523.25, func():
		_go_to_scene(target_scenes["level_select"], "Membuka Halaman Pilih Level...")
	)
	_add_nav_button(nav_vbox, "Cara Bermain", "", MenuUI.PALETTE["yellow"], "help", 587.33, func():
		_go_to_scene(target_scenes["how_to_play"], "Membuka Tutorial Bermain...")
	)
	_add_nav_button(nav_vbox, "Pengaturan", "", MenuUI.PALETTE["purple"], "sliders", 659.25, func():
		_go_to_scene(target_scenes["settings"], "Membuka Halaman Pengaturan...")
	)
	_add_nav_button(nav_vbox, "Keluar", "", MenuUI.PALETTE["coral"], "exit", 329.63, func():
		get_tree().quit()
	)

	# --- Footer ---
	var footer := HBoxContainer.new()
	root_vbox.add_child(footer)
	var ver_lbl := MenuUI.make_label("v1.0.4  •  GODOT 4", 11, MenuUI.PALETTE["text_muted"], false, true)
	footer.add_child(ver_lbl)

	_build_toast()

# ==============================================================================
# HELPER NAVIGASI & TOAST
# ==============================================================================
func _play(freq: float, dur: float) -> void:
	var vol: float = 0.0 if GameConfig.muted else GameConfig.sfx_volume
	MenuUI.play_tone(audio_playback, freq, dur, vol)

func _go_to_scene(scene_path: String, fallback_msg: String) -> void:
	if ResourceLoader.exists(scene_path):
		get_tree().change_scene_to_file(scene_path)
	else:
		_show_toast("%s (Scene '%s' belum dibuat)" % [fallback_msg, scene_path])

func _add_nav_button(
	parent: Control,
	title: String,
	subtitle: String,
	accent: Color,
	icon_name: String,
	hover_freq: float,
	callback: Callable
) -> void:
	var btn := MenuUI.make_menu_button(title, subtitle, accent, icon_name)
	btn.mouse_entered.connect(func(): _play(hover_freq, 0.06))
	btn.pressed.connect(func():
		_play(hover_freq * 1.25, 0.12)
		callback.call()
	)
	parent.add_child(btn)

func _build_toast() -> void:
	toast_panel = PanelContainer.new()
	toast_panel.visible = false
	toast_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast_panel.offset_top = -76
	toast_panel.offset_bottom = -28
	toast_panel.offset_left = -260
	toast_panel.offset_right = 260
	var t_sb := StyleBoxFlat.new()
	t_sb.bg_color = MenuUI.PALETTE["bg_panel"]
	t_sb.border_color = MenuUI.PALETTE["yellow"]
	t_sb.set_border_width_all(2)
	t_sb.set_corner_radius_all(10)
	t_sb.set_content_margin_all(12)
	toast_panel.add_theme_stylebox_override("panel", t_sb)

	toast_label = MenuUI.make_label("", 13, MenuUI.PALETTE["cream"])
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_panel.add_child(toast_label)
	ui_layer.add_child(toast_panel)

func _show_toast(msg: String) -> void:
	toast_label.text = msg
	toast_panel.visible = true
	await get_tree().create_timer(2.4).timeout
	if is_instance_valid(toast_panel):
		toast_panel.visible = false

# Emblem kotak kecil khas Parabox untuk mendampingi judul utama.
class BrandEmblem extends Control:
	func _draw() -> void:
		var s: float = minf(size.x, size.y)
		var pad: float = 4.0
		var box := Rect2(Vector2(pad, pad), Vector2(s - pad * 2.0, s - pad * 2.0))
		draw_rect(Rect2(box.position + Vector2(0.0, 4.0), box.size), MenuUI.PALETTE["ink"], true)
		draw_rect(box, MenuUI.PALETTE["purple"], true)
		draw_rect(box, MenuUI.PALETTE["ink"], false, 3.0)
		# Pintu kuning di kiri
		draw_rect(Rect2(Vector2(box.position.x, box.get_center().y - 7.0), Vector2(6.0, 14.0)), MenuUI.PALETTE["yellow"], true)
		# Mata kotak kecil
		var cx: float = box.get_center().x + 2.0
		var cy: float = box.get_center().y
		draw_rect(Rect2(Vector2(cx - 9.0, cy - 6.0), Vector2(5.0, 11.0)), MenuUI.PALETTE["ink"], true)
		draw_rect(Rect2(Vector2(cx + 4.0, cy - 6.0), Vector2(5.0, 11.0)), MenuUI.PALETTE["ink"], true)
