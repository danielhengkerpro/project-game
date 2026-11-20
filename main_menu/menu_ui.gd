class_name MenuUI
extends RefCounted

# ==============================================================================
# Helper tampilan untuk halaman menu (Pilih Level & Pengaturan).
# Warnanya sengaja sama dengan main_menu.gd supaya terasa satu aplikasi.
# ==============================================================================

static var PALETTE: Dictionary = {
	"bg_dark": Color("#12141d"),
	"bg_panel": Color("#1a1d2b"),
	"coral": Color("#ff6b6b"),
	"teal": Color("#4ecdc4"),
	"yellow": Color("#ffe66d"),
	"purple": Color("#a29bfe"),
	"text_main": Color("#f1f2f6"),
	"text_muted": Color("#8395a7")
}

static func accent_color(name: String) -> Color:
	if PALETTE.has(name):
		return PALETTE[name]
	return PALETTE["text_main"]

# ------------------------------------------------------------------ background
# Latar kotak rekursif yang sama dengan main menu.
static func draw_recursive_bg(canvas: Node2D, zoom_progress: float, mouse_offset: Vector2) -> void:
	var vp_size: Vector2 = canvas.get_viewport_rect().size
	canvas.draw_rect(Rect2(Vector2.ZERO, vp_size), PALETTE["bg_dark"], true)

	var center: Vector2 = Vector2(vp_size.x * 0.68, vp_size.y * 0.5) + mouse_offset
	var total_layers: int = 11
	var max_dim: float = maxf(vp_size.x, vp_size.y) * 1.65
	var scale_factor: float = 0.56
	var colors: Array = [PALETTE["coral"], PALETTE["teal"], PALETTE["yellow"], PALETTE["purple"]]

	for i in range(total_layers - 1, -1, -1):
		var effective_idx: float = float(i) - zoom_progress
		var box_size: float = max_dim * pow(scale_factor, effective_idx)
		if box_size < 4.0:
			continue

		var col: Color = colors[i % colors.size()]
		var alpha: float = clampf((box_size / max_dim) * 1.4, 0.08, 1.0)
		var angle: float = (effective_idx * 0.08) + sin(zoom_progress * TAU) * 0.02

		canvas.draw_set_transform(center, angle, Vector2.ONE)

		var half: float = box_size / 2.0
		var rect := Rect2(Vector2(-half, -half), Vector2(box_size, box_size))

		var fill_col: Color = col
		fill_col.a = 0.04 * alpha
		canvas.draw_rect(rect, fill_col, true)

		var border_col: Color = col
		border_col.a = alpha
		var line_w: float = maxf(1.5, box_size * 0.012)
		canvas.draw_rect(rect, border_col, false, line_w)

		var entrance_h: float = box_size * 0.24
		var notch := Rect2(Vector2(-half - line_w, -entrance_h / 2.0), Vector2(line_w * 2.5, entrance_h))
		canvas.draw_rect(notch, PALETTE["bg_dark"], true)

		if box_size > 160.0:
			var grid_col := Color(1, 1, 1, 0.04 * alpha)
			var step: float = box_size / 4.0
			for g in range(-1, 2):
				canvas.draw_line(Vector2(g * step, -half), Vector2(g * step, half), grid_col, 1.0)
				canvas.draw_line(Vector2(-half, g * step), Vector2(half, g * step), grid_col, 1.0)

	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ------------------------------------------------------------------ widgets
static func make_menu_button(title: String, subtitle: String, accent: Color) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 64 if subtitle != "" else 52)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.text = "   " + title + ("\n      " + subtitle if subtitle != "" else "")
	btn.add_theme_font_size_override("font_size", 17)
	btn.add_theme_color_override("font_color", PALETTE["text_main"])
	btn.add_theme_color_override("font_hover_color", accent)
	btn.add_theme_color_override("font_disabled_color", PALETTE["text_muted"])

	var normal_sb := StyleBoxFlat.new()
	normal_sb.bg_color = Color(PALETTE["bg_panel"], 0.88)
	normal_sb.border_width_left = 4
	normal_sb.border_width_top = 1
	normal_sb.border_width_right = 1
	normal_sb.border_width_bottom = 1
	normal_sb.border_color = Color(1, 1, 1, 0.12)
	normal_sb.set_corner_radius_all(10)

	var hover_sb := StyleBoxFlat.new()
	hover_sb.bg_color = Color(accent, 0.16)
	hover_sb.border_width_left = 8
	hover_sb.border_width_top = 1
	hover_sb.border_width_right = 1
	hover_sb.border_width_bottom = 1
	hover_sb.border_color = accent
	hover_sb.set_corner_radius_all(10)

	btn.add_theme_stylebox_override("normal", normal_sb)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("pressed", hover_sb)
	return btn

static func make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PALETTE["bg_panel"], 0.92)
	sb.border_color = Color(1, 1, 1, 0.12)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", sb)
	return panel

static func make_label(text: String, size: int, col: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", col)
	return lbl

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
