extends Node2D

# ==============================================================================
# 1. KONFIGURASI UKURAN GRID, WARNA & SCENE MENU
# ==============================================================================
const TILE_SIZE: int = 76              # ukuran maksimum petak (otomatis mengecil bila layar sempit)
const MOVE_DURATION: float = 0.13
const ZOOM_DURATION: float = 0.30      # durasi animasi zoom masuk / keluar kotak
const DASH_TRAIL_COUNT: int = 3        # jumlah bayangan yang ditinggalkan saat dash
const DASH_TRAIL_DURATION: float = 0.22
const MAX_DEPTH: int = 40              # pengaman rekursi (kotak di dalam kotak di dalam kotak ...)
const INVALID_POS := Vector2i(-1, -1)
const MAIN_MENU_PATH: String = "res://main_menu/main_menu.tscn"
const LEVEL2_PATH: String = "res://level2/level2.tscn"

# Warna diambil langsung dari screenshot level.
var palette := {
	"bg": Color("#000000"),
	"bg_blue": Color("#2f5572"),
	"floor": Color("#77432b"),
	"wall": Color("#ffaa77"),
	"wall_highlight": Color("#fbe49a"),
	"outline": Color("#323c79"),
	"blue": Color("#78a0ff"),
	"blue_floor": Color("#2358ea"),
	"blue_wall": Color("#b6dcee"),
	"blue_light": Color("#e8f7ff"),
	"ice": Color("#dff1fb"),
	"yellow": Color("#fde069"),
	"yellow_inner": Color("#ca8a04"),
	"pink": Color("#de6edc"),
	"pink_inner": Color("#a21caf"),
	"teal": Color("#4ecdc4"),
	"text": Color("#f1f2f6")
}

# ==============================================================================
# 2. DEFINISI PETA RUANGAN
# ==============================================================================
# '#' = Dinding          '.' = Lantai
# 'G' = Target kotak     'P' = Target pemain (kotak bermata dua)
# 'E' = Pintu ruangan interior. Di dinding KIRI  -> kotak bisa dimasuki dari kiri
#                                 di dinding ATAS  -> bisa dimasuki dari atas, dst.
#       Keluar lewat pintu = muncul di sisi kotak induk yang sama dengan pintu itu.

var rooms := {
	# Ruang luar: gua kecil. Kotak biru menempel di dinding kanan (tidak bisa
	# didorong ke kanan), jadi bisa dimasuki dari kiri lewat pintu kuning.
	"outer": {
		"name": "Level 1 - Gua Kotak",
		"theme": "orange",
		"grid": [
			"########",
			"#......#",
			"#...P###",
			"##.#...#",
			"###....#",
			"###...G#",
			"########"
		]
	},
	# Di dalam kotak biru ada target kotak sendiri ('G').
	# Antar kotak kuning ke sana, lalu keluar lewat pintu kiri.
	"inner_blue": {
		"name": "Dalam Kotak Biru",
		"theme": "blue",
		"grid": [
			"#######",
			"###..##",
			"##G...#",
			"E.....#",
			"###...#",
			"#...###",
			"#######"
		]
	}
}

var game_state := {}
var undo_stack: Array[Dictionary] = []
var is_animating: bool = false
var is_completed: bool = false
var step_count: int = 0
var is_in_menu: bool = false

var board_container: Node2D
var hud_layer: CanvasLayer
var hud_label: Label
var step_panel: PanelContainer
var step_label: Label
var bg_layer: CanvasLayer
var bg_rect: ColorRect
var win_overlay: CanvasLayer
var win_step_label: Label

func _ready() -> void:
	is_in_menu = get_parent() != null and get_parent() != get_tree().root
	_setup_hud()
	_setup_win_overlay()
	_reset_level()
	if is_in_menu:
		if hud_layer != null:
			hud_layer.visible = false
		if bg_layer != null:
			bg_layer.visible = false

# ==============================================================================
# 3. INISIALISASI, UNDO & RESET LEVEL
# ==============================================================================
func _reset_level(play_sound: bool = false) -> void:
	if play_sound:
		Sfx.play("reset")
	undo_stack.clear()
	step_count = 0
	_update_step_hud()
	is_completed = false
	if win_overlay != null:
		win_overlay.visible = false

	game_state = {
		"active_room": "outer",
		"player": {
			"room": "outer",
			"pos": Vector2i(6, 1),
			"path": []              # daftar id kotak yang sedang dimasuki pemain (untuk jalan keluar)
		},
		"boxes": [
			{
				"id": "box_yellow_1",
				"room": "outer",
				"pos": Vector2i(4, 4),
				"color": "yellow",
				"target_room": ""
			},
			{
				"id": "box_yellow_2",
				"room": "outer",
				"pos": Vector2i(2, 2),
				"color": "yellow",
				"target_room": ""
			},
			{
				"id": "box_blue",
				"room": "outer",
				"pos": Vector2i(6, 3),
				"color": "blue",
				"target_room": "inner_blue"
			}
		]
	}
	_rebuild_visuals("none")

func _save_undo() -> void:
	var snap: Dictionary = game_state.duplicate(true)
	snap["step_count"] = step_count
	undo_stack.append(snap)

func _undo_move() -> void:
	if undo_stack.is_empty() or is_animating or is_completed:
		return
	var prev: Dictionary = undo_stack.pop_back()
	if prev.has("step_count"):
		step_count = prev["step_count"]
	game_state = prev
	_update_step_hud()
	Sfx.play("undo")
	_rebuild_visuals("none")

# ==============================================================================
# 4. INPUT KEYBOARD (WASD / PANAH, UNDO, RESET, ESC)
# ==============================================================================
func _unhandled_input(event: InputEvent) -> void:
	if is_in_menu or is_animating:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_go_to_main_menu()
			return
		if event.keycode == KEY_R:
			_reset_level(true)
			return
		if is_completed:
			if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
				_go_to_main_menu()
			return

		match event.keycode:
			KEY_UP, KEY_W:        _try_move_player(Vector2i(0, -1))
			KEY_DOWN, KEY_S:      _try_move_player(Vector2i(0, 1))
			KEY_LEFT, KEY_A:      _try_move_player(Vector2i(-1, 0))
			KEY_RIGHT, KEY_D:     _try_move_player(Vector2i(1, 0))
			KEY_Z, KEY_BACKSPACE: _undo_move()

# ==============================================================================
# 5. LOGIKA PATRICK'S PARABOX
# ==============================================================================
# Satu fungsi inti yang dipakai pemain DAN kotak:
#
#   _resolve_move(room, pos, dir, ...)  =  "sesuatu bergerak ke petak (room, pos) dengan arah dir"
#
#   - dinding / luar peta                -> gagal
#   - petak pintu 'E' (arah keluar)      -> lanjut ke petak di samping kotak induk (ruangan luar)
#   - petak kosong                       -> sukses
#   - ada kotak di petak itu:
#       1) coba DORONG kotak itu searah dir (rantai, bisa menembus pintu / masuk kotak lain)
#       2) kalau tidak bisa didorong dan kotak itu punya ruangan + pintu di sisi
#          yang berhadapan dengan arah gerak -> MASUK ke dalam kotak itu
#       3) selain itu gagal
#
# Perubahan state hanya dilakukan ketika seluruh rantai sudah pasti berhasil,
# jadi gerakan yang gagal tidak meninggalkan state setengah jadi.
#
# Mengembalikan {} bila gagal, atau {"room", "pos", "path"} = tujuan akhir pelaku.

func _try_move_player(dir: Vector2i) -> void:
	if is_completed:
		return
	var p: Dictionary = game_state["player"]
	var old_room: String = p["room"]
	var old_pos: Vector2i = p["pos"]
	var old_depth: int = p["path"].size()
	var boxes_before: Array = _snapshot_boxes()

	_save_undo()
	var res: Dictionary = _resolve_move(old_room, p["pos"] + dir, dir, 0, false, p["path"])
	if res.is_empty():
		undo_stack.pop_back()
		Sfx.play("blocked")
		return

	p["room"] = res["room"]
	p["pos"] = res["pos"]
	p["path"] = res["path"]
	game_state["active_room"] = res["room"]
	step_count += 1
	_update_step_hud()

	var transition := "move"
	if res["room"] != old_room:
		transition = "enter" if res["path"].size() > old_depth else "exit"

	match transition:
		"enter": Sfx.play("enter")
		"exit":  Sfx.play("exit")
		_:       Sfx.play("push" if _boxes_changed(boxes_before) else "move")

	await _rebuild_visuals(transition, old_pos, dir, boxes_before)
	_check_win_condition()

# Posisi semua kotak sebelum langkah dipakai untuk animasi dash kotak.
func _snapshot_boxes() -> Array:
	var snap: Array = []
	for box in game_state["boxes"]:
		snap.append({"id": box["id"], "room": box["room"], "pos": box["pos"]})
	return snap

func _boxes_changed(before: Array) -> bool:
	for b in before:
		var now: Dictionary = _get_box_by_id(b["id"])
		if now.is_empty():
			continue
		if now["room"] != b["room"] or now["pos"] != b["pos"]:
			return true
	return false

func _resolve_move(room: String, pos: Vector2i, dir: Vector2i, depth: int, mover_is_box: bool, path: Array) -> Dictionary:
	if depth > MAX_DEPTH:
		return {}

	var tile: String = _tile_at(room, pos)
	if tile == "" or tile == "#":
		return {}

	# --- Pintu keluar ruangan interior ---
	if tile == "E":
		if not _is_exit_dir(room, pos, dir):
			return {}
		var parent: Dictionary = _find_parent_box(room, path)
		if parent.is_empty():
			return {}
		var new_path: Array = path.duplicate()
		if not new_path.is_empty() and new_path.back() == parent["id"]:
			new_path.pop_back()
		return _resolve_move(parent["room"], parent["pos"] + dir, dir, depth + 1, mover_is_box, new_path)

	# --- Petak biasa ---
	var box: Dictionary = _get_box_at(room, pos)
	if box.is_empty():
		# kotak tidak boleh ditumpuk di atas pemain
		if mover_is_box and game_state["player"]["room"] == room and game_state["player"]["pos"] == pos:
			return {}
		return {"room": room, "pos": pos, "path": path}

	# 1) Dorong kotak di depan
	var pushed: Dictionary = _resolve_move(box["room"], pos + dir, dir, depth + 1, true, path)
	if not pushed.is_empty():
		box["room"] = pushed["room"]
		box["pos"] = pushed["pos"]
		return {"room": room, "pos": pos, "path": path}

	# 2) Tidak bisa didorong -> coba masuk ke dalam kotak (jika punya pintu di sisi ini)
	if box["target_room"] != "":
		var entry: Vector2i = _entry_pos(box["target_room"], dir)
		if entry != INVALID_POS:
			var in_path: Array = path
			if not mover_is_box:
				in_path = path + [box["id"]]
			return _resolve_move(box["target_room"], entry, dir, depth + 1, mover_is_box, in_path)

	return {}

# ==============================================================================
# 6. RENDER VISUAL PROSEDURAL (MINIATUR ISI KOTAK REKURSIF + ANIMASI ZOOM)
# ==============================================================================
func _calc_tile_size(rows: int, cols: int, vp: Vector2) -> float:
	var max_w: float = minf(vp.x - 490.0, vp.x * 0.52) if is_in_menu else vp.x * 0.92
	var avail := Vector2(max_w, vp.y - 120.0)
	var fit: float = floorf(minf(avail.x / float(cols), avail.y / float(rows)))
	return clampf(fit, 24.0, float(TILE_SIZE))

func _rebuild_visuals(transition: String, dash_from: Vector2i = INVALID_POS, dash_dir: Vector2i = Vector2i.ZERO, boxes_before: Array = []) -> void:
	if board_container != null:
		board_container.queue_free()

	board_container = Node2D.new()
	add_child(board_container)

	var active_r: String = game_state["active_room"]
	var room_data: Dictionary = rooms[active_r]
	var grid: Array = room_data["grid"]
	var theme: String = room_data["theme"]
	var rows_count: int = grid.size()
	var cols_count: int = grid[0].length()

	bg_rect.color = palette["bg_blue"] if theme == "blue" else palette["bg"]

	var vp_size: Vector2 = get_viewport_rect().size
	var ts: float = _calc_tile_size(rows_count, cols_count, vp_size)

	# Papan berpusat di tengah layar; di menu utama digeser ke kanan agar tidak tertutup seleksi menu
	if is_in_menu:
		var board_cx: float = maxf(vp_size.x * 0.68, 470.0 + (cols_count * ts) / 2.0)
		board_container.position = Vector2(board_cx, vp_size.y * 0.5)
	else:
		board_container.position = vp_size / 2.0 + Vector2(0.0, 24.0)
	var origin := -Vector2(cols_count, rows_count) * ts / 2.0 + Vector2(ts / 2.0, ts / 2.0)

	# 1. LANTAI, DINDING, TARGET & PINTU
	for y in range(rows_count):
		for x in range(cols_count):
			var ch: String = grid[y][x]
			var nb: Array = [
				_is_solid(active_r, Vector2i(x, y - 1)),
				_is_solid(active_r, Vector2i(x, y + 1)),
				_is_solid(active_r, Vector2i(x - 1, y)),
				_is_solid(active_r, Vector2i(x + 1, y))
			]
			var door_dir := Vector2i.ZERO
			if ch == "E":
				if x == 0: door_dir = Vector2i(-1, 0)
				elif x == cols_count - 1: door_dir = Vector2i(1, 0)
				elif y == 0: door_dir = Vector2i(0, -1)
				elif y == rows_count - 1: door_dir = Vector2i(0, 1)
			var tile_node := ProceduralTile.new(ch, theme, ts, palette, nb, door_dir)
			tile_node.position = origin + Vector2(x, y) * ts
			board_container.add_child(tile_node)

	# 2. KOTAK-KOTAK DI RUANGAN AKTIF
	for box in game_state["boxes"]:
		if box["room"] != active_r:
			continue
		var box_node := ProceduralBox.new(
			box["color"],
			box["target_room"],
			rooms,
			game_state["boxes"],
			game_state["player"],
			ts - 4.0,
			palette
		)
		var box_target: Vector2 = origin + Vector2(box["pos"].x, box["pos"].y) * ts
		var box_start: Vector2i = _old_box_pos(boxes_before, box)
		board_container.add_child(box_node)
		if box_start != INVALID_POS and box_start != box["pos"]:
			# Kotak ikut meluncur (dash) dari petak lamanya.
			box_node.position = origin + Vector2(box_start.x, box_start.y) * ts
			box_node.create_tween() \
				.tween_property(box_node, "position", box_target, MOVE_DURATION * 1.15) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			box_node.position = box_target

	# 3. KARAKTER PEMAIN
	var is_nested: bool = (active_r != "outer")
	var player_node := ProceduralPlayer.new(is_nested, ts - 8.0, palette)
	var p_pos: Vector2i = game_state["player"]["pos"]
	# Posisi lama hanya dipakai untuk dash di ruangan yang sama. Saat masuk/keluar
	# ruangan, koordinat lama berasal dari peta lain sehingga tidak boleh dipakai.
	var p_start: Vector2i = p_pos
	if transition == "move" and dash_from != INVALID_POS:
		p_start = dash_from
		if p_start != p_pos:
			# Bayangan dulu supaya tampil di bawah pemain.
			_spawn_dash_trail(
				origin + Vector2(p_start.x, p_start.y) * ts,
				origin + Vector2(p_pos.x, p_pos.y) * ts,
				ts - 8.0,
				is_nested
			)
	player_node.position = origin + Vector2(p_start.x, p_start.y) * ts
	board_container.add_child(player_node)

	hud_label.text = "%s   |   [WASD/Panah] Gerak   •   [Z] Undo   •   [R] Reset   •   [ESC] Menu" % room_data["name"]

	# 4. ANIMASI
	if transition == "enter":
		# Kamera "menyelam" ke dalam kotak
		is_animating = true
		board_container.scale = Vector2(0.25, 0.25)
		board_container.modulate.a = 0.0
		var tw_in := create_tween().set_parallel(true)
		tw_in.tween_property(board_container, "scale", Vector2.ONE, ZOOM_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw_in.tween_property(board_container, "modulate:a", 1.0, ZOOM_DURATION * 0.7)
		await tw_in.finished
		is_animating = false
	elif transition == "exit":
		# Kamera "mundur" keluar dari kotak
		is_animating = true
		board_container.scale = Vector2(2.4, 2.4)
		board_container.modulate.a = 0.0
		var tw_out := create_tween().set_parallel(true)
		tw_out.tween_property(board_container, "scale", Vector2.ONE, ZOOM_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw_out.tween_property(board_container, "modulate:a", 1.0, ZOOM_DURATION * 0.7)
		await tw_out.finished
		is_animating = false
	elif transition == "move":
		is_animating = true
		var target: Vector2 = origin + Vector2(p_pos.x, p_pos.y) * ts
		# Badan pemain memanjang ke arah gerak saat mulai meluncur.
		var stretch := Vector2(1.22, 0.84)
		if dash_dir.y != 0:
			stretch = Vector2(0.84, 1.22)
		player_node.scale = stretch

		# Luncuran halus: langsung bergerak lalu melambat saat hampir tiba.
		var tw := create_tween()
		tw.tween_property(player_node, "position", target, MOVE_DURATION) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

		# "Mendarat": badan sedikit memampat lalu memantul kembali normal.
		var squash := player_node.create_tween()
		squash.tween_property(player_node, "scale", Vector2(0.93, 1.07), MOVE_DURATION * 0.45) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		squash.tween_property(player_node, "scale", Vector2.ONE, MOVE_DURATION * 0.55) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		await tw.finished
		is_animating = false

# Posisi kotak yang sama di snapshot sebelumnya (dipakai untuk animasi dash).
func _old_box_pos(before: Array, box: Dictionary) -> Vector2i:
	for b in before:
		if b["id"] == box["id"] and b["room"] == box["room"]:
			return b["pos"]
	return INVALID_POS

# Jejak bayangan pemain saat dash. Tween diikat ke masing-masing bayangan,
# jadi ikut hilang otomatis ketika papan dibangun ulang.
func _spawn_dash_trail(from_pos: Vector2, to_pos: Vector2, sz: float, nested: bool) -> void:
	for i in range(DASH_TRAIL_COUNT):
		var t: float = float(i + 1) / float(DASH_TRAIL_COUNT + 1)
		var ghost := ProceduralPlayer.new(nested, sz, palette)
		ghost.position = from_pos.lerp(to_pos, t)
		ghost.modulate.a = 0.34 * (1.0 - t * 0.55)
		var skala: float = 1.0 - 0.16 * t
		ghost.scale = Vector2(skala, skala)
		board_container.add_child(ghost)

		var tw := ghost.create_tween().set_parallel(true)
		tw.tween_property(ghost, "modulate:a", 0.0, DASH_TRAIL_DURATION)
		tw.tween_property(ghost, "scale", Vector2(skala * 0.55, skala * 0.55), DASH_TRAIL_DURATION)
		tw.chain().tween_callback(ghost.queue_free)

# ==============================================================================
# 7. PENGECEKAN KONDISI MENANG & POP-UP UCAPAN SELAMAT
# ==============================================================================
# Menang bila SEMUA target 'G' (di ruangan mana pun) tertutup kotak
# dan pemain berdiri di target 'P'.
func _check_win_condition() -> void:
	for room_id in rooms.keys():
		var grid: Array = rooms[room_id]["grid"]
		for y in range(grid.size()):
			for x in range(grid[y].length()):
				var ch: String = grid[y][x]
				var pos := Vector2i(x, y)
				if ch == "G" and _get_box_at(room_id, pos).is_empty():
					return
				if ch == "P":
					var pl: Dictionary = game_state["player"]
					if pl["room"] != room_id or pl["pos"] != pos:
						return

	is_completed = true
	_update_step_hud()
	win_overlay.visible = true
	GameConfig.complete_level("level1")
	Sfx.play("win")

func _setup_win_overlay() -> void:
	win_overlay = CanvasLayer.new()
	win_overlay.layer = 10
	win_overlay.visible = false
	add_child(win_overlay)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.05, 0.06, 0.09, 0.82)
	win_overlay.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#1a1d2b")
	sb.border_color = palette["yellow"]
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(32)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var badge := Label.new()
	badge.text = "★ LEVEL 1 BERHASIL ★"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_color_override("font_color", palette["teal"])
	badge.add_theme_font_size_override("font_size", 14)
	vbox.add_child(badge)

	var title := Label.new()
	title.text = "SELAMAT!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", palette["yellow"])
	title.add_theme_font_size_override("font_size", 38)
	vbox.add_child(title)

	var msg := Label.new()
	msg.text = "Kamu berhasil mengantar kotak ke target di dalam kotak lain!\nKotak bisa menyimpan dunianya sendiri, termasuk targetnya."
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.add_theme_color_override("font_color", palette["text"])
	msg.add_theme_font_size_override("font_size", 15)
	vbox.add_child(msg)

	win_step_label = Label.new()
	win_step_label.text = "Total Langkah: 0"
	win_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_step_label.add_theme_color_override("font_color", palette["teal"])
	win_step_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(win_step_label)

	var next_btn := Button.new()
	next_btn.text = "  Lanjut ke Level 2 ▶  "
	next_btn.custom_minimum_size = Vector2(0, 52)
	var n_sb := StyleBoxFlat.new()
	n_sb.bg_color = palette["teal"]
	n_sb.set_corner_radius_all(8)
	next_btn.add_theme_stylebox_override("normal", n_sb)
	next_btn.add_theme_color_override("font_color", Color("#0d0f14"))
	next_btn.add_theme_font_size_override("font_size", 16)
	next_btn.pressed.connect(_go_to_level2)
	vbox.add_child(next_btn)

	var btn_box := HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 14)
	vbox.add_child(btn_box)

	var retry_btn := Button.new()
	retry_btn.text = "  ↺ Ulangi Level (R)  "
	retry_btn.custom_minimum_size = Vector2(0, 46)
	retry_btn.pressed.connect(func(): _reset_level(true))
	btn_box.add_child(retry_btn)

	var menu_btn := Button.new()
	menu_btn.text = "  ▶ Kembali ke Menu Utama  "
	menu_btn.custom_minimum_size = Vector2(0, 46)
	var m_sb := StyleBoxFlat.new()
	m_sb.bg_color = palette["blue"]
	m_sb.set_corner_radius_all(8)
	menu_btn.add_theme_stylebox_override("normal", m_sb)
	menu_btn.add_theme_color_override("font_color", Color("#0d0f14"))
	menu_btn.pressed.connect(_go_to_main_menu)
	btn_box.add_child(menu_btn)

func _go_to_main_menu() -> void:
	if ResourceLoader.exists(MAIN_MENU_PATH):
		get_tree().change_scene_to_file(MAIN_MENU_PATH)

func _go_to_level2() -> void:
	if ResourceLoader.exists(LEVEL2_PATH):
		get_tree().change_scene_to_file(LEVEL2_PATH)

# ==============================================================================
# 8. HELPER GRID & HUD
# ==============================================================================
func _tile_at(room_id: String, pos: Vector2i) -> String:
	var grid: Array = rooms[room_id]["grid"]
	if pos.y < 0 or pos.y >= grid.size() or pos.x < 0 or pos.x >= grid[0].length():
		return ""
	return grid[pos.y][pos.x]

# Dinding / luar peta dianggap "solid" (dipakai untuk bayangan & garis tepi dinding).
func _is_solid(room_id: String, pos: Vector2i) -> bool:
	var t: String = _tile_at(room_id, pos)
	return t == "" or t == "#"

# Petak 'E' hanya bisa dilewati bila bergerak KELUAR menembus tepi ruangan.
func _is_exit_dir(room_id: String, pos: Vector2i, dir: Vector2i) -> bool:
	var grid: Array = rooms[room_id]["grid"]
	var h: int = grid.size()
	var w: int = grid[0].length()
	return (pos.x == 0 and dir == Vector2i(-1, 0)) \
		or (pos.x == w - 1 and dir == Vector2i(1, 0)) \
		or (pos.y == 0 and dir == Vector2i(0, -1)) \
		or (pos.y == h - 1 and dir == Vector2i(0, 1))

# Petak tempat muncul bila memasuki ruangan sambil bergerak ke arah dir
# (bergerak ke kanan -> masuk lewat pintu di dinding KIRI, dst.).
func _entry_pos(room_id: String, dir: Vector2i) -> Vector2i:
	var grid: Array = rooms[room_id]["grid"]
	var h: int = grid.size()
	var w: int = grid[0].length()
	for y in range(h):
		for x in range(w):
			if grid[y][x] != "E":
				continue
			if dir == Vector2i(1, 0) and x == 0:
				return Vector2i(x + 1, y)
			if dir == Vector2i(-1, 0) and x == w - 1:
				return Vector2i(x - 1, y)
			if dir == Vector2i(0, 1) and y == 0:
				return Vector2i(x, y + 1)
			if dir == Vector2i(0, -1) and y == h - 1:
				return Vector2i(x, y - 1)
	return INVALID_POS

func _get_box_at(room_id: String, pos: Vector2i) -> Dictionary:
	for box in game_state["boxes"]:
		if box["room"] == room_id and box["pos"] == pos:
			return box
	return {}

func _get_box_by_id(box_id) -> Dictionary:
	for box in game_state["boxes"]:
		if box["id"] == box_id:
			return box
	return {}

# Kotak induk dari sebuah ruangan. Jika pemain masuk lewat kotak tertentu, kotak itulah yang dipakai.
func _find_parent_box(room_id: String, path: Array) -> Dictionary:
	if not path.is_empty():
		var preferred: Dictionary = _get_box_by_id(path.back())
		if not preferred.is_empty() and preferred["target_room"] == room_id:
			return preferred
	for box in game_state["boxes"]:
		if box["target_room"] == room_id:
			return box
	return {}

func _setup_hud() -> void:
	bg_layer = CanvasLayer.new()
	bg_layer.layer = -1
	add_child(bg_layer)

	bg_rect = ColorRect.new()
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_rect.color = palette["bg"]
	bg_layer.add_child(bg_rect)

	hud_layer = CanvasLayer.new()
	hud_layer.layer = 5
	add_child(hud_layer)

	hud_label = Label.new()
	hud_label.position = Vector2(36, 28)
	hud_label.add_theme_font_size_override("font_size", 17)
	hud_label.add_theme_color_override("font_color", palette["wall_highlight"])
	hud_layer.add_child(hud_label)

	step_panel = PanelContainer.new()
	step_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	step_panel.anchor_left = 1.0
	step_panel.anchor_right = 1.0
	step_panel.offset_left = -196
	step_panel.offset_top = 20
	step_panel.offset_right = -36
	step_panel.offset_bottom = 60
	var sb_step := StyleBoxFlat.new()
	sb_step.bg_color = Color("#1a1d2b")
	sb_step.border_color = palette["yellow"]
	sb_step.set_border_width_all(2)
	sb_step.set_corner_radius_all(12)
	sb_step.set_content_margin_all(8)
	sb_step.content_margin_left = 16
	sb_step.content_margin_right = 16
	step_panel.add_theme_stylebox_override("panel", sb_step)

	step_label = Label.new()
	step_label.text = "LANGKAH: 0"
	step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	step_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	step_label.add_theme_font_size_override("font_size", 15)
	step_label.add_theme_color_override("font_color", palette["yellow"])
	step_panel.add_child(step_label)
	hud_layer.add_child(step_panel)

func _update_step_hud() -> void:
	if step_label != null:
		step_label.text = "LANGKAH: %d" % step_count
	if win_step_label != null:
		win_step_label.text = "Total Langkah: %d" % step_count

# ==============================================================================
# 9. INNER CLASSES: MENGGAMBAR SPRITE VEKTOR & MINIATUR RUANGAN (_draw)
# ==============================================================================
class ProceduralTile extends Node2D:
	var type: String
	var theme: String
	var sz: float
	var pal: Dictionary
	var nb: Array            # [atas, bawah, kiri, kanan] -> true bila tetangga itu dinding
	var door_dir: Vector2i

	func _init(p_type: String, p_theme: String, p_sz: float, p_pal: Dictionary, p_nb: Array, p_door: Vector2i) -> void:
		type = p_type
		theme = p_theme
		sz = p_sz
		pal = p_pal
		nb = p_nb
		door_dir = p_door

	func _draw() -> void:
		var half: float = sz / 2.0
		var rect := Rect2(Vector2(-half, -half), Vector2(sz, sz))
		var is_blue: bool = theme == "blue"
		var wall_col: Color = pal["blue_wall"] if is_blue else pal["wall"]
		var floor_col: Color = pal["blue_floor"] if is_blue else pal["floor"]
		var lit_col: Color = pal["blue_light"] if is_blue else pal["wall_highlight"]
		var band: float = maxf(4.0, sz * 0.09)

		if type == "#":
			draw_rect(rect, wall_col, true)
			# garis terang di sisi dinding yang menghadap lantai
			if not nb[0]: draw_rect(Rect2(Vector2(-half, -half), Vector2(sz, band)), lit_col, true)
			if not nb[1]: draw_rect(Rect2(Vector2(-half, half - band), Vector2(sz, band)), lit_col, true)
			if not nb[2]: draw_rect(Rect2(Vector2(-half, -half), Vector2(band, sz)), lit_col, true)
			if not nb[3]: draw_rect(Rect2(Vector2(half - band, -half), Vector2(band, sz)), lit_col, true)
			return

		draw_rect(rect, floor_col, true)
		# bayangan lantai di dekat dinding
		var shade := Color(0, 0, 0, 0.20)
		var sh: float = band * 1.4
		if nb[0]: draw_rect(Rect2(Vector2(-half, -half), Vector2(sz, sh)), shade, true)
		if nb[1]: draw_rect(Rect2(Vector2(-half, half - sh), Vector2(sz, sh)), shade, true)
		if nb[2]: draw_rect(Rect2(Vector2(-half, -half), Vector2(sh, sz)), shade, true)
		if nb[3]: draw_rect(Rect2(Vector2(half - sh, -half), Vector2(sh, sz)), shade, true)

		if type == "G":
			var g_rect := Rect2(Vector2(-sz * 0.34, -sz * 0.34), Vector2(sz * 0.68, sz * 0.68))
			draw_rect(g_rect, lit_col, false, 4.0)
		elif type == "P":
			var p_rect := Rect2(Vector2(-sz * 0.34, -sz * 0.34), Vector2(sz * 0.68, sz * 0.68))
			draw_rect(p_rect, lit_col, false, 4.0)
			draw_circle(Vector2(-sz * 0.13, sz * 0.03), sz * 0.045, lit_col)
			draw_circle(Vector2(sz * 0.13, sz * 0.03), sz * 0.045, lit_col)
		elif type == "E":
			# pintu: strip kuning di tepi ruangan sisi tempat pintu berada
			var thick: float = 10.0
			var long_side: float = sz * 0.56
			var r: Rect2
			if door_dir.x == -1:
				r = Rect2(Vector2(-half, -long_side / 2.0), Vector2(thick, long_side))
			elif door_dir.x == 1:
				r = Rect2(Vector2(half - thick, -long_side / 2.0), Vector2(thick, long_side))
			elif door_dir.y == -1:
				r = Rect2(Vector2(-long_side / 2.0, -half), Vector2(long_side, thick))
			else:
				r = Rect2(Vector2(-long_side / 2.0, half - thick), Vector2(long_side, thick))
			draw_rect(r, pal["yellow"], true)

class ProceduralBox extends Node2D:
	var color_name: String
	var target_room: String
	var rooms: Dictionary
	var boxes: Array
	var player: Dictionary
	var sz: float
	var pal: Dictionary

	func _init(p_col: String, p_target: String, p_rooms: Dictionary, p_boxes: Array, p_player: Dictionary, p_sz: float, p_pal: Dictionary) -> void:
		color_name = p_col
		target_room = p_target
		rooms = p_rooms
		boxes = p_boxes
		player = p_player
		sz = p_sz
		pal = p_pal

	func _draw() -> void:
		var half: float = sz / 2.0
		var main_col: Color = pal[color_name]

		draw_rect(Rect2(Vector2(-half, -half), Vector2(sz, sz)), main_col.darkened(0.30), true)
		var body := Rect2(Vector2(-half + 3, -half + 3), Vector2(sz - 6, sz - 6))
		draw_rect(body, main_col, true)

		if target_room != "":
			# Miniatur isi ruangan di dalam kotak (seperti di video)
			_draw_room_preview(target_room, body.grow(-sz * 0.08), 0)

	# Menggambar ruangan `room_id` mengecil di dalam `area`. Kotak rekursif di dalamnya
	# digambar lagi (maks 2 tingkat) dan pemain ikut tampak bila sedang berada di sana.
	func _draw_room_preview(room_id: String, area: Rect2, depth: int) -> void:
		var grid: Array = rooms[room_id]["grid"]
		var theme: String = rooms[room_id]["theme"]
		var is_blue: bool = theme == "blue"
		var floor_col: Color = pal["blue_floor"] if is_blue else pal["floor"]
		var wall_col: Color = pal["blue_wall"] if is_blue else pal["wall"]
		var lit_col: Color = pal["blue_light"] if is_blue else pal["wall_highlight"]

		var r_cnt: int = grid.size()
		var c_cnt: int = grid[0].length()
		var cell := Vector2(area.size.x / float(c_cnt), area.size.y / float(r_cnt))

		draw_rect(area, floor_col, true)
		for y in range(r_cnt):
			for x in range(c_cnt):
				var ch: String = grid[y][x]
				var cell_rect := Rect2(area.position + Vector2(x * cell.x, y * cell.y), cell)
				if ch == "#":
					draw_rect(Rect2(cell_rect.position, cell + Vector2(0.6, 0.6)), wall_col, true)
				elif ch == "G" or ch == "P":
					draw_rect(cell_rect.grow(-cell.x * 0.15), lit_col, false, 1.0)

		for ib in boxes:
			if ib["room"] != room_id:
				continue
			var b_pos: Vector2i = ib["pos"]
			var b_rect := Rect2(area.position + Vector2(b_pos.x * cell.x, b_pos.y * cell.y), cell).grow(-cell.x * 0.06)
			draw_rect(b_rect, pal[ib["color"]], true)
			if ib["target_room"] != "" and depth < 2 and b_rect.size.x > 6.0:
				_draw_room_preview(ib["target_room"], b_rect.grow(-b_rect.size.x * 0.10), depth + 1)

		if player["room"] == room_id:
			var pp: Vector2i = player["pos"]
			var p_rect := Rect2(area.position + Vector2(pp.x * cell.x, pp.y * cell.y), cell).grow(-cell.x * 0.1)
			draw_rect(p_rect, pal["pink"], true)

class ProceduralPlayer extends Node2D:
	var is_nested: bool
	var sz: float
	var pal: Dictionary

	func _init(p_nested: bool, p_sz: float, p_pal: Dictionary) -> void:
		is_nested = p_nested
		sz = p_sz
		pal = p_pal

	func _draw() -> void:
		var half: float = sz / 2.0
		var main_col: Color = pal["pink"]
		draw_rect(Rect2(Vector2(-half, -half), Vector2(sz, sz)), main_col.darkened(0.30), true)
		var body := Rect2(Vector2(-half + 3, -half + 3), Vector2(sz - 6, sz - 6))
		draw_rect(body, main_col, true)

		if is_nested:
			draw_rect(body.grow(-sz * 0.12), pal["pink_inner"], true)
			draw_rect(body.grow(-sz * 0.19), main_col, true)

		var eye_x: float = sz * 0.17
		draw_circle(Vector2(-eye_x, sz * 0.03), sz * 0.06, pal["outline"])
		draw_circle(Vector2(eye_x, sz * 0.03), sz * 0.06, pal["outline"])
