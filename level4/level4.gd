extends Node2D

# ==============================================================================
# LEVEL 4 - "DUA KOTAK BIRU"
#
# Dua kotak biru TERPISAH, masing-masing punya ruangan sendiri berisi peti kuning:
#   - Kotak Biru A (pintu di sisi KIRI)  : berisi 2 peti
#   - Kotak Biru B (pintu di sisi KANAN) : berisi 1 peti
# Ada 3 target kotak 'G' di ruang luar, jadi semua peti harus dikeluarkan.
#   1. Pojokkan kotak biru ke dinding/benda lain supaya tidak bisa bergeser.
#   2. Masuk dari sisi pintunya, dorong peti ke pintu 'E' sampai keluar.
#   3. Dorong semua peti ke target 'G', lalu injak target 'P'.
# ==============================================================================

# ==============================================================================
# 1. KONFIGURASI UKURAN GRID & WARNA
# ==============================================================================
const TILE_SIZE: int = 76
const MOVE_DURATION: float = 0.13
const ZOOM_DURATION: float = 0.30
const DASH_TRAIL_COUNT: int = 3
const DASH_TRAIL_DURATION: float = 0.22
const MAX_DEPTH: int = 40
const INVALID_POS := Vector2i(-1, -1)
const MAIN_MENU_PATH: String = "res://main_menu/main_menu.tscn"
const LEVEL5_PATH: String = "res://level5/level5.tscn"

var palette := {
	"bg": Color("#180f0c"),
	"bg_blue": Color("#2f5572"),
	"bg_purple": Color("#20122b"),
	"floor": Color("#77432b"),
	"wall": Color("#ffaa77"),
	"wall_highlight": Color("#fbe49a"),
	"outline": Color("#323c79"),
	"blue": Color("#78a0ff"),
	"blue_floor": Color("#2358ea"),
	"blue_wall": Color("#b6dcee"),
	"blue_light": Color("#e8f7ff"),
	"yellow": Color("#fde069"),
	"yellow_inner": Color("#ca8a04"),
	"yellow_floor": Color("#6d4f12"),
	"yellow_wall": Color("#e8c96a"),
	"yellow_light": Color("#fff0b8"),
	"bg_yellow": Color("#3d2f0a"),
	"purple": Color("#a29bfe"),
	"purple_inner": Color("#6c5ce7"),
	"purple_floor": Color("#4a3264"),
	"purple_wall": Color("#c4bbf0"),
	"purple_light": Color("#f2e6ff"),
	"pink": Color("#de6edc"),
	"pink_inner": Color("#a21caf"),
	"teal": Color("#4ecdc4"),
	"text": Color("#f1f2f6")
}

# Tema per ruangan: dinding, lantai, garis terang, dan warna latar layar.
var themes := {
	"orange": {
		"wall": Color("#ffaa77"),
		"floor": Color("#77432b"),
		"light": Color("#fbe49a"),
		"bg": Color("#180f0c")
	},
	"blue": {
		"wall": Color("#b6dcee"),
		"floor": Color("#2358ea"),
		"light": Color("#e8f7ff"),
		"bg": Color("#2f5572")
	},
	"purple": {
		"wall": Color("#c4bbf0"),
		"floor": Color("#4a3264"),
		"light": Color("#f2e6ff"),
		"bg": Color("#20122b")
	}
}

# ==============================================================================
# 2. DEFINISI PETA RUANGAN
# ==============================================================================
# '#' dinding, '.' lantai, 'G' target kotak, 'P' target pemain, 'E' pintu.
var rooms := {
	"outer": {
		"name": "Level 4 - Dua Kotak Biru",
		"theme": "orange",
		"grid": [
			"#########",
			"#P......#",
			"#..#.G#.#",
			"#.##....#",
			"#.......#",
			"#.G....G#",
			"#########"
		]
	},
	"in_blue_a": {
		"name": "Dalam Kotak Biru A",
		"theme": "blue",
		"grid": [
			"#######",
			"###..##",
			"#.....#",
			"E.....#",
			"#.#...#",
			"#...###",
			"#######"
		]
	},
	"in_blue_b": {
		"name": "Dalam Kotak Biru B",
		"theme": "blue",
		"grid": [
			"#######",
			"#.....#",
			"#..#..#",
			"#.....E",
			"#.#...#",
			"#######"
		]
	}
}

var game_state := {}
var undo_stack: Array[Dictionary] = []
var is_animating: bool = false
var is_completed: bool = false
var step_count: int = 0

var board_container: Node2D
var hud_layer: CanvasLayer
var hud_label: Label
var step_panel: PanelContainer
var step_label: Label
var bg_rect: ColorRect
var win_overlay: CanvasLayer
var win_step_label: Label

func _ready() -> void:
	_setup_hud()
	_setup_win_overlay()
	_reset_level()

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
			"pos": Vector2i(3, 1),
			"path": []
		},
		"boxes": [
			{
				"id": "box_blue_1",
				"room": "outer",
				"pos": Vector2i(6, 3),
				"color": "blue",
				"target_room": "in_blue_a"
			},
			{
				"id": "box_blue_2",
				"room": "outer",
				"pos": Vector2i(2, 4),
				"color": "blue",
				"target_room": "in_blue_b"
			},
			{
				"id": "crate_a",
				"room": "in_blue_a",
				"pos": Vector2i(3, 3),
				"color": "yellow",
				"target_room": ""
			},
			{
				"id": "crate_b",
				"room": "in_blue_a",
				"pos": Vector2i(4, 2),
				"color": "yellow",
				"target_room": ""
			},
			{
				"id": "crate_c",
				"room": "in_blue_b",
				"pos": Vector2i(2, 2),
				"color": "yellow",
				"target_room": ""
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
	if is_animating:
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
	var avail := Vector2(vp.x * 0.92, vp.y - 110.0)
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

	bg_rect.color = themes[theme]["bg"]

	var vp_size: Vector2 = get_viewport_rect().size
	var ts: float = _calc_tile_size(rows_count, cols_count, vp_size)

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
			var tile_node := ProceduralTile.new(ch, theme, ts, palette, themes, nb, door_dir)
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
			themes,
			game_state["boxes"],
			game_state["player"],
			ts - 4.0,
			palette
		)
		var box_target: Vector2 = origin + Vector2(box["pos"].x, box["pos"].y) * ts
		var box_start: Vector2i = _old_box_pos(boxes_before, box)
		board_container.add_child(box_node)
		if box_start != INVALID_POS and box_start != box["pos"]:
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
	var p_start: Vector2i = p_pos
	if transition == "move" and dash_from != INVALID_POS:
		p_start = dash_from
		if p_start != p_pos:
			_spawn_dash_trail(
				origin + Vector2(p_start.x, p_start.y) * ts,
				origin + Vector2(p_pos.x, p_pos.y) * ts,
				ts - 8.0,
				is_nested
			)
	player_node.position = origin + Vector2(p_start.x, p_start.y) * ts
	board_container.add_child(player_node)

	hud_label.text = room_data["name"]

	# 4. ANIMASI
	if transition == "enter":
		is_animating = true
		board_container.scale = Vector2(0.25, 0.25)
		board_container.modulate.a = 0.0
		var tw_in := create_tween().set_parallel(true)
		tw_in.tween_property(board_container, "scale", Vector2.ONE, ZOOM_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw_in.tween_property(board_container, "modulate:a", 1.0, ZOOM_DURATION * 0.7)
		await tw_in.finished
		is_animating = false
	elif transition == "exit":
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
		var stretch := Vector2(1.22, 0.84)
		if dash_dir.y != 0:
			stretch = Vector2(0.84, 1.22)
		player_node.scale = stretch

		var tw := create_tween()
		tw.tween_property(player_node, "position", target, MOVE_DURATION) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

		var squash := player_node.create_tween()
		squash.tween_property(player_node, "scale", Vector2(0.93, 1.07), MOVE_DURATION * 0.45) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		squash.tween_property(player_node, "scale", Vector2.ONE, MOVE_DURATION * 0.55) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		await tw.finished
		is_animating = false

func _old_box_pos(before: Array, box: Dictionary) -> Vector2i:
	for b in before:
		if b["id"] == box["id"] and b["room"] == box["room"]:
			return b["pos"]
	return INVALID_POS

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
func _check_win_condition() -> void:
	for room_id in rooms.keys():
		var grid: Array = rooms[room_id]["grid"]
		for y in range(grid.size()):
			for x in range(grid[y].length()):
				var ch: String = grid[y][x]
				var pos := Vector2i(x, y)
				if ch == "G":
					# Hanya peti kuning (tanpa ruangan) yang dihitung mengisi target.
					var on_goal: Dictionary = _get_box_at(room_id, pos)
					if on_goal.is_empty() or on_goal["target_room"] != "":
						return
				if ch == "P":
					var pl: Dictionary = game_state["player"]
					if pl["room"] != room_id or pl["pos"] != pos:
						return

	is_completed = true
	_update_step_hud()
	win_overlay.visible = true
	GameConfig.complete_level("level4")
	Sfx.play("win")

func _setup_win_overlay() -> void:
	var ui: Dictionary = MenuUI.build_win_overlay(
		self,
		"LEVEL 4 SELESAI",
		"SELAMAT!",
		"Tiga peti berhasil keluar dari dua kotak biru!\nSetiap kotak punya dimensinya sendiri.",
		palette["purple_light"],
		"Lanjut ke Level 5",
		_go_to_level5,
		func(): _reset_level(true),
		_go_to_main_menu
	)
	win_overlay = ui["win_overlay"]
	win_step_label = ui["win_step_label"]

func _go_to_level5() -> void:
	if ResourceLoader.exists(LEVEL5_PATH):
		get_tree().change_scene_to_file(LEVEL5_PATH)

func _go_to_main_menu() -> void:
	if ResourceLoader.exists(MAIN_MENU_PATH):
		get_tree().change_scene_to_file(MAIN_MENU_PATH)

# ==============================================================================
# 8. HELPER GRID & HUD
# ==============================================================================
func _tile_at(room_id: String, pos: Vector2i) -> String:
	var grid: Array = rooms[room_id]["grid"]
	if pos.y < 0 or pos.y >= grid.size() or pos.x < 0 or pos.x >= grid[0].length():
		return ""
	return grid[pos.y][pos.x]

func _is_solid(room_id: String, pos: Vector2i) -> bool:
	var t: String = _tile_at(room_id, pos)
	return t == "" or t == "#"

func _is_exit_dir(room_id: String, pos: Vector2i, dir: Vector2i) -> bool:
	var grid: Array = rooms[room_id]["grid"]
	var h: int = grid.size()
	var w: int = grid[0].length()
	return (pos.x == 0 and dir == Vector2i(-1, 0)) \
		or (pos.x == w - 1 and dir == Vector2i(1, 0)) \
		or (pos.y == 0 and dir == Vector2i(0, -1)) \
		or (pos.y == h - 1 and dir == Vector2i(0, 1))

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
	var ui: Dictionary = MenuUI.build_game_hud(
		self,
		palette["bg"],
		palette["wall"],
		_go_to_main_menu,
		_undo_move,
		func(): _reset_level(true)
	)
	bg_rect = ui["bg_rect"]
	hud_layer = ui["hud_layer"]
	hud_label = ui["hud_label"]
	step_panel = ui["step_panel"]
	step_label = ui["step_label"]

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
	var themes: Dictionary
	var nb: Array
	var door_dir: Vector2i

	func _init(p_type: String, p_theme: String, p_sz: float, p_pal: Dictionary, p_themes: Dictionary, p_nb: Array, p_door_dir: Vector2i) -> void:
		type = p_type
		theme = p_theme
		sz = p_sz
		pal = p_pal
		themes = p_themes
		nb = p_nb
		door_dir = p_door_dir

	func _draw() -> void:
		var half: float = sz / 2.0
		var rect := Rect2(Vector2(-half, -half), Vector2(sz, sz))
		var th: Dictionary = themes[theme]
		var wall_col: Color = th["wall"]
		var floor_col: Color = th["floor"]
		var lit_col: Color = th["light"]
		var band: float = maxf(4.0, sz * 0.09)

		if type == "#":
			draw_rect(rect, wall_col, true)
			if not nb[0]: draw_rect(Rect2(Vector2(-half, -half), Vector2(sz, band)), lit_col, true)
			if not nb[1]: draw_rect(Rect2(Vector2(-half, half - band), Vector2(sz, band)), lit_col, true)
			if not nb[2]: draw_rect(Rect2(Vector2(-half, -half), Vector2(band, sz)), lit_col, true)
			if not nb[3]: draw_rect(Rect2(Vector2(half - band, -half), Vector2(band, sz)), lit_col, true)
			return

		draw_rect(rect, floor_col, true)
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
	var themes: Dictionary
	var boxes: Array
	var player: Dictionary
	var sz: float
	var pal: Dictionary

	func _init(p_col: String, p_target: String, p_rooms: Dictionary, p_themes: Dictionary, p_boxes: Array, p_player: Dictionary, p_sz: float, p_pal: Dictionary) -> void:
		color_name = p_col
		target_room = p_target
		rooms = p_rooms
		themes = p_themes
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
			_draw_room_preview(target_room, body.grow(-sz * 0.08), 0)

	func _draw_room_preview(room_id: String, area: Rect2, depth: int) -> void:
		var grid: Array = rooms[room_id]["grid"]
		var th: Dictionary = themes[rooms[room_id]["theme"]]
		var floor_col: Color = th["floor"]
		var wall_col: Color = th["wall"]
		var lit_col: Color = th["light"]
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
