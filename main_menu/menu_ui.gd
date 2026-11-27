class_name MenuUI
extends RefCounted

# ==============================================================================
# Sistem tampilan antarmuka menu PARABOX REQUIEM.
# Mengatur palet warna, tipografi (Fredoka, Plus Jakarta Sans, Space Mono),
# latar kotak bersarang taktil, ikon vektor, dan gaya tombol/kartu.
# ==============================================================================

const FONT_DISPLAY_BOLD_PATH: String = "res://asset/fonts/Fredoka-Bold.ttf"
const FONT_DISPLAY_SEMI_PATH: String = "res://asset/fonts/Fredoka-SemiBold.ttf"
const FONT_BODY_MED_PATH: String = "res://asset/fonts/PlusJakartaSans-Medium.ttf"
const FONT_BODY_SEMI_PATH: String = "res://asset/fonts/PlusJakartaSans-SemiBold.ttf"
const FONT_MONO_PATH: String = "res://asset/fonts/SpaceMono-Bold.ttf"

static var PALETTE: Dictionary = {
	"bg_dark": Color("#13111c"),
	"bg_mid": Color("#1b1829"),
	"bg_panel": Color("#211d32"),
	"bg_hover": Color("#2c2744"),
	"ink": Color("#0d0b14"),
	"border": Color("#3b3559"),
	"cream": Color("#f4efe6"),
	"cream_shadow": Color("#c8bfb0"),
	"text_main": Color("#f4efe6"),
	"text_muted": Color("#9c95b8"),
	"violet": Color("#8b72f0"),
	"violet_dark": Color("#5d48b8"),
	"coral": Color("#f06c75"),
	"teal": Color("#4ecdc4"),
	"yellow": Color("#f4c245"),
	"purple": Color("#9b84f5"),
	"green": Color("#52d68a")
}

static var _font_cache: Dictionary = {}

static func accent_color(name: String) -> Color:
	if PALETTE.has(name):
		return PALETTE[name]
	return PALETTE["cream"]

# ------------------------------------------------------------------ tipografi
static func get_display_font(weight: int = 700) -> Font:
	var key := "display_%d" % weight
	if _font_cache.has(key):
		return _font_cache[key]
	var path: String = FONT_DISPLAY_BOLD_PATH if weight >= 700 else FONT_DISPLAY_SEMI_PATH
	var f := load(path) as Font
	if f == null:
		return ThemeDB.fallback_font
	_font_cache[key] = f
	return f

static func get_body_font(weight: int = 500) -> Font:
	var key := "body_%d" % weight
	if _font_cache.has(key):
		return _font_cache[key]
	var path: String = FONT_BODY_SEMI_PATH if weight >= 600 else FONT_BODY_MED_PATH
	var f := load(path) as Font
	if f == null:
		return ThemeDB.fallback_font
	_font_cache[key] = f
	return f

static func get_mono_font() -> Font:
	if _font_cache.has("mono"):
		return _font_cache["mono"]
	var f := load(FONT_MONO_PATH) as Font
	if f == null:
		return ThemeDB.fallback_font
	_font_cache["mono"] = f
	return f

static func create_menu_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = get_body_font(500)
	theme.default_font_size = 15

	# Slider bergaya kotak taktil
	var grabber_area := StyleBoxFlat.new()
	grabber_area.bg_color = PALETTE["violet"]
	grabber_area.set_corner_radius_all(6)

	var slider_bg := StyleBoxFlat.new()
	slider_bg.bg_color = PALETTE["ink"]
	slider_bg.border_color = PALETTE["border"]
	slider_bg.set_border_width_all(2)
	slider_bg.set_corner_radius_all(6)
	slider_bg.content_margin_top = 5
	slider_bg.content_margin_bottom = 5

	theme.set_stylebox("slider", "HSlider", slider_bg)
	theme.set_stylebox("grabber_area", "HSlider", grabber_area)
	theme.set_stylebox("grabber_area_highlight", "HSlider", grabber_area)

	# Hilangkan outline fokus default biru Godot
	var empty_focus := StyleBoxEmpty.new()
	theme.set_stylebox("focus", "Button", empty_focus)
	theme.set_stylebox("focus", "CheckButton", empty_focus)
	theme.set_stylebox("focus", "HSlider", empty_focus)
	return theme

# ------------------------------------------------------------------ latar rekursif
# Menggambar latar kotak bersarang berwarna (gaya sebelum pembaruan UI)
# yang berputar dan menembus ke dalam secara kontinu.
static func draw_recursive_bg(
	canvas: Node2D,
	zoom_progress: float,
	mouse_offset: Vector2,
	subtle: bool = false,
	spin_angle: float = 0.0
) -> void:
	var vp: Vector2 = canvas.get_viewport_rect().size
	canvas.draw_rect(Rect2(Vector2.ZERO, vp), PALETTE["bg_dark"], true)

	var center: Vector2 = Vector2(vp.x * 0.68, vp.y * 0.50) + mouse_offset
	if subtle:
		center = Vector2(vp.x * 0.68, vp.y * 0.50) + mouse_offset * 0.5

	var total_layers: int = 11
	var max_dim: float = maxf(vp.x, vp.y) * 1.65
	var scale_factor: float = 0.56
	var layer_palette: Array = [
		PALETTE["coral"],
		PALETTE["teal"],
		PALETTE["yellow"],
		PALETTE["purple"]
	]

	var base_idx: int = int(floor(zoom_progress))
	var frac: float = zoom_progress - float(base_idx)

	for i in range(total_layers - 1, -1, -1):
		var effective_idx: float = float(i) - frac
		var box_size: float = max_dim * pow(scale_factor, effective_idx)
		if box_size < 4.0:
			continue

		var col: Color = layer_palette[(i + base_idx) % layer_palette.size()]
		var alpha: float = clampf((box_size / max_dim) * 1.4, 0.08, 1.0)
		var angle: float = spin_angle + (effective_idx * 0.085)

		canvas.draw_set_transform(center, angle, Vector2.ONE)

		var half: float = box_size / 2.0
		var rect := Rect2(Vector2(-half, -half), Vector2(box_size, box_size))

		canvas.draw_rect(rect, Color(col, 0.04 * alpha), true)

		var line_w: float = maxf(1.5, box_size * 0.012)
		canvas.draw_rect(rect, Color(col, alpha), false, line_w)

		# Garis grid tipis di dalam kotak besar
		if box_size > 160.0:
			var grid_col := Color(1, 1, 1, 0.04 * alpha)
			var step: float = box_size / 4.0
			for g in range(-1, 2):
				canvas.draw_line(Vector2(g * step, -half), Vector2(g * step, half), grid_col, 1.0)
				canvas.draw_line(Vector2(-half, g * step), Vector2(half, g * step), grid_col, 1.0)

	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if subtle:
		canvas.draw_rect(Rect2(Vector2.ZERO, vp), Color(PALETTE["bg_dark"], 0.65), true)

# ------------------------------------------------------------------ widget
static func make_label(text: String, size: int, col: Color, is_display: bool = false, is_mono: bool = false) -> Label:
	var lbl := Label.new()
	lbl.text = text
	if is_mono:
		lbl.add_theme_font_override("font", get_mono_font())
	elif is_display:
		lbl.add_theme_font_override("font", get_display_font(700))
	else:
		lbl.add_theme_font_override("font", get_body_font(500))
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", col)
	return lbl

static func make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PALETTE["bg_panel"], 0.94)
	sb.border_color = PALETTE["border"]
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 5
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", sb)
	return panel

static func make_icon_pill_button(icon_name: String, label_text: String, accent: Color = PALETTE["cream"]) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 38)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var normal_sb := StyleBoxFlat.new()
	normal_sb.bg_color = PALETTE["bg_panel"]
	normal_sb.border_color = PALETTE["border"]
	normal_sb.border_width_left = 2
	normal_sb.border_width_top = 2
	normal_sb.border_width_right = 2
	normal_sb.border_width_bottom = 4
	normal_sb.set_corner_radius_all(10)
	normal_sb.content_margin_left = 12
	normal_sb.content_margin_right = 14
	normal_sb.content_margin_top = 6
	normal_sb.content_margin_bottom = 8

	var hover_sb := normal_sb.duplicate()
	hover_sb.bg_color = PALETTE["bg_hover"]
	hover_sb.border_color = accent

	var pressed_sb := hover_sb.duplicate()
	pressed_sb.border_width_bottom = 2
	pressed_sb.content_margin_top = 8
	pressed_sb.content_margin_bottom = 6

	btn.add_theme_stylebox_override("normal", normal_sb)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("pressed", pressed_sb)
	btn.text = ""

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 8)
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.add_child(hbox)

	var ic := MenuIcon.new(icon_name, accent, 16.0)
	ic.custom_minimum_size = Vector2(18, 18)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(ic)

	var lbl := make_label(label_text, 12, PALETTE["text_main"], false, true)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(lbl)

	btn.set_meta("icon_node", ic)
	btn.set_meta("label_node", lbl)
	# Hitung lebar minimum agar teks dan ikon pas tanpa terpotong
	var text_w: float = get_mono_font().get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	btn.custom_minimum_size = Vector2(text_w + 54.0, 38.0)
	return btn

static func make_primary_button(title: String, subtitle: String, icon_name: String = "play") -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 70)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.text = ""

	var normal_sb := StyleBoxFlat.new()
	normal_sb.bg_color = PALETTE["bg_panel"]
	normal_sb.border_color = PALETTE["border"]
	normal_sb.border_width_left = 2
	normal_sb.border_width_top = 2
	normal_sb.border_width_right = 2
	normal_sb.border_width_bottom = 4
	normal_sb.set_corner_radius_all(12)

	var hover_sb := normal_sb.duplicate()
	hover_sb.bg_color = PALETTE["bg_hover"]
	hover_sb.border_color = PALETTE["yellow"]

	var pressed_sb := hover_sb.duplicate()
	pressed_sb.border_width_bottom = 2
	pressed_sb.border_width_top = 3

	btn.add_theme_stylebox_override("normal", normal_sb)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("pressed", pressed_sb)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	btn.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)

	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.custom_minimum_size = Vector2(40, 40)
	var b_sb := StyleBoxFlat.new()
	b_sb.bg_color = Color(PALETTE["yellow"], 0.14)
	b_sb.border_color = Color(PALETTE["yellow"], 0.45)
	b_sb.set_border_width_all(1)
	b_sb.set_corner_radius_all(10)
	badge.add_theme_stylebox_override("panel", b_sb)
	row.add_child(badge)

	var ic := MenuIcon.new(icon_name, PALETTE["yellow"], 18.0)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.custom_minimum_size = Vector2(20, 20)
	badge.add_child(ic)

	var text_col := VBoxContainer.new()
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_col.add_theme_constant_override("separation", 1)
	row.add_child(text_col)

	var t_lbl := Label.new()
	t_lbl.text = title
	t_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t_lbl.add_theme_font_override("font", get_display_font(700))
	t_lbl.add_theme_font_size_override("font_size", 20)
	t_lbl.add_theme_color_override("font_color", PALETTE["text_main"])
	text_col.add_child(t_lbl)

	if subtitle != "":
		var s_lbl := Label.new()
		s_lbl.text = subtitle
		s_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s_lbl.add_theme_font_override("font", get_body_font(600))
		s_lbl.add_theme_font_size_override("font_size", 13)
		s_lbl.add_theme_color_override("font_color", PALETTE["text_muted"])
		text_col.add_child(s_lbl)

	return btn

static func make_menu_button(
	title: String,
	subtitle: String,
	accent: Color,
	icon_name: String = "",
	badge_text: String = "",
	right_icon: String = ""
) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 62 if subtitle != "" else 50)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.text = ""

	var normal_sb := StyleBoxFlat.new()
	normal_sb.bg_color = PALETTE["bg_panel"]
	normal_sb.border_color = PALETTE["border"]
	normal_sb.border_width_left = 2
	normal_sb.border_width_top = 2
	normal_sb.border_width_right = 2
	normal_sb.border_width_bottom = 4
	normal_sb.set_corner_radius_all(11)

	var hover_sb := normal_sb.duplicate()
	hover_sb.bg_color = PALETTE["bg_hover"]
	hover_sb.border_color = accent

	var pressed_sb := hover_sb.duplicate()
	pressed_sb.border_width_bottom = 2

	var disabled_sb := normal_sb.duplicate()
	disabled_sb.bg_color = Color(PALETTE["bg_mid"], 0.72)
	disabled_sb.border_color = Color(PALETTE["border"], 0.45)
	disabled_sb.border_width_bottom = 2

	btn.add_theme_stylebox_override("normal", normal_sb)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("pressed", pressed_sb)
	btn.add_theme_stylebox_override("disabled", disabled_sb)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	btn.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	if badge_text != "":
		var pill := PanelContainer.new()
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pill.custom_minimum_size = Vector2(44, 34)
		var p_sb := StyleBoxFlat.new()
		p_sb.bg_color = Color(accent, 0.16)
		p_sb.border_color = Color(accent, 0.55)
		p_sb.set_border_width_all(1)
		p_sb.set_corner_radius_all(8)
		pill.add_theme_stylebox_override("panel", p_sb)
		row.add_child(pill)

		var b_lbl := make_label(badge_text, 13, accent, false, true)
		b_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill.add_child(b_lbl)
	elif icon_name != "":
		var ic := MenuIcon.new(icon_name, accent, 18.0)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ic.custom_minimum_size = Vector2(22, 22)
		row.add_child(ic)

	var text_col := VBoxContainer.new()
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_col.add_theme_constant_override("separation", 1)
	row.add_child(text_col)

	var t_lbl := Label.new()
	t_lbl.text = title
	t_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t_lbl.add_theme_font_override("font", get_display_font(600))
	t_lbl.add_theme_font_size_override("font_size", 17)
	t_lbl.add_theme_color_override("font_color", PALETTE["text_main"])
	text_col.add_child(t_lbl)

	if subtitle != "":
		var s_lbl := Label.new()
		s_lbl.text = subtitle
		s_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s_lbl.add_theme_font_override("font", get_body_font(500))
		s_lbl.add_theme_font_size_override("font_size", 12)
		s_lbl.add_theme_color_override("font_color", PALETTE["text_muted"])
		text_col.add_child(s_lbl)

	if right_icon != "":
		var r_col: Color = PALETTE["text_muted"] if right_icon == "lock" else accent
		var ric := MenuIcon.new(right_icon, r_col, 16.0)
		ric.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ric.custom_minimum_size = Vector2(20, 20)
		row.add_child(ric)

	btn.set_meta("title_lbl", t_lbl)
	return btn

# ------------------------------------------------------------------ audio
# Suara menu dibuat langsung lewat generator, tanpa file audio.
static func create_tone_player(parent: Node) -> Array:
	var player := AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.1
	player.stream = gen
	parent.add_child(player)
	player.play()
	return [player, player.get_stream_playback()]

static func play_tone(playback, freq: float, duration: float, volume: float) -> void:
	var gen := playback as AudioStreamGeneratorPlayback
	if gen == null or volume <= 0.0:
		return
	var sample_rate: float = 22050.0
	var frames: int = int(sample_rate * duration)
	if frames <= 0:
		return
	var phase: float = 0.0
	var increment: float = freq / sample_rate
	for i in range(frames):
		if gen.get_frames_available() <= 0:
			break
		var env: float = (1.0 - float(i) / float(frames)) * 0.15 * volume
		var sample: float = sin(phase * TAU) * env
		gen.push_frame(Vector2(sample, sample))
		phase = fmod(phase + increment, 1.0)

# ------------------------------------------------------------------ ikon vektor
class MenuIcon extends Control:
	var icon_name: String
	var icon_color: Color
	var icon_sz: float

	func _init(p_name: String, p_color: Color, p_sz: float = 18.0) -> void:
		icon_name = p_name
		icon_color = p_color
		icon_sz = p_sz
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c: Vector2 = size / 2.0
		var r: float = icon_sz * 0.44
		var lw: float = maxf(1.8, icon_sz * 0.11)
		match icon_name:
			"play":
				var pts := PackedVector2Array([
					c + Vector2(-r * 0.65, -r * 0.85),
					c + Vector2(r * 0.90, 0.0),
					c + Vector2(-r * 0.65, r * 0.85)
				])
				draw_colored_polygon(pts, icon_color)
			"grid":
				var g: float = r * 0.42
				var off: float = r * 0.52
				draw_rect(Rect2(c + Vector2(-off - g, -off - g), Vector2(g * 2, g * 2)), icon_color, true)
				draw_rect(Rect2(c + Vector2(off - g, -off - g), Vector2(g * 2, g * 2)), icon_color, true)
				draw_rect(Rect2(c + Vector2(-off - g, off - g), Vector2(g * 2, g * 2)), icon_color, true)
				draw_rect(Rect2(c + Vector2(off - g, off - g), Vector2(g * 2, g * 2)), icon_color, true)
			"help":
				draw_arc(c + Vector2(0.0, -r * 0.25), r * 0.42, PI, TAU * 1.15, 16, icon_color, lw)
				draw_line(c + Vector2(0.0, r * 0.15), c + Vector2(0.0, r * 0.42), icon_color, lw)
				draw_circle(c + Vector2(0.0, r * 0.78), lw * 0.65, icon_color)
			"sliders":
				draw_line(c + Vector2(-r, -r * 0.45), c + Vector2(r, -r * 0.45), icon_color, lw)
				draw_circle(c + Vector2(r * 0.35, -r * 0.45), lw * 1.2, icon_color)
				draw_line(c + Vector2(-r, r * 0.45), c + Vector2(r, r * 0.45), icon_color, lw)
				draw_circle(c + Vector2(-r * 0.35, r * 0.45), lw * 1.2, icon_color)
			"exit":
				draw_rect(Rect2(c + Vector2(-r * 0.85, -r * 0.85), Vector2(r * 1.1, r * 1.7)), icon_color, false, lw)
				draw_line(c + Vector2(-r * 0.1, 0.0), c + Vector2(r * 0.9, 0.0), icon_color, lw)
				draw_line(c + Vector2(r * 0.45, -r * 0.45), c + Vector2(r * 0.9, 0.0), icon_color, lw)
				draw_line(c + Vector2(r * 0.45, r * 0.45), c + Vector2(r * 0.9, 0.0), icon_color, lw)
			"back":
				draw_line(c + Vector2(r * 0.45, -r * 0.7), c + Vector2(-r * 0.45, 0.0), icon_color, lw)
				draw_line(c + Vector2(-r * 0.45, 0.0), c + Vector2(r * 0.45, r * 0.7), icon_color, lw)
			"loop":
				draw_arc(c, r * 0.72, 0.3, PI * 1.55, 18, icon_color, lw)
				draw_line(c + Vector2(0.0, -r * 0.72), c + Vector2(-r * 0.35, -r * 1.0), icon_color, lw)
				draw_line(c + Vector2(0.0, -r * 0.72), c + Vector2(-r * 0.35, -r * 0.38), icon_color, lw)
			"sound_on":
				var body := PackedVector2Array([
					c + Vector2(-r * 0.85, -r * 0.35),
					c + Vector2(-r * 0.35, -r * 0.35),
					c + Vector2(r * 0.2, -r * 0.8),
					c + Vector2(r * 0.2, r * 0.8),
					c + Vector2(-r * 0.35, r * 0.35),
					c + Vector2(-r * 0.85, r * 0.35)
				])
				draw_colored_polygon(body, icon_color)
				draw_arc(c + Vector2(r * 0.15, 0.0), r * 0.48, -0.7, 0.7, 10, icon_color, lw)
				draw_arc(c + Vector2(r * 0.15, 0.0), r * 0.82, -0.7, 0.7, 12, icon_color, lw)
			"sound_off":
				var body2 := PackedVector2Array([
					c + Vector2(-r * 0.85, -r * 0.35),
					c + Vector2(-r * 0.35, -r * 0.35),
					c + Vector2(r * 0.2, -r * 0.8),
					c + Vector2(r * 0.2, r * 0.8),
					c + Vector2(-r * 0.35, r * 0.35),
					c + Vector2(-r * 0.85, r * 0.35)
				])
				draw_colored_polygon(body2, icon_color)
				draw_line(c + Vector2(r * 0.45, -r * 0.38), c + Vector2(r * 0.95, r * 0.38), icon_color, lw)
				draw_line(c + Vector2(r * 0.95, -r * 0.38), c + Vector2(r * 0.45, r * 0.38), icon_color, lw)
			"lock":
				draw_arc(c + Vector2(0.0, -r * 0.22), r * 0.45, PI, TAU, 12, icon_color, lw)
				draw_rect(Rect2(c + Vector2(-r * 0.68, -r * 0.15), Vector2(r * 1.36, r * 1.05)), icon_color, true)
			"check":
				draw_line(c + Vector2(-r * 0.65, 0.0), c + Vector2(-r * 0.15, r * 0.55), icon_color, lw * 1.15)
				draw_line(c + Vector2(-r * 0.15, r * 0.55), c + Vector2(r * 0.75, -r * 0.55), icon_color, lw * 1.15)
			"star":
				var pts_star := PackedVector2Array([
					c + Vector2(0.0, -r),
					c + Vector2(r * 0.28, -r * 0.28),
					c + Vector2(r, 0.0),
					c + Vector2(r * 0.28, r * 0.28),
					c + Vector2(0.0, r),
					c + Vector2(-r * 0.28, r * 0.28),
					c + Vector2(-r, 0.0),
					c + Vector2(-r * 0.28, -r * 0.28)
				])
				draw_colored_polygon(pts_star, icon_color)

# ------------------------------------------------------------------ HUD level & pop-up menang
# Kelas pola latar lembut untuk scene permainan agar tidak hitam polos.
class _GameBgPattern extends Node2D:
	var glow_color: Color

	func _init(p_glow: Color = Color(1.0, 0.90, 0.78, 0.04)) -> void:
		glow_color = p_glow

	func _draw() -> void:
		var vp: Vector2 = get_viewport_rect().size
		if vp.x <= 0.0 or vp.y <= 0.0:
			return
		draw_circle(vp * 0.5, minf(vp.x, vp.y) * 0.46, glow_color)
		var step: float = 40.0
		var dot_col := Color(1.0, 0.96, 0.90, 0.045)
		var gx: float = step * 0.5
		while gx < vp.x:
			var gy: float = step * 0.5
			while gy < vp.y:
				draw_circle(Vector2(gx, gy), 1.2, dot_col)
				gy += step
			gx += step

static func make_game_keycap_button(
	key_text: String,
	label_text: String,
	icon_name: String,
	accent: Color,
	on_press: Callable
) -> Button:
	var btn := Button.new()
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.focus_mode = Control.FOCUS_NONE
	btn.text = ""

	var normal_sb := StyleBoxFlat.new()
	normal_sb.bg_color = Color("#1e1613", 0.92)
	normal_sb.border_color = Color("#4a372e")
	normal_sb.border_width_left = 1
	normal_sb.border_width_top = 1
	normal_sb.border_width_right = 1
	normal_sb.border_width_bottom = 3
	normal_sb.set_corner_radius_all(10)

	var hover_sb := normal_sb.duplicate()
	hover_sb.bg_color = Color("#2b1f1b", 0.96)
	hover_sb.border_color = accent

	var pressed_sb := hover_sb.duplicate()
	pressed_sb.border_width_bottom = 1
	pressed_sb.border_width_top = 2

	btn.add_theme_stylebox_override("normal", normal_sb)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("pressed", pressed_sb)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 11)
	margin.add_theme_constant_override("margin_right", 11)
	margin.add_theme_constant_override("margin_bottom", 2)
	btn.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 7)
	margin.add_child(row)

	if icon_name != "":
		var ic := MenuIcon.new(icon_name, accent, 14.0)
		ic.custom_minimum_size = Vector2(15, 15)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ic)

	if key_text != "":
		var key_pill := PanelContainer.new()
		key_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var k_sb := StyleBoxFlat.new()
		k_sb.bg_color = Color(accent, 0.16)
		k_sb.border_color = Color(accent, 0.45)
		k_sb.set_border_width_all(1)
		k_sb.set_corner_radius_all(5)
		k_sb.content_margin_left = 6
		k_sb.content_margin_right = 6
		k_sb.content_margin_top = 1
		k_sb.content_margin_bottom = 1
		key_pill.add_theme_stylebox_override("panel", k_sb)
		row.add_child(key_pill)

		var k_lbl := Label.new()
		k_lbl.text = key_text
		k_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		k_lbl.add_theme_font_override("font", get_mono_font())
		k_lbl.add_theme_font_size_override("font_size", 11)
		k_lbl.add_theme_color_override("font_color", accent)
		key_pill.add_child(k_lbl)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_override("font", get_body_font(600))
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", PALETTE["cream"])
	row.add_child(lbl)

	var total_w: float = 26.0 + get_body_font(600).get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	if icon_name != "":
		total_w += 22.0
	if key_text != "":
		total_w += 20.0 + get_mono_font().get_string_size(key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	btn.custom_minimum_size = Vector2(total_w, 38.0)

	if on_press.is_valid():
		btn.pressed.connect(on_press)
	return btn

static func build_game_hud(
	owner: Node,
	initial_bg: Color,
	accent: Color,
	on_menu: Callable,
	on_undo: Callable,
	on_reset: Callable,
	include_hint_bar: bool = false
) -> Dictionary:
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -1
	owner.add_child(bg_layer)

	var bg_rect := ColorRect.new()
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_rect.color = initial_bg
	bg_layer.add_child(bg_rect)

	var pattern := _GameBgPattern.new(Color(accent, 0.045))
	bg_layer.add_child(pattern)
	owner.get_viewport().size_changed.connect(func():
		if is_instance_valid(pattern):
			pattern.queue_redraw()
	)

	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 5
	owner.add_child(hud_layer)

	var margin := MarginContainer.new()
	margin.theme = create_menu_theme()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	hud_layer.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(root_vbox)

	# Baris atas: tombol menu & badge ruangan di kiri, tombol cepat & langkah di kanan
	var top_bar := HBoxContainer.new()
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_theme_constant_override("separation", 10)
	root_vbox.add_child(top_bar)

	var menu_btn := make_game_keycap_button("ESC", "Menu", "back", PALETTE["cream"], on_menu)
	top_bar.add_child(menu_btn)

	var room_pill := PanelContainer.new()
	room_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r_sb := StyleBoxFlat.new()
	r_sb.bg_color = Color("#1e1613", 0.92)
	r_sb.border_color = Color(accent, 0.55)
	r_sb.border_width_left = 1
	r_sb.border_width_top = 1
	r_sb.border_width_right = 1
	r_sb.border_width_bottom = 3
	r_sb.set_corner_radius_all(10)
	r_sb.content_margin_left = 12
	r_sb.content_margin_right = 14
	r_sb.content_margin_top = 6
	r_sb.content_margin_bottom = 6
	room_pill.add_theme_stylebox_override("panel", r_sb)
	top_bar.add_child(room_pill)

	var room_row := HBoxContainer.new()
	room_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room_row.add_theme_constant_override("separation", 9)
	room_pill.add_child(room_row)

	var swatch := Panel.new()
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swatch.custom_minimum_size = Vector2(10, 10)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sw_sb := StyleBoxFlat.new()
	sw_sb.bg_color = accent
	sw_sb.set_corner_radius_all(3)
	swatch.add_theme_stylebox_override("panel", sw_sb)
	room_row.add_child(swatch)

	var hud_label := Label.new()
	hud_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_label.add_theme_font_override("font", get_display_font(600))
	hud_label.add_theme_font_size_override("font_size", 16)
	hud_label.add_theme_color_override("font_color", PALETTE["cream"])
	room_row.add_child(hud_label)

	var top_spacer := Control.new()
	top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(top_spacer)

	var undo_btn := make_game_keycap_button("Z", "Undo", "loop", PALETTE["teal"], on_undo)
	top_bar.add_child(undo_btn)

	var reset_btn := make_game_keycap_button("R", "Ulang", "", PALETTE["coral"], on_reset)
	top_bar.add_child(reset_btn)

	var step_panel := PanelContainer.new()
	step_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb_step := StyleBoxFlat.new()
	sb_step.bg_color = Color("#211814", 0.95)
	sb_step.border_color = PALETTE["yellow"]
	sb_step.border_width_left = 2
	sb_step.border_width_top = 2
	sb_step.border_width_right = 2
	sb_step.border_width_bottom = 4
	sb_step.set_corner_radius_all(10)
	sb_step.content_margin_left = 14
	sb_step.content_margin_right = 14
	sb_step.content_margin_top = 6
	sb_step.content_margin_bottom = 6
	step_panel.add_theme_stylebox_override("panel", sb_step)
	top_bar.add_child(step_panel)

	var step_label := Label.new()
	step_label.text = "LANGKAH: 0"
	step_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	step_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	step_label.add_theme_font_override("font", get_mono_font())
	step_label.add_theme_font_size_override("font_size", 14)
	step_label.add_theme_color_override("font_color", PALETTE["yellow"])
	step_panel.add_child(step_label)

	var mid_spacer := Control.new()
	mid_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(mid_spacer)

	# Baris bawah: petunjuk dinamis untuk tutorial, atau penanda kontrol gerak di kiri bawah
	var hint_label: Label = null
	var bottom_bar := HBoxContainer.new()
	bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_vbox.add_child(bottom_bar)

	if include_hint_bar:
		bottom_bar.alignment = BoxContainer.ALIGNMENT_CENTER
		var hint_pill := PanelContainer.new()
		hint_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var h_sb := StyleBoxFlat.new()
		h_sb.bg_color = Color("#1b172a", 0.92)
		h_sb.border_color = Color(PALETTE["yellow"], 0.45)
		h_sb.set_border_width_all(1)
		h_sb.border_width_bottom = 3
		h_sb.set_corner_radius_all(10)
		h_sb.content_margin_left = 16
		h_sb.content_margin_right = 16
		h_sb.content_margin_top = 6
		h_sb.content_margin_bottom = 6
		hint_pill.add_theme_stylebox_override("panel", h_sb)
		bottom_bar.add_child(hint_pill)

		hint_label = Label.new()
		hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint_label.add_theme_font_override("font", get_body_font(600))
		hint_label.add_theme_font_size_override("font_size", 14)
		hint_label.add_theme_color_override("font_color", Color("#fbe49a"))
		hint_pill.add_child(hint_label)
	else:
		var move_pill := PanelContainer.new()
		move_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m_sb := StyleBoxFlat.new()
		m_sb.bg_color = Color("#1c1512", 0.78)
		m_sb.border_color = Color("#4a372e", 0.55)
		m_sb.set_border_width_all(1)
		m_sb.set_corner_radius_all(8)
		m_sb.content_margin_left = 10
		m_sb.content_margin_right = 10
		m_sb.content_margin_top = 4
		m_sb.content_margin_bottom = 4
		move_pill.add_theme_stylebox_override("panel", m_sb)
		bottom_bar.add_child(move_pill)

		var move_row := HBoxContainer.new()
		move_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		move_row.add_theme_constant_override("separation", 6)
		move_pill.add_child(move_row)

		var key_lbl := Label.new()
		key_lbl.text = "WASD / PANAH"
		key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key_lbl.add_theme_font_override("font", get_mono_font())
		key_lbl.add_theme_font_size_override("font_size", 11)
		key_lbl.add_theme_color_override("font_color", Color("#e6d5c0"))
		move_row.add_child(key_lbl)

		var act_lbl := Label.new()
		act_lbl.text = "Gerak"
		act_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		act_lbl.add_theme_font_override("font", get_body_font(500))
		act_lbl.add_theme_font_size_override("font_size", 12)
		act_lbl.add_theme_color_override("font_color", Color("#b8a594"))
		move_row.add_child(act_lbl)

	return {
		"bg_layer": bg_layer,
		"bg_rect": bg_rect,
		"hud_layer": hud_layer,
		"hud_label": hud_label,
		"step_panel": step_panel,
		"step_label": step_label,
		"hint_label": hint_label
	}

static func build_win_overlay(
	owner: Node,
	badge_text: String,
	title_text: String,
	msg_text: String,
	accent: Color,
	next_label: String,
	on_next: Callable,
	on_retry: Callable,
	on_menu: Callable
) -> Dictionary:
	var win_overlay := CanvasLayer.new()
	win_overlay.layer = 10
	win_overlay.visible = false
	owner.add_child(win_overlay)

	var backdrop := ColorRect.new()
	backdrop.theme = create_menu_theme()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.05, 0.04, 0.07, 0.84)
	win_overlay.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#1e1828")
	sb.border_color = accent
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 5
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 32
	sb.content_margin_right = 32
	sb.content_margin_top = 28
	sb.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var badge_pill := PanelContainer.new()
	badge_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var b_sb := StyleBoxFlat.new()
	b_sb.bg_color = Color(accent, 0.14)
	b_sb.border_color = Color(accent, 0.45)
	b_sb.set_border_width_all(1)
	b_sb.set_corner_radius_all(8)
	b_sb.content_margin_left = 12
	b_sb.content_margin_right = 12
	b_sb.content_margin_top = 4
	b_sb.content_margin_bottom = 4
	badge_pill.add_theme_stylebox_override("panel", b_sb)
	vbox.add_child(badge_pill)

	var badge_lbl := Label.new()
	badge_lbl.text = badge_text
	badge_lbl.add_theme_font_override("font", get_mono_font())
	badge_lbl.add_theme_font_size_override("font_size", 12)
	badge_lbl.add_theme_color_override("font_color", accent)
	badge_pill.add_child(badge_lbl)

	var title_lbl := Label.new()
	title_lbl.text = title_text
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_override("font", get_display_font(700))
	title_lbl.add_theme_font_size_override("font_size", 38)
	title_lbl.add_theme_color_override("font_color", PALETTE["yellow"])
	vbox.add_child(title_lbl)

	var msg_lbl := Label.new()
	msg_lbl.text = msg_text
	msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_lbl.add_theme_font_override("font", get_body_font(500))
	msg_lbl.add_theme_font_size_override("font_size", 15)
	msg_lbl.add_theme_color_override("font_color", Color("#d8d0c5"))
	vbox.add_child(msg_lbl)

	var step_pill := PanelContainer.new()
	step_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var sp_sb := StyleBoxFlat.new()
	sp_sb.bg_color = PALETTE["bg_mid"]
	sp_sb.border_color = Color(PALETTE["teal"], 0.4)
	sp_sb.set_border_width_all(1)
	sp_sb.set_corner_radius_all(8)
	sp_sb.content_margin_left = 16
	sp_sb.content_margin_right = 16
	sp_sb.content_margin_top = 6
	sp_sb.content_margin_bottom = 6
	step_pill.add_theme_stylebox_override("panel", sp_sb)
	vbox.add_child(step_pill)

	var win_step_label := Label.new()
	win_step_label.text = "Total Langkah: 0"
	win_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_step_label.add_theme_font_override("font", get_mono_font())
	win_step_label.add_theme_font_size_override("font_size", 14)
	win_step_label.add_theme_color_override("font_color", PALETTE["teal"])
	step_pill.add_child(win_step_label)

	if next_label != "" and on_next.is_valid():
		var next_btn := make_primary_button(next_label, "Tekan untuk melanjutkan", "play")
		next_btn.pressed.connect(on_next)
		vbox.add_child(next_btn)

		var btn_box := HBoxContainer.new()
		btn_box.add_theme_constant_override("separation", 12)
		vbox.add_child(btn_box)

		var retry_btn := make_menu_button("Ulangi (R)", "", PALETTE["yellow"], "loop")
		retry_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		retry_btn.pressed.connect(on_retry)
		btn_box.add_child(retry_btn)

		var menu_btn := make_menu_button("Menu Utama", "", PALETTE["teal"], "back")
		menu_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		menu_btn.pressed.connect(on_menu)
		btn_box.add_child(menu_btn)
	else:
		var menu_btn := make_primary_button("Kembali ke Menu Utama", "Semua level selesai", "star")
		menu_btn.pressed.connect(on_menu)
		vbox.add_child(menu_btn)

		var retry_btn := make_menu_button("Main Lagi (R)", "", PALETTE["yellow"], "loop")
		retry_btn.pressed.connect(on_retry)
		vbox.add_child(retry_btn)

	return {
		"win_overlay": win_overlay,
		"win_step_label": win_step_label
	}
