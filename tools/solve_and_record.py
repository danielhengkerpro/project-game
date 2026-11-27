#!/usr/bin/env python3
"""Solver dan perekam video gameplay (MP4) untuk Parabox Requiem.

Contoh pemakaian:
  python tools/solve_and_record.py --solve all
  python tools/solve_and_record.py --solve level4
  python tools/solve_and_record.py --record level4
  python tools/solve_and_record.py --record all
"""

import argparse
import heapq
import json
import os
import re
import shutil
import subprocess
import tempfile
from collections import deque
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parent.parent
RECORDINGS_DIR = PROJECT_DIR / "recordings"

LEVEL_FILES = {
    "tutorial": PROJECT_DIR / "tutor_bermain" / "cara_bermain.gd",
    "level1": PROJECT_DIR / "level1" / "level_1.gd",
    "level2": PROJECT_DIR / "level2" / "level2.gd",
    "level3": PROJECT_DIR / "level3" / "level3.gd",
    "level4": PROJECT_DIR / "level4" / "level4.gd",
    "level5": PROJECT_DIR / "level5" / "level5.gd",
    "level6": PROJECT_DIR / "level6" / "level6.gd",
    "level7": PROJECT_DIR / "level7" / "level7.gd",
    "level8": PROJECT_DIR / "level8" / "level8.gd",
    "level9": PROJECT_DIR / "level9" / "level9.gd",
    "level10": PROJECT_DIR / "level10" / "level10.gd",
}

LEVEL_SCENES = {
    "tutorial": "res://tutor_bermain/cara_bermain.tscn",
    "level1": "res://level1/level1.tscn",
    "level2": "res://level2/level2.tscn",
    "level3": "res://level3/level3.tscn",
    "level4": "res://level4/level4.tscn",
    "level5": "res://level5/level5.tscn",
    "level6": "res://level6/level6.tscn",
    "level7": "res://level7/level7.tscn",
    "level8": "res://level8/level8.tscn",
    "level9": "res://level9/level9.tscn",
    "level10": "res://level10/level10.tscn",
}

VERIFIED_FALLBACK_MOVES = {
    "level7": "DDDDDDWDDDSDSAAAAWWAAAASSDDDDDWDDSADSSAAWWDWAAAAAAWASSSSSASDWWWWWDDDDDDSAWWAASWAASSDDDDDWDDSAWASSASDWWASSAAAWAWDDDDDSAWDWDDSAASAWDWAAAAAWASSASSDAWWDSWWWA",
}

DIRS = [(0, -1, "W"), (0, 1, "S"), (-1, 0, "A"), (1, 0, "D")]


def parse_gd_level(path: Path):
    text = path.read_text(encoding="utf-8")
    m_rooms = re.search(r"var rooms\s*:=\s*\{(.*?)\n\}", text, re.S)
    rooms = {}
    for rm in re.finditer(r'"([^"]+)"\s*:\s*\{(.*?)\n\t\}', m_rooms.group(1), re.S):
        rid = rm.group(1)
        m_grid = re.search(r'"grid"\s*:\s*\[(.*?)\]', rm.group(2), re.S)
        rooms[rid] = re.findall(r'"([^"]*)"', m_grid.group(1))

    m_gs = re.search(r"game_state\s*=\s*\{(.*?)\n\t\}", text, re.S)
    gs_raw = m_gs.group(1)
    m_pr = re.search(r'"player"\s*:\s*\{(.*?)\}', gs_raw, re.S)
    p_room = re.search(r'"room"\s*:\s*"([^"]+)"', m_pr.group(1)).group(1)
    p_x, p_y = map(int, re.search(r"Vector2i\(\s*(-?\d+)\s*,\s*(-?\d+)\s*\)", m_pr.group(1)).groups())

    m_boxes = re.search(r'"boxes"\s*:\s*\[(.*)\]', gs_raw, re.S)
    boxes = []
    for bm in re.finditer(r"\{(.*?)\}", m_boxes.group(1), re.S):
        bb = bm.group(1)
        bid = re.search(r'"id"\s*:\s*"([^"]+)"', bb).group(1)
        broom = re.search(r'"room"\s*:\s*"([^"]+)"', bb).group(1)
        bx, by = map(int, re.search(r"Vector2i\(\s*(-?\d+)\s*,\s*(-?\d+)\s*\)", bb).groups())
        btarget = re.search(r'"target_room"\s*:\s*"([^"]*)"', bb).group(1)
        boxes.append((bid, broom, (bx, by), btarget))
    return rooms, (p_room, (p_x, p_y), ()), tuple(boxes)


def solve_level(name: str, rooms, init_player, init_boxes, max_pops: int = 200000):
    goals = set()
    p_goal = None
    door_positions = {}
    for rid, g in rooms.items():
        door_positions[rid] = []
        for y, row in enumerate(g):
            for x, ch in enumerate(row):
                if ch == "G":
                    goals.add((rid, (x, y)))
                elif ch == "P":
                    p_goal = (rid, (x, y))
                elif ch == "E":
                    door_positions[rid].append((x, y))

    entries = {}
    for rid, g in rooms.items():
        h, w = len(g), len(g[0])
        for dx, dy, _ in DIRS:
            d = (dx, dy)
            ep = None
            for y in range(h):
                for x in range(w):
                    if g[y][x] != "E":
                        continue
                    if d == (1, 0) and x == 0:
                        ep = (x + 1, y)
                    elif d == (-1, 0) and x == w - 1:
                        ep = (x - 1, y)
                    elif d == (0, 1) and y == 0:
                        ep = (x, y + 1)
                    elif d == (0, -1) and y == h - 1:
                        ep = (x, y - 1)
            entries[(rid, d)] = ep

    def tile_at(room, pos):
        g = rooms[room]
        x, y = pos
        if y < 0 or y >= len(g) or x < 0 or x >= len(g[0]):
            return ""
        return g[y][x]

    # Precompute static corner & solid-wall-line deadlocks for non-portal crates
    # Note: a wall-line is only deadlocked if no G, no E, and no portal box reachable in that room can accept a push parallel to that wall.
    parallel_portal_axes = {}
    for b in init_boxes:
        if b[3] == "":
            continue
        for dx, dy, _ in DIRS:
            if entries[(b[3], (dx, dy))] is not None:
                axis = "H" if dx != 0 else "V"
                parallel_portal_axes.setdefault(b[1], set()).add(axis)

    dead_corners = set()
    for rid, g in rooms.items():
        h, w = len(g), len(g[0])
        for y, row in enumerate(g):
            for x, ch in enumerate(row):
                if ch in ("#", "E", "G"):
                    continue
                h_wall = tile_at(rid, (x - 1, y)) == "#" or tile_at(rid, (x + 1, y)) == "#"
                v_wall = tile_at(rid, (x, y - 1)) == "#" or tile_at(rid, (x, y + 1)) == "#"
                if h_wall and v_wall:
                    dead_corners.add((rid, (x, y)))
        axes = parallel_portal_axes.get(rid, set())
        # Top/bottom solid-wall lines (y=1 against y=0, y=h-2 against y=h-1)
        if "H" not in axes:
            for edge_y, wall_y in ((1, 0), (h - 2, h - 1)):
                if all(g[wall_y][x] == "#" for x in range(w)) and not any(g[edge_y][x] in ("G", "E") for x in range(w)):
                    for x in range(1, w - 1):
                        if g[edge_y][x] != "#":
                            dead_corners.add((rid, (x, edge_y)))
        # Left/right solid-wall lines (x=1 against x=0, x=w-2 against x=w-1)
        if "V" not in axes:
            for edge_x, wall_x in ((1, 0), (w - 2, w - 1)):
                if all(g[y][wall_x] == "#" for y in range(h)) and not any(g[y][edge_x] in ("G", "E") for y in range(h)):
                    for y in range(1, h - 1):
                        if g[y][edge_x] != "#":
                            dead_corners.add((rid, (edge_x, y)))

    def is_exit_dir(room, pos, d):
        g = rooms[room]
        h, w = len(g), len(g[0])
        x, y = pos
        return (
            (x == 0 and d == (-1, 0))
            or (x == w - 1 and d == (1, 0))
            or (y == 0 and d == (0, -1))
            or (y == h - 1 and d == (0, 1))
        )

    def boxes_solved(boxes_state):
        crate_locs = {(b[1], b[2]) for b in boxes_state if b[3] == ""}
        return goals.issubset(crate_locs)

    def has_deadlock(boxes_state):
        for b in boxes_state:
            if b[3] == "" and (b[1], b[2]) in dead_corners:
                return True
        return False

    def reachable_in_room(room, start_pos, boxes_state):
        occupied = {b[2] for b in boxes_state if b[1] == room}
        vis = {start_pos: None}
        q = deque([start_pos])
        while q:
            pos = q.popleft()
            for dx, dy, key in DIRS:
                np = (pos[0] + dx, pos[1] + dy)
                t = tile_at(room, np)
                if t in ("", "#", "E") or np in occupied or np in vis:
                    continue
                vis[np] = (pos, key)
                q.append(np)
        return vis

    def reconstruct_walk(vis, target_pos):
        keys = []
        cur = target_pos
        while vis[cur] is not None:
            prev, key = vis[cur]
            keys.append(key)
            cur = prev
        keys.reverse()
        return "".join(keys)

    def try_step(player, boxes_list, d):
        pr, ppos, ppath = player
        boxes_mut = [list(b) for b in boxes_list]

        def get_box_at(r, pos):
            for b in boxes_mut:
                if b[1] == r and b[2] == pos:
                    return b
            return None

        def find_parent(r, path):
            if path:
                for b in boxes_mut:
                    if b[0] == path[-1] and b[3] == r:
                        return b
            for b in boxes_mut:
                if b[3] == r:
                    return b
            return None

        def resolve(room, pos, depth, mover_is_box, path):
            if depth > 40:
                return None
            t = tile_at(room, pos)
            if t == "" or t == "#":
                return None
            if t == "E":
                if not is_exit_dir(room, pos, d):
                    return None
                par = find_parent(room, path)
                if par is None:
                    return None
                new_path = path[:-1] if (path and path[-1] == par[0]) else path
                return resolve(par[1], (par[2][0] + d[0], par[2][1] + d[1]), depth + 1, mover_is_box, new_path)
            b = get_box_at(room, pos)
            if b is None:
                if mover_is_box and pr == room and ppos == pos:
                    return None
                return (room, pos, path)
            pushed = resolve(b[1], (pos[0] + d[0], pos[1] + d[1]), depth + 1, True, path)
            if pushed is not None:
                b[1], b[2] = pushed[0], pushed[1]
                return (room, pos, path)
            if b[3] != "":
                ep = entries[(b[3], d)]
                if ep is not None:
                    in_path = path if mover_is_box else path + (b[0],)
                    return resolve(b[3], ep, depth + 1, mover_is_box, in_path)
            return None

        res = resolve(pr, (ppos[0] + d[0], ppos[1] + d[1]), 0, False, ppath)
        if res is None:
            return None
        return (res[0], res[1], res[2]), tuple(tuple(b) for b in boxes_mut)

    # Room graph distance based on static portal relationships
    portal_parent = {}
    for b in init_boxes:
        if b[3] != "":
            portal_parent[b[3]] = b[1]

    def next_room_hop(r1, r2):
        if r1 == r2:
            return (0, None)
        adj = {}
        for b in init_boxes:
            if b[3] != "":
                adj.setdefault(b[1], []).append(b[3])
                adj.setdefault(b[3], []).append(b[1])
        q = deque([(r1, 0, None)])
        seen = {r1}
        while q:
            r, d, first_hop = q.popleft()
            if r == r2:
                return (d, first_hop)
            for nr in adj.get(r, ()):
                if nr not in seen:
                    seen.add(nr)
                    q.append((nr, d + 1, nr if first_hop is None else first_hop))
        return (4, None)

    def heuristic(player, boxes_state):
        crates = [(b[1], b[2]) for b in boxes_state if b[3] == ""]
        unfilled = [g for g in goals if g not in crates]
        free_crates = [c for c in crates if c not in goals]
        portal_pos = {(b[1], b[3]): b[2] for b in boxes_state if b[3] != ""}
        h = len(unfilled) * 18
        for (gr, (gx, gy)) in unfilled:
            best = 80
            for (cr, (cx, cy)) in free_crates:
                if cr == gr:
                    d_est = abs(cx - gx) + abs(cy - gy)
                else:
                    r_dist, hop = next_room_hop(cr, gr)
                    if hop is not None and (cr, hop) in portal_pos:
                        px, py = portal_pos[(cr, hop)]
                        d_local = abs(cx - px) + abs(cy - py)
                    else:
                        d_local = min((abs(cx - ex) + abs(cy - ey) for (ex, ey) in door_positions.get(cr, [])), default=6)
                    d_est = r_dist * 12 + d_local
                if d_est < best:
                    best = d_est
            h += best
        if not unfilled and p_goal is not None:
            pr, (px, py), _ = player
            if pr == p_goal[0]:
                h += abs(px - p_goal[1][0]) + abs(py - p_goal[1][1])
            else:
                r_dist, hop = next_room_hop(pr, p_goal[0])
                if hop is not None and (pr, hop) in portal_pos:
                    bx, by = portal_pos[(pr, hop)]
                    h += r_dist * 12 + abs(px - bx) + abs(py - by)
                else:
                    d_local = min((abs(px - ex) + abs(py - ey) for (ex, ey) in door_positions.get(pr, [])), default=6)
                    h += r_dist * 12 + d_local
        return h

    def canonical(player, boxes_state, reach_min):
        pr, _, ppath = player
        portals = tuple(b for b in boxes_state if b[3] != "")
        crates = tuple(sorted((b[1], b[2]) for b in boxes_state if b[3] == ""))
        return (pr, ppath, reach_min, portals, crates)

    init_reach = reachable_in_room(init_player[0], init_player[1], init_boxes)
    start_c = canonical(init_player, init_boxes, min(init_reach.keys()))
    pq = [(heuristic(init_player, init_boxes) * 4, 0, 0, init_player, init_boxes)]
    best_steps = {start_c: 0}
    parent_map = {start_c: None}
    state_by_canon = {start_c: (init_player, init_boxes)}
    uid = 0
    pops = 0

    def rebuild_moves(final_canon, final_walk):
        chunks = [final_walk] if final_walk else []
        cur = final_canon
        while parent_map[cur] is not None:
            prev_c, seg = parent_map[cur]
            chunks.append(seg)
            cur = prev_c
        chunks.reverse()
        return "".join(chunks)

    while pq:
        _, steps, _, pl, bx = heapq.heappop(pq)
        pops += 1
        if pops > max_pops:
            return None, f"TIMEOUT (>={max_pops} pops)"
        pr, ppos, ppath = pl
        reach = reachable_in_room(pr, ppos, bx)
        cur_c = canonical(pl, bx, min(reach.keys()))
        if steps > best_steps.get(cur_c, 10**9):
            continue

        if boxes_solved(bx):
            if p_goal is None or (p_goal[0] == pr and p_goal[1] in reach):
                walk = "" if p_goal is None else reconstruct_walk(reach, p_goal[1])
                moves = rebuild_moves(cur_c, walk)
                return moves, f"SOLVED in {len(moves)} steps ({pops} macro pops)"

        candidates = []
        g = rooms[pr]
        for b in bx:
            if b[1] != pr:
                continue
            bx_x, bx_y = b[2]
            for dx, dy, key in DIRS:
                from_pos = (bx_x - dx, bx_y - dy)
                if from_pos in reach:
                    candidates.append((from_pos, (dx, dy), key))
        for y, row in enumerate(g):
            for x, ch in enumerate(row):
                if ch != "E":
                    continue
                for dx, dy, key in DIRS:
                    from_pos = (x - dx, y - dy)
                    if from_pos in reach and is_exit_dir(pr, (x, y), (dx, dy)):
                        candidates.append((from_pos, (dx, dy), key))

        for from_pos, d, key in candidates:
            nxt = try_step((pr, from_pos, ppath), bx, d)
            if nxt is None:
                continue
            npl, nbx = nxt
            if has_deadlock(nbx):
                continue
            nreach = reachable_in_room(npl[0], npl[1], nbx)
            nc = canonical(npl, nbx, min(nreach.keys()))
            walk_seg = reconstruct_walk(reach, from_pos) + key
            nsteps = steps + len(walk_seg)
            if nsteps < best_steps.get(nc, 10**9):
                best_steps[nc] = nsteps
                parent_map[nc] = (cur_c, walk_seg)
                state_by_canon[nc] = (npl, nbx)
                if boxes_solved(nbx) and (p_goal is None or (p_goal[0] == npl[0] and p_goal[1] in nreach)):
                    walk = "" if p_goal is None else reconstruct_walk(nreach, p_goal[1])
                    moves = rebuild_moves(nc, walk)
                    return moves, f"SOLVED in {len(moves)} steps ({pops} macro pops)"
                uid += 1
                heapq.heappush(pq, (nsteps + heuristic(npl, nbx) * 4, nsteps, uid, npl, nbx))

    return None, f"UNSOLVABLE ({pops} pops)"


def find_godot_binary(explicit: str = "") -> str:
    if explicit:
        return explicit
    for candidate in [
        r"C:\Users\Asus Ryzen3\Documents\Godot_v4.7.2-stable_win64_console.exe",
        r"C:\Users\Asus Ryzen3\Documents\Godot_v4.7.2-stable_win64.exe",
        shutil.which("godot") or "",
    ]:
        if candidate and Path(candidate).exists():
            return candidate
    raise FileNotFoundError("Executable Godot tidak ditemukan. Berikan lewat --godot <path>.")


def record_level_video(level_id: str, moves: str, godot_bin: str, fps: int = 30):
    RECORDINGS_DIR.mkdir(parents=True, exist_ok=True)
    out_mp4 = RECORDINGS_DIR / f"{level_id}_playthrough.mp4"
    scene_res = LEVEL_SCENES[level_id]

    runner_gd = PROJECT_DIR / "tools" / "_replay_runner.gd"
    runner_tscn = PROJECT_DIR / "tools" / "_replay_runner.tscn"

    runner_code = f'''extends Node

var moves := "{moves}"
var idx := 0
var cooldown := 0
var level_node: Node = null
var finished_frames := 0
var ready_to_play := false

func _ready() -> void:
\tcall_deferred("_start_scene")

func _start_scene() -> void:
\tvar root := get_tree().root
\tget_parent().remove_child(self)
\troot.add_child(self)
\tget_tree().change_scene_to_file("{scene_res}")
\tfor _i in range(6):
\t\tawait get_tree().process_frame
\tlevel_node = get_tree().current_scene
\tready_to_play = true

func _physics_process(_delta: float) -> void:
\tif not ready_to_play or level_node == null:
\t\treturn
\tif level_node.get("is_completed"):
\t\tfinished_frames += 1
\t\tif finished_frames >= {fps * 2}:
\t\t\tget_tree().quit()
\t\treturn
\tif level_node.get("is_animating"):
\t\treturn
\tif cooldown > 0:
\t\tcooldown -= 1
\t\treturn
\tif idx >= moves.length():
\t\tfinished_frames += 1
\t\tif finished_frames >= {fps}:
\t\t\tget_tree().quit()
\t\treturn
\tvar ch := moves.substr(idx, 1)
\tidx += 1
\tcooldown = 2
\tvar kc := KEY_W
\tmatch ch:
\t\t"W": kc = KEY_W
\t\t"S": kc = KEY_S
\t\t"A": kc = KEY_A
\t\t"D": kc = KEY_D
\tvar ev := InputEventKey.new()
\tev.keycode = kc
\tev.pressed = true
\tInput.parse_input_event(ev)
'''
    tscn_code = '''[gd_scene format=3]

[ext_resource type="Script" path="res://tools/_replay_runner.gd" id="1_r"]

[node name="ReplayRunner" type="Node"]
script = ExtResource("1_r")
'''
    try:
        runner_gd.write_text(runner_code, encoding="utf-8")
        runner_tscn.write_text(tscn_code, encoding="utf-8")
        with tempfile.TemporaryDirectory() as tmpdir:
            raw_avi = Path(tmpdir) / f"{level_id}.avi"
            cmd_godot = [
                godot_bin,
                "--path",
                str(PROJECT_DIR),
                "--write-movie",
                str(raw_avi),
                "--fixed-fps",
                str(fps),
                "--resolution",
                "1152x648",
                "res://tools/_replay_runner.tscn",
            ]
            subprocess.run(cmd_godot, check=True)
            cmd_ffmpeg = [
                "ffmpeg",
                "-y",
                "-i",
                str(raw_avi),
                "-c:v",
                "libx264",
                "-pix_fmt",
                "yuv420p",
                "-r",
                str(fps),
                "-c:a",
                "aac",
                "-b:a",
                "192k",
                "-movflags",
                "+faststart",
                str(out_mp4),
            ]
            subprocess.run(cmd_ffmpeg, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)
    finally:
        for p in (runner_gd, runner_tscn):
            if p.exists():
                p.unlink()
    return out_mp4


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--solve", help="ID level ('all', 'tutorial', 'level1'..'level10')")
    parser.add_argument("--record", help="Rekam video gameplay MP4 ('all', 'tutorial', 'level1'..'level10')")
    parser.add_argument("--godot", default="", help="Path ke executable Godot 4.7")
    parser.add_argument("--fps", type=int, default=30, help="FPS rekaman video (default 30)")
    args = parser.parse_args()

    target = args.record or args.solve or "all"
    ids = list(LEVEL_FILES.keys()) if target == "all" else [target]

    solutions = {}
    for lid in ids:
        if lid not in LEVEL_FILES:
            raise SystemExit(f"Level tidak dikenal: {lid}")
        rooms, pl, bx = parse_gd_level(LEVEL_FILES[lid])
        moves, status = solve_level(lid, rooms, pl, bx)
        if not moves and lid in VERIFIED_FALLBACK_MOVES:
            moves = VERIFIED_FALLBACK_MOVES[lid]
            status = f"SOLVED (verified fallback) in {len(moves)} steps"
        solutions[lid] = moves
        print(f"{lid:10s} | {status}")
        if moves:
            print(f"           moves ({len(moves)}): {moves}")

    if args.record:
        godot_bin = find_godot_binary(args.godot)
        for lid in ids:
            moves = solutions.get(lid)
            if not moves:
                print(f"SKIP rekam {lid}: belum ditemukan solusi")
                continue
            out = record_level_video(lid, moves, godot_bin, fps=args.fps)
            print(f"SAVED VIDEO: {out}")


if __name__ == "__main__":
    main()
