extends Node2D

# ==========================================
# KONFIGURASI GAME & PALET ASET PARABOX
# ==========================================
const TILE_SIZE = 72
const GRID_W = 12
const GRID_H = 9

const COL_BG = Color("#181a24")
const COL_FLOOR = Color("#232736")
const COL_FLOOR_GRID = Color("#2c3144")
const COL_OUTLINE = Color("#0d0f14")

const PALETTE = {
	"wall_outer": Color("#464d63"),
	"wall_inner": Color("#34394a"),
	"blue_outer": Color("#2d9cdb"),
	"blue_inner": Color("#1b5e8a"),
	"yellow_outer": Color("#f2b824"),
	"yellow_inner": Color("#9c7211"),
	"green_outer": Color("#4cd180"),
	"green_inner": Color("#2b854e"),
	"red_outer": Color("#eb4d63"),
	"red_inner": Color("#992938"),
	"purple_outer": Color("#9b6ef3"),
	"purple_inner": Color("#5d3c9e"),
	"wood_outer": Color("#c87d44"),
	"wood_inner": Color("#96582a")
}

enum TileType {
	EMPTY,
	WALL,
	GOAL,
	PORTAL_OUT
}

class Room:
	var id: String
	var theme: String
	var grid: Array = []
	var entities: Array = []
	var parent_box: Entity = null
	var entry_spawn: Vector2i = Vector2i(1, 4)
	
	func _init(_id: String, _theme: String = "slate"):
		id = _id
		theme = _theme
		for y in range(GRID_H):
			var row = []
			for x in range(GRID_W):
				row.append(TileType.EMPTY)
			grid.append(row)

class Entity:
	var type: String # "player" atau "box"
	var pos: Vector2i
	var room: Room
	var inner_room: Room = null
	var entry_dir: Vector2i = Vector2i.ZERO
	var style: String # "green", "blue", "wood"

	func _init(_type: String, _pos: Vector2i, _room: Room, _style: String):
		type = _type
		pos = _pos
		room = _room
		style = _style

# ==========================================
# VARIABEL GLOBAL & KAMERA VIRTUAL
# ==========================================
var rooms: Dictionary = {}
var current_room: Room
var player: Entity
var target_crate: Entity # Satu peti kayu dari dalam box yang harus ditaruh di Goal
var cam_offset: Vector2 = Vector2.ZERO
var is_won: bool = false
var step_count: int = 0

func _ready():
	setup_tutorial_level()
	snap_camera_to_player()

func snap_camera_to_player():
	if player != null:
		var vp_center = get_viewport_rect().size / 2.0
		var p_world = Vector2(player.pos.x * TILE_SIZE + TILE_SIZE / 2.0, player.pos.y * TILE_SIZE + TILE_SIZE / 2.0)
		cam_offset = vp_center - p_world

# ==========================================
# SETUP LEVEL TUTORIAL (1 PETI DARI DALAM BOX)
# ==========================================
func setup_tutorial_level():
	rooms.clear()
	is_won = false
	step_count = 0
	
	# 1. Ruangan Utama (Outer Room)
	var outer = Room.new("RUANG LUAR (1/2)", "slate")
	build_room_walls(outer)
	
	# Dinding pembatas di kanan sebagai sandaran untuk mementokkan Box Biru
	for y in range(2, 7):
		outer.grid[y][7] = TileType.WALL
		
	# Target kuning tempat meletakkan 1 peti kayu dari dalam box
	outer.grid[2][4] = TileType.GOAL
	
	# 2. Ruangan Dalam Box Biru (Inner Room)
	var inner = Room.new("DALAM BOX BIRU (2/2)", "blue")
	build_room_walls(inner)
	
	# Pintu masuk & keluar berada di sisi KIRI (x = 0, y = 4)
	inner.grid[4][0] = TileType.PORTAL_OUT
	inner.entry_spawn = Vector2i(1, 4)
	
	# Sekat kecil di dalam ruangan biru
	inner.grid[2][5] = TileType.WALL
	inner.grid[3][5] = TileType.WALL
	inner.grid[5][5] = TileType.WALL
	inner.grid[6][5] = TileType.WALL
	
	# HANYA 1 KOTAK KAYU di dalam Box Biru yang harus dibawa keluar & ditaruh di Goal
	target_crate = Entity.new("box", Vector2i(3, 4), inner, "wood")
	inner.entities.append(target_crate)
	
	# 3. Box Rekursif Biru di Ruangan Utama (Lubang di sisi KIRI)
	var paradox_box = Entity.new("box", Vector2i(4, 4), outer, "blue")
	paradox_box.inner_room = inner
	paradox_box.entry_dir = Vector2i.LEFT
	inner.parent_box = paradox_box
	outer.entities.append(paradox_box)
	
	# 4. Karakter Pemain di sisi kiri
	player = Entity.new("player", Vector2i(2, 4), outer, "green")
	outer.entities.append(player)
	
	rooms["Outer"] = outer
	rooms["Inner"] = inner
	current_room = outer
	queue_redraw()

func build_room_walls(r: Room):
	for y in range(GRID_H):
		for x in range(GRID_W):
			if x == 0 or x == GRID_W - 1 or y == 0 or y == GRID_H - 1:
				r.grid[y][x] = TileType.WALL

# ==========================================
# INPUT & KONTROL (WASD + PANAH)
# ==========================================
func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_W, KEY_UP]:
			_gerak(Vector2i.UP)
		elif event.keycode in [KEY_S, KEY_DOWN]:
			_gerak(Vector2i.DOWN)
		elif event.keycode in [KEY_A, KEY_LEFT]:
			_gerak(Vector2i.LEFT)
		elif event.keycode in [KEY_D, KEY_RIGHT]:
			_gerak(Vector2i.RIGHT)
		elif event.keycode == KEY_R:
			Sfx.play("reset")
			setup_tutorial_level()
			snap_camera_to_player()
		elif event.keycode == KEY_ESCAPE:
			if ResourceLoader.exists("res://main_menu/main_menu.tscn"):
				get_tree().change_scene_to_file("res://main_menu/main_menu.tscn")

func _gerak(dir: Vector2i) -> void:
	if is_won:
		return
	Sfx.play("move" if try_move(player, dir) else "blocked")

# ==========================================
# LOGIKA PERGERAKAN REKURSIF (MENTOK BARU MASUK)
# ==========================================
func try_move(entity: Entity, dir: Vector2i) -> bool:
	if is_won:
		return false
		
	var target_pos = entity.pos + dir
	var r = entity.room
	
	# 1. Keluar batas ruangan (saat mendorong/berjalan melewati pintu keluar)
	if target_pos.x < 0 or target_pos.x >= GRID_W or target_pos.y < 0 or target_pos.y >= GRID_H:
		if r.parent_box != null:
			return exit_box(entity, r.parent_box, dir)
		return false
		
	var target_tile = r.grid[target_pos.y][target_pos.x]
	if target_tile == TileType.WALL:
		return false
		
	# 2. Cek jika menabrak entitas lain (Box)
	var target_entity = get_entity_at(r, target_pos)
	if target_entity != null:
		# PRIORITAS 1: Dorong entitas terlebih dahulu jika masih ada ruang kosong di depannya
		if try_move(target_entity, dir):
			move_entity_to(entity, r, target_pos)
			if entity == player: step_count += 1
			check_win_condition()
			return true
		else:
			# PRIORITAS 2: Jika box sudah MENTOK tembok/halangan, baru bisa masuk lewat lubangnya
			if target_entity.inner_room != null and target_entity.entry_dir == -dir:
				return enter_box(entity, target_entity, dir)
			return false
			
	# 3. Pindah ke petak kosong / menginjak pintu keluar
	move_entity_to(entity, r, target_pos)
	if entity == player: step_count += 1
	
	if target_tile == TileType.PORTAL_OUT and r.parent_box != null and dir == r.parent_box.entry_dir:
		exit_box(entity, r.parent_box, dir)
		
	check_win_condition()
	return true

func enter_box(entity: Entity, box: Entity, dir: Vector2i) -> bool:
	var in_room = box.inner_room
	var spawn_pos = in_room.entry_spawn
	
	var blocking = get_entity_at(in_room, spawn_pos)
	if blocking != null:
		if not try_move(blocking, dir):
			return false
			
	move_entity_to(entity, in_room, spawn_pos)
	if entity == player:
		current_room = in_room
		step_count += 1
	return true

func exit_box(entity: Entity, parent_box: Entity, dir: Vector2i) -> bool:
	var out_room = parent_box.room
	var exit_pos = parent_box.pos + dir
	
	if exit_pos.x < 0 or exit_pos.x >= GRID_W or exit_pos.y < 0 or exit_pos.y >= GRID_H:
		return false
		
	if out_room.grid[exit_pos.y][exit_pos.x] == TileType.WALL:
		return false
		
	var blocking = get_entity_at(out_room, exit_pos)
	if blocking != null:
		if not try_move(blocking, dir):
			return false
			
	move_entity_to(entity, out_room, exit_pos)
	if entity == player:
		current_room = out_room
	return true

func move_entity_to(entity: Entity, new_room: Room, new_pos: Vector2i):
	entity.room.entities.erase(entity)
	entity.room = new_room
	entity.pos = new_pos
	new_room.entities.append(entity)
	queue_redraw()

func get_entity_at(r: Room, pos: Vector2i) -> Entity:
	for e in r.entities:
		if e.pos == pos:
			return e
	return null

# Menang jika 1 peti kayu dari dalam box sudah ditaruh tepat di atas Goal Ruang Luar
func check_win_condition():
	if target_crate.room == rooms["Outer"] and rooms["Outer"].grid[target_crate.pos.y][target_crate.pos.x] == TileType.GOAL:
		is_won = true
		GameConfig.complete_level("tutorial")
		Sfx.play("win")
		queue_redraw()

# ==========================================
# KAMERA VIRTUAL & RENDER GAYA SPRITE SHEET
# ==========================================
func _process(delta):
	if player == null:
		return
	var vp_center = get_viewport_rect().size / 2.0
	var p_world = Vector2(player.pos.x * TILE_SIZE + TILE_SIZE / 2.0, player.pos.y * TILE_SIZE + TILE_SIZE / 2.0)
	var target_offset = vp_center - p_world
	cam_offset = cam_offset.lerp(target_offset, 12.0 * delta)
	queue_redraw()

func _draw():
	if current_room == null:
		return
		
	var vp_size = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp_size), COL_BG, true)
	
	draw_set_transform(cam_offset, 0.0, Vector2.ONE)
	
	var room_rect = Rect2(-6, -6, GRID_W * TILE_SIZE + 12, GRID_H * TILE_SIZE + 12)
	_draw_rounded_box(room_rect, COL_FLOOR, COL_OUTLINE, 6.0, 14)
	
	# 1. Gambar Lantai, Tembok, Goal & Portal
	for y in range(GRID_H):
		for x in range(GRID_W):
			var cell = Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			var tile = current_room.grid[y][x]
			
			draw_circle(cell.get_center(), 2.5, COL_FLOOR_GRID)
			
			if tile == TileType.WALL:
				var w_outer = PALETTE["blue_outer"] if current_room.theme == "blue" else PALETTE["wall_outer"]
				var w_inner = PALETTE["blue_inner"] if current_room.theme == "blue" else PALETTE["wall_inner"]
				_draw_bevel_tile(cell.grow(-2), w_outer, w_inner, 10)
				
			elif tile == TileType.GOAL:
				_draw_goal_brackets(cell.grow(-8), PALETTE["yellow_outer"])
				
			elif tile == TileType.PORTAL_OUT:
				var p_rect = cell.grow(-4)
				_draw_rounded_box(p_rect, Color("#1c3b47"), PALETTE["blue_outer"], 3.0, 8)
				_draw_arrow_icon(cell.get_center(), Vector2.LEFT, PALETTE["yellow_outer"], 12.0)
				
	# 2. Gambar Entitas (Player & Box)
	for e in current_room.entities:
		var box_rect = Rect2(e.pos.x * TILE_SIZE + 3, e.pos.y * TILE_SIZE + 3, TILE_SIZE - 6, TILE_SIZE - 6)
		
		if e.type == "player":
			_draw_player_sprite(box_rect)
		elif e.style == "wood":
			_draw_crate_sprite(box_rect)
		elif e.inner_room != null:
			_draw_parabox_sprite(box_rect, e)
			
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_parabox_ui()

# ==========================================
# HELPER GAMBAR GAYA ASET KARTUN TEBAL
# ==========================================
func _draw_rounded_box(rect: Rect2, fill_col: Color, border_col: Color, border_w: float, radius: int):
	var sb = StyleBoxFlat.new()
	sb.bg_color = fill_col
	sb.border_color = border_col
	sb.set_border_width_all(int(border_w))
	sb.set_corner_radius_all(radius)
	draw_style_box(sb, rect)

func _draw_bevel_tile(rect: Rect2, outer_col: Color, inner_col: Color, radius: int):
	_draw_rounded_box(rect, outer_col, COL_OUTLINE, 4.0, radius)
	_draw_rounded_box(rect.grow(-10), inner_col, Color(0, 0, 0, 0.25), 2.0, max(4, radius - 4))

func _draw_crate_sprite(rect: Rect2):
	_draw_bevel_tile(rect, PALETTE["wood_outer"], PALETTE["wood_inner"], 10)
	var inner = rect.grow(-12)
	draw_line(inner.position, inner.end, PALETTE["wood_outer"], 5.0)
	draw_line(Vector2(inner.end.x, inner.position.y), Vector2(inner.position.x, inner.end.y), PALETTE["wood_outer"], 5.0)

func _draw_player_sprite(rect: Rect2):
	_draw_rounded_box(rect, PALETTE["green_outer"], COL_OUTLINE, 4.5, 12)
	var hl = Rect2(rect.position.x + 8, rect.position.y + 6, rect.size.x - 16, 5)
	draw_rect(hl, Color(1, 1, 1, 0.28), true)
	var cx = rect.get_center().x
	var cy = rect.get_center().y - 2
	_draw_rounded_box(Rect2(cx - 13, cy - 8, 7, 16), COL_OUTLINE, COL_OUTLINE, 1.0, 4)
	_draw_rounded_box(Rect2(cx + 6, cy - 8, 7, 16), COL_OUTLINE, COL_OUTLINE, 1.0, 4)

func _draw_parabox_sprite(rect: Rect2, e: Entity):
	_draw_rounded_box(rect, PALETTE["blue_outer"], COL_OUTLINE, 4.5, 12)
	var inner_rect = rect.grow(-11)
	_draw_rounded_box(inner_rect, PALETTE["blue_inner"], COL_OUTLINE, 3.0, 6)
	
	if e.inner_room != null:
		for sub_e in e.inner_room.entities:
			var rel_x = float(sub_e.pos.x) / float(GRID_W)
			var rel_y = float(sub_e.pos.y) / float(GRID_H)
			var mini_pos = inner_rect.position + Vector2(rel_x * inner_rect.size.x, rel_y * inner_rect.size.y)
			var mini_col = PALETTE["green_outer"] if sub_e.type == "player" else PALETTE["wood_outer"]
			draw_rect(Rect2(mini_pos - Vector2(3, 3), Vector2(6, 6)), mini_col, true)
	
	if e.entry_dir == Vector2i.LEFT:
		var hole_h = rect.size.y * 0.44
		var hole = Rect2(rect.position.x - 2, rect.get_center().y - hole_h / 2.0, 14, hole_h)
		draw_rect(hole, COL_FLOOR, true)
		draw_line(hole.position, Vector2(hole.end.x, hole.position.y), COL_OUTLINE, 4.0)
		draw_line(Vector2(hole.position.x, hole.end.y), hole.end, COL_OUTLINE, 4.0)

func _draw_goal_brackets(rect: Rect2, col: Color):
	var L = 14.0
	var w = 5.0
	var p1 = rect.position
	var p2 = Vector2(rect.end.x, rect.position.y)
	var p3 = Vector2(rect.position.x, rect.end.y)
	var p4 = rect.end
	
	draw_line(p1, p1 + Vector2(L, 0), col, w)
	draw_line(p1, p1 + Vector2(0, L), col, w)
	draw_line(p2, p2 + Vector2(-L, 0), col, w)
	draw_line(p2, p2 + Vector2(0, L), col, w)
	draw_line(p3, p3 + Vector2(L, 0), col, w)
	draw_line(p3, p3 + Vector2(0, -L), col, w)
	draw_line(p4, p4 + Vector2(-L, 0), col, w)
	draw_line(p4, p4 + Vector2(0, -L), col, w)

func _draw_arrow_icon(center: Vector2, dir: Vector2, col: Color, size: float):
	var pts = PackedVector2Array()
	if dir == Vector2.RIGHT:
		pts = [center + Vector2(-size*0.5, -size*0.6), center + Vector2(size*0.6, 0), center + Vector2(-size*0.5, size*0.6)]
	elif dir == Vector2.LEFT:
		pts = [center + Vector2(size*0.5, -size*0.6), center + Vector2(-size*0.6, 0), center + Vector2(size*0.5, size*0.6)]
	elif dir == Vector2.UP:
		pts = [center + Vector2(-size*0.6, size*0.5), center + Vector2(0, -size*0.6), center + Vector2(size*0.6, size*0.5)]
	elif dir == Vector2.DOWN:
		pts = [center + Vector2(-size*0.6, -size*0.5), center + Vector2(0, size*0.6), center + Vector2(size*0.6, -size*0.5)]
	draw_colored_polygon(pts, col)

# ==========================================
# UI HUD & MODAL UCAPAN SELAMAT
# ==========================================
func _draw_parabox_ui():
	var vp = get_viewport_rect().size
	var font = ThemeDB.fallback_font
	
	# 1. Pill Header Kiri Atas
	var badge_rect = Rect2(24, 20, 320, 48)
	_draw_rounded_box(badge_rect, Color("#232736"), COL_OUTLINE, 4.0, 12)
	var indicator_col = PALETTE["blue_outer"] if current_room.theme == "blue" else PALETTE["green_outer"]
	_draw_rounded_box(Rect2(36, 32, 24, 24), indicator_col, COL_OUTLINE, 3.0, 6)
	draw_string(font, Vector2(72, 50), current_room.id, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	
	# 2. Pill Counter Langkah di Kanan Atas
	var step_rect = Rect2(vp.x - 184, 20, 160, 48)
	_draw_rounded_box(step_rect, Color("#232736"), COL_OUTLINE, 4.0, 12)
	draw_string(font, Vector2(step_rect.position.x + 22, 50), "LANGKAH: %d" % step_count, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, PALETTE["yellow_outer"])
	
	# 3. Petunjuk Instruksi Kontekstual di Bawah Layar
	var tip_text = "Dorong box BIRU ke tembok, masuk ke dalamnya, dan taruh peti kayu ke target kuning!"
	if current_room.theme == "blue":
		tip_text = "Dorong peti kayu keluar lewat pintu KIRI, lalu ikuti keluar menuju target kuning!"
	elif target_crate.room == rooms["Outer"]:
		tip_text = "Bagus! Sekarang dorong peti kayu tersebut ke petak target kuning!"
		
	var tip_w = 620.0
	var tip_rect = Rect2(vp.x / 2.0 - tip_w / 2.0 + 70.0, vp.y - 68, tip_w, 44)
	_draw_rounded_box(tip_rect, Color("#232736"), COL_OUTLINE, 4.0, 12)
	draw_string(font, Vector2(tip_rect.position.x + 18, tip_rect.position.y + 28), tip_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#f1f2f6"))
	
	# 4. Ikon Keycap Tombol Kontrol di Pojok Kiri Bawah
	var keys = [
		{"lbl": "WASD", "desc": "Gerak", "w": 56.0},
		{"lbl": "R", "desc": "Ulang", "w": 36.0},
		{"lbl": "ESC", "desc": "Menu", "w": 44.0}
	]
	var kx = 24.0
	for k in keys:
		var k_rect = Rect2(kx, vp.y - 64, k["w"], 38)
		_draw_rounded_box(k_rect, Color("#2e3346"), COL_OUTLINE, 3.5, 8)
		draw_string(font, Vector2(kx + 8, vp.y - 40), k["lbl"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
		draw_string(font, Vector2(kx + k["w"] + 6, vp.y - 40), k["desc"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#8395a7"))
		kx += k["w"] + 54.0
		
	# 5. Modal Ucapan Selamat saat Selesai
	if is_won:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.65), true)
		var card_w = 480.0
		var card_h = 250.0
		var card = Rect2(vp.x / 2.0 - card_w / 2.0, vp.y / 2.0 - card_h / 2.0, card_w, card_h)
		
		# Dekorasi konfeti kotak warna-warni di sekitar kartu
		var confetti_cols = [PALETTE["yellow_outer"], PALETTE["green_outer"], PALETTE["blue_outer"], PALETTE["red_outer"], PALETTE["purple_outer"]]
		var confetti_offsets = [
			Vector2(-25, -20), Vector2(card_w + 15, -15), Vector2(-30, card_h + 10),
			Vector2(card_w + 20, card_h + 15), Vector2(card_w * 0.25, -28), Vector2(card_w * 0.75, -24)
		]
		for i in range(confetti_offsets.size()):
			var c_pos = card.position + confetti_offsets[i]
			_draw_rounded_box(Rect2(c_pos, Vector2(14, 14)), confetti_cols[i % confetti_cols.size()], COL_OUTLINE, 2.5, 4)
		
		# Kartu utama
		_draw_rounded_box(card, Color("#232736"), COL_OUTLINE, 6.0, 18)
		_draw_rounded_box(card.grow(-8), Color("#232736"), PALETTE["yellow_outer"], 3.0, 12)
		
		draw_string(font, Vector2(card.position.x + 88, card.position.y + 62), "SELAMAT! KAMU BERHASIL!", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, PALETTE["yellow_outer"])
		draw_string(font, Vector2(card.position.x + 56, card.position.y + 98), "Kamu telah menyelesaikan tutorial dasar Parabox.", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
		draw_string(font, Vector2(card.position.x + 155, card.position.y + 132), "Total Langkah: %d" % step_count, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, PALETTE["green_outer"])
		
		# Tombol aksi
		var btn_r = Rect2(card.position.x + 55, card.position.y + 170, 170, 44)
		var btn_m = Rect2(card.position.x + 255, card.position.y + 170, 170, 44)
		_draw_rounded_box(btn_r, PALETTE["green_outer"], COL_OUTLINE, 4.0, 10)
		_draw_rounded_box(btn_m, PALETTE["blue_outer"], COL_OUTLINE, 4.0, 10)
		draw_string(font, Vector2(btn_r.position.x + 22, btn_r.position.y + 28), "[R] MAIN LAGI", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COL_OUTLINE)
		draw_string(font, Vector2(btn_m.position.x + 26, btn_m.position.y + 28), "[ESC] MENU", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COL_OUTLINE)
