extends Node2D

enum Screen { TITLE, MODE, SONG, PLAY, RESULT }

@onready var music: AudioStreamPlayer = $Music

# 화면 및 상태
var screen: Screen = Screen.TITLE
var selected_mode: Global.PlayMode = Global.PlayMode.PRO_4KEY_LEVER
var selected_diff: Global.Difficulty = Global.Difficulty.NORMAL
var current_song_idx: int = 0
var mode_cursor: int = 1

# 인게임 차트 & 노트
var chart_data: Array = []
var active_notes: Array = []
var next_note_idx: int = 0
var song_time: float = 0.0
var total_chart_notes: int = 0

# 점수 및 통계
var score: int = 0
var combo: int = 0
var max_combo: int = 0
var judge_counts: Dictionary = {"PERFECT": 0, "GREAT": 0, "GOOD": 0, "MISS": 0}
var total_hits: int = 0
var accuracy: float = 100.0

# 판정 연출
var judge_text: String = ""
var judge_color: Color = Color.WHITE
var judge_anim_timer: float = 0.0
var combo_bounce: float = 0.0

# 4키 입력 및 키 빔 상태
var key_pressed_states: Array[bool] = [false, false, false, false]
var key_beam_timers: Array[float] = [0.0, 0.0, 0.0, 0.0]

# 바닥 롱노트 홀드 상태
var holding_notes: Array = [null, null, null, null]
var hold_tick_timers: Array[float] = [0.0, 0.0, 0.0, 0.0]

# 레버 커브 롱노트 홀드 상태
var active_curve_holds: Array[Dictionary] = []
var curve_tick_timer: float = 0.0

# 레버 제어 (-1.0: LEFT, 0.0: CENTER, 1.0: RIGHT)
var lever_target: float = 0.0
var lever_current: float = 0.0
var lever_key_left: bool = false
var lever_key_right: bool = false

# 비주얼 파티클 & 스파크
var hit_sparks: Array[Dictionary] = []
var anim_time: float = 0.0
var bg_particles: Array[Dictionary] = []

func _ready() -> void:
	get_viewport().size_changed.connect(queue_redraw)
	for i in range(40):
		bg_particles.append({
			"pos": Vector2(randf() * 1280.0, randf() * 720.0),
			"size": randf_range(6.0, 24.0),
			"alpha": randf_range(0.15, 0.45),
			"color": Color("00e5ff") if randf() < 0.5 else Color("d500f9"),
			"speed": randf_range(20.0, 50.0)
		})

func _process(delta: float) -> void:
	anim_time += delta
	
	if lever_key_left and not lever_key_right:
		lever_target = maxf(-1.0, lever_target - delta * 4.5)
	elif lever_key_right and not lever_key_left:
		lever_target = minf(1.0, lever_target + delta * 4.5)
		
	lever_current = lerpf(lever_current, lever_target, delta * 24.0)
	
	for i in range(4):
		if not key_pressed_states[i]:
			key_beam_timers[i] = maxf(0.0, key_beam_timers[i] - delta * 6.0)
		else:
			key_beam_timers[i] = 1.0
			
	if judge_anim_timer > 0.0:
		judge_anim_timer = maxf(0.0, judge_anim_timer - delta * 2.8)
	if combo_bounce > 0.0:
		combo_bounce = maxf(0.0, combo_bounce - delta * 4.5)
		
	var alive_sparks: Array[Dictionary] = []
	for spark in hit_sparks:
		spark["life"] = float(spark["life"]) - delta * 4.0
		spark["pos"] = (spark["pos"] as Vector2) + (spark["vel"] as Vector2) * delta
		if float(spark["life"]) > 0.0:
			alive_sparks.append(spark)
	hit_sparks = alive_sparks
	
	if screen == Screen.PLAY:
		if music.playing:
			song_time = music.get_playback_position()
		else:
			song_time += delta
			
		_update_game_notes(delta)
		_update_holding_notes(delta)
		_update_curve_holds(delta)
		
		if next_note_idx >= chart_data.size() and active_notes.is_empty() and not _has_active_hold():
			_finish_game()
			
	queue_redraw()

func _has_active_hold() -> bool:
	for h in holding_notes:
		if h != null:
			return true
	return not active_curve_holds.is_empty()

# ==========================================
# 3D 원근 투시 변환 (Perspective Projection)
# ==========================================
# 1. 하단 4키 바닥 트랙 투영 (판정선: TRACK_BOTTOM_Y = 630.0)
func project_floor_point(x_ratio: float, time_diff: float) -> Vector2:
	var v: Vector2 = get_viewport_rect().size
	var progress: float = clampf(1.0 - (time_diff / Global.APPROACH_TIME), 0.0, 1.0)
	var z: float = pow(progress, 1.85)
	
	var y: float = lerpf(Global.TRACK_TOP_Y, Global.TRACK_BOTTOM_Y, z)
	var w: float = lerpf(Global.TRACK_TOP_WIDTH, Global.TRACK_BOTTOM_WIDTH, z)
	var center_x: float = v.x * 0.5
	var x: float = center_x + x_ratio * (w * 0.5)
	
	return Vector2(x, y)

# 2. 상단 레버/공중 트랙 투영 (판정선: LEVER_JUDGEMENT_Y = 475.0)
func project_lever_point(x_ratio: float, time_diff: float) -> Vector2:
	var v: Vector2 = get_viewport_rect().size
	var progress: float = clampf(1.0 - (time_diff / Global.APPROACH_TIME), 0.0, 1.0)
	var z: float = pow(progress, 1.7)
	
	var y: float = lerpf(Global.TRACK_TOP_Y, Global.LEVER_JUDGEMENT_Y, z)
	var w: float = lerpf(Global.TRACK_TOP_WIDTH, Global.TRACK_BOTTOM_WIDTH * 0.74, z)
	var center_x: float = v.x * 0.5
	var x: float = center_x + x_ratio * (w * 0.5)
	
	return Vector2(x, y)

# ==========================================
# 입력 처리
# ==========================================
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and screen == Screen.PLAY:
		var mouse_event: InputEventMouseMotion = event as InputEventMouseMotion
		var v: Vector2 = get_viewport_rect().size
		var lever_track_half_w: float = Global.TRACK_BOTTOM_WIDTH * 0.37
		var rel_x: float = mouse_event.position.x - (v.x * 0.5)
		lever_target = clampf(rel_x / lever_track_half_w, -1.0, 1.0)
		
		if absf(mouse_event.velocity.x) > 1300.0:
			_try_lever_flick(-1 if mouse_event.velocity.x < 0.0 else 1)
		return
		
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	var keycode: Key = key_event.keycode
	
	if not key_event.pressed:
		_handle_key_release(keycode)
		return
	if key_event.echo:
		return
		
	match screen:
		Screen.TITLE:
			SFXManager.play_ui_select()
			screen = Screen.MODE
			return
			
		Screen.MODE:
			if keycode in [KEY_UP, KEY_W]:
				mode_cursor = (mode_cursor - 1 + 2) % 2
				SFXManager.play_ui_move()
			elif keycode in [KEY_DOWN, KEY_S]:
				mode_cursor = (mode_cursor + 1) % 2
				SFXManager.play_ui_move()
			elif keycode in [KEY_ENTER, KEY_SPACE]:
				selected_mode = Global.PlayMode.CASUAL_LEVER_2KEY if mode_cursor == 0 else Global.PlayMode.PRO_4KEY_LEVER
				SFXManager.play_ui_select()
				screen = Screen.SONG
			elif keycode == KEY_ESCAPE:
				SFXManager.play_ui_move()
				screen = Screen.TITLE
			return
			
		Screen.SONG:
			if keycode in [KEY_TAB, KEY_RIGHT, KEY_D]:
				selected_diff = ((selected_diff + 1) % 3) as Global.Difficulty
				SFXManager.play_ui_move()
			elif keycode in [KEY_LEFT, KEY_A]:
				selected_diff = ((selected_diff - 1 + 3) % 3) as Global.Difficulty
				SFXManager.play_ui_move()
			elif keycode == KEY_1:
				selected_diff = Global.Difficulty.EASY
				SFXManager.play_ui_move()
			elif keycode == KEY_2:
				selected_diff = Global.Difficulty.NORMAL
				SFXManager.play_ui_move()
			elif keycode == KEY_3:
				selected_diff = Global.Difficulty.HARD
				SFXManager.play_ui_move()
			elif keycode in [KEY_ENTER, KEY_SPACE]:
				SFXManager.play_ui_select()
				_start_game()
			elif keycode == KEY_ESCAPE:
				SFXManager.play_ui_move()
				screen = Screen.MODE
			return
			
		Screen.PLAY:
			if keycode == KEY_ESCAPE:
				music.stop()
				SFXManager.play_ui_move()
				screen = Screen.SONG
				return
			_handle_game_press(keycode)
			
		Screen.RESULT:
			if keycode in [KEY_ENTER, KEY_SPACE]:
				SFXManager.play_ui_select()
				screen = Screen.SONG
			elif keycode == KEY_ESCAPE:
				SFXManager.play_ui_move()
				screen = Screen.MODE
			return

func _handle_game_press(key: Key) -> void:
	if key in [KEY_A, KEY_LEFT]:
		lever_key_left = true
		lever_target = -1.0
		if selected_mode == Global.PlayMode.PRO_4KEY_LEVER:
			_try_lever_flick(-1)
	elif key in [KEY_L, KEY_RIGHT]:
		lever_key_right = true
		lever_target = 1.0
		if selected_mode == Global.PlayMode.PRO_4KEY_LEVER:
			_try_lever_flick(1)
			
	if selected_mode == Global.PlayMode.CASUAL_LEVER_2KEY:
		if key in [KEY_D, KEY_F]:
			key_pressed_states[0] = true
			key_pressed_states[1] = true
			key_beam_timers[0] = 1.0
			key_beam_timers[1] = 1.0
			_try_hit_lanes([0, 1])
		elif key in [KEY_J, KEY_K]:
			key_pressed_states[2] = true
			key_pressed_states[3] = true
			key_beam_timers[2] = 1.0
			key_beam_timers[3] = 1.0
			_try_hit_lanes([2, 3])
	else:
		var key_map: Dictionary = {KEY_D: 0, KEY_F: 1, KEY_J: 2, KEY_K: 3}
		if key_map.has(key):
			var lane: int = key_map[key]
			key_pressed_states[lane] = true
			key_beam_timers[lane] = 1.0
			_try_hit_lanes([lane])

func _handle_key_release(key: Key) -> void:
	if key in [KEY_A, KEY_LEFT]:
		lever_key_left = false
	elif key in [KEY_L, KEY_RIGHT]:
		lever_key_right = false
		
	if screen != Screen.PLAY:
		return
		
	var released_lanes: Array[int] = []
	if key == KEY_D:
		key_pressed_states[0] = false
		released_lanes.append(0)
	elif key == KEY_F:
		key_pressed_states[1] = false
		released_lanes.append(1)
	elif key == KEY_J:
		key_pressed_states[2] = false
		released_lanes.append(2)
	elif key == KEY_K:
		key_pressed_states[3] = false
		released_lanes.append(3)
		
	for lane in released_lanes:
		if holding_notes[lane] != null:
			var note: Dictionary = holding_notes[lane]
			var note_time: float = float(note.get("time", 0.0))
			var duration: float = float(note.get("duration", 0.6))
			var end_time: float = note_time + duration
			if song_time >= end_time - Global.GOOD_WINDOW:
				_trigger_judgement("EXACT", 1000, lane, false)
				SFXManager.play_tap(1.2)
			else:
				_trigger_judgement("MISS", 0, lane, false)
				SFXManager.play_miss()
			holding_notes[lane] = null

# ==========================================
# 인게임 판정 로직
# ==========================================
func _start_game() -> void:
	var chart_obj: Dictionary = Charts.get_chart(current_song_idx, selected_diff)
	chart_data = chart_obj.get("notes", []).duplicate(true)
	
	active_notes.clear()
	active_curve_holds.clear()
	next_note_idx = 0
	song_time = 0.0
	score = 0
	combo = 0
	max_combo = 0
	total_hits = 0
	accuracy = 100.0
	judge_counts = {"PERFECT": 0, "GREAT": 0, "GOOD": 0, "MISS": 0}
	judge_text = "READY"
	judge_color = Global.JUDGE_COLORS["READY"]
	judge_anim_timer = 1.0
	combo_bounce = 0.0
	lever_target = 0.0
	lever_current = 0.0
	lever_key_left = false
	lever_key_right = false
	
	for i in range(4):
		key_pressed_states[i] = false
		key_beam_timers[i] = 0.0
		holding_notes[i] = null
		hold_tick_timers[i] = 0.0
		
	hit_sparks.clear()
	total_chart_notes = chart_data.size()
	screen = Screen.PLAY
	music.play()

func _update_game_notes(delta: float) -> void:
	while next_note_idx < chart_data.size():
		var n: Dictionary = chart_data[next_note_idx]
		var note_time: float = float(n.get("time", 0.0))
		if song_time >= note_time - Global.APPROACH_TIME:
			if n.get("type", Global.NoteType.TAP) == Global.NoteType.LEVER_CURVE_HOLD:
				active_curve_holds.append(n)
			else:
				active_notes.append(n)
			next_note_idx += 1
		else:
			break
		
	var notes_to_check: Array = active_notes.duplicate()
	for note_var in notes_to_check:
		var note: Dictionary = note_var
		var note_time: float = float(note.get("time", 0.0))
		var is_lever: bool = (int(note.get("type", Global.NoteType.TAP)) in [Global.NoteType.LEVER_FLICK_LEFT, Global.NoteType.LEVER_FLICK_RIGHT])
		if song_time - note_time > Global.GOOD_WINDOW:
			active_notes.erase(note)
			_trigger_judgement("MISS", 0, int(note.get("lane", 0)), is_lever)
			SFXManager.play_miss()

func _update_holding_notes(delta: float) -> void:
	for lane in range(4):
		var note_var = holding_notes[lane]
		if note_var != null:
			var note: Dictionary = note_var
			var note_time: float = float(note.get("time", 0.0))
			var duration: float = float(note.get("duration", 0.6))
			var end_time: float = note_time + duration
			hold_tick_timers[lane] += delta
			if hold_tick_timers[lane] >= 0.1:
				hold_tick_timers[lane] = 0.0
				combo += 1
				max_combo = maxi(max_combo, combo)
				score += 60 + combo * 2
				SFXManager.play_tick()
				_spawn_hit_sparks(lane, 3)
			if song_time >= end_time:
				_trigger_judgement("EXACT", 1000, lane, false)
				SFXManager.play_tap(1.2)
				holding_notes[lane] = null

func _update_curve_holds(delta: float) -> void:
	curve_tick_timer += delta
	var holds_to_check: Array = active_curve_holds.duplicate()
	
	for hold_var in holds_to_check:
		var hold: Dictionary = hold_var
		var start_time: float = float(hold.get("time", 0.0))
		var duration: float = float(hold.get("duration", 1.0))
		var end_time: float = start_time + duration
		
		# 상단 판정선 기준 실시간 레버 위치 추적
		if song_time >= start_time and song_time <= end_time:
			var progress: float = (song_time - start_time) / duration
			var target_x: float = lerpf(float(hold.get("start_x", 0.0)), float(hold.get("end_x", 0.0)), progress)
			
			if absf(lever_current - target_x) <= 0.48:
				if curve_tick_timer >= 0.08:
					curve_tick_timer = 0.0
					combo += 1
					max_combo = maxi(max_combo, combo)
					score += 80 + combo * 3
					SFXManager.play_tick()
					_spawn_lever_sparks(target_x, 4)
			else:
				if curve_tick_timer >= 0.2:
					curve_tick_timer = 0.0
					combo = 0
		elif song_time > end_time:
			active_curve_holds.erase(hold)

func _try_hit_lanes(lanes: Array) -> void:
	var best_note: Dictionary = {}
	var min_diff: float = INF
	
	for note_var in active_notes:
		var note: Dictionary = note_var
		var n_type: int = int(note.get("type", Global.NoteType.TAP))
		if n_type in [Global.NoteType.LEVER_FLICK_LEFT, Global.NoteType.LEVER_FLICK_RIGHT, Global.NoteType.LEVER_CURVE_HOLD]:
			continue
		var n_lane: int = int(note.get("lane", 0))
		if not n_lane in lanes:
			continue
			
		var note_time: float = float(note.get("time", 0.0))
		var diff: float = absf(song_time - note_time)
		if diff < min_diff:
			min_diff = diff
			best_note = note
			
	if best_note.is_empty() or min_diff > Global.GOOD_WINDOW:
		return
		
	var target_lane: int = int(best_note.get("lane", 0))
	var kind: int = int(best_note.get("type", Global.NoteType.TAP))
	active_notes.erase(best_note)
	
	if kind == Global.NoteType.HOLD:
		holding_notes[target_lane] = best_note
		hold_tick_timers[target_lane] = 0.0
		_trigger_judgement("EXACT", 1000, target_lane, false)
		SFXManager.play_tap(1.0)
	else:
		if min_diff <= Global.PERFECT_WINDOW * 0.5:
			_trigger_judgement("EXACT", 1000, target_lane, false)
			SFXManager.play_tap(1.1)
		elif min_diff <= Global.PERFECT_WINDOW:
			_trigger_judgement("PERFECT", 1000, target_lane, false)
			SFXManager.play_tap(1.0)
		elif min_diff <= Global.GREAT_WINDOW:
			_trigger_judgement("GREAT", 700, target_lane, false)
			SFXManager.play_tap(0.9)
		else:
			_trigger_judgement("GOOD", 400, target_lane, false)
			SFXManager.play_tap(0.8)

func _try_lever_flick(direction: int) -> void:
	var target_type: int = Global.NoteType.LEVER_FLICK_LEFT if direction < 0 else Global.NoteType.LEVER_FLICK_RIGHT
	var best_note: Dictionary = {}
	var min_diff: float = INF
	
	for note_var in active_notes:
		var note: Dictionary = note_var
		if int(note.get("type", Global.NoteType.TAP)) == target_type:
			var note_time: float = float(note.get("time", 0.0))
			var diff: float = absf(song_time - note_time)
			if diff < min_diff:
				min_diff = diff
				best_note = note
				
	if best_note.is_empty() or min_diff > Global.GOOD_WINDOW:
		return
		
	var flick_x: float = float(best_note.get("x", 0.0))
	active_notes.erase(best_note)
	_trigger_judgement("EXACT", 1200, 0, true)
	_spawn_lever_sparks(flick_x, 18)
	SFXManager.play_flick()

func _trigger_judgement(kind: String, points: int, lane: int, is_lever: bool = false) -> void:
	judge_text = kind
	judge_color = Global.JUDGE_COLORS.get(kind, Color.WHITE)
	judge_anim_timer = 1.0
	combo_bounce = 1.0
	
	if kind != "MISS":
		if kind == "EXACT" or kind == "PERFECT":
			judge_counts["PERFECT"] = int(judge_counts["PERFECT"]) + 1
		elif kind == "GREAT":
			judge_counts["GREAT"] = int(judge_counts["GREAT"]) + 1
		elif kind == "GOOD":
			judge_counts["GOOD"] = int(judge_counts["GOOD"]) + 1
		combo += 1
		max_combo = maxi(max_combo, combo)
		score += points + combo * 10
		if not is_lever:
			_spawn_hit_sparks(lane, 14)
	else:
		judge_counts["MISS"] = int(judge_counts["MISS"]) + 1
		combo = 0
		
	total_hits += 1
	var perfects: int = int(judge_counts["PERFECT"])
	var greats: int = int(judge_counts["GREAT"])
	var goods: int = int(judge_counts["GOOD"])
	var total: float = float(maxi(1, total_hits))
	accuracy = ((perfects * 1.0 + greats * 0.7 + goods * 0.4) / total) * 100.0

func _spawn_hit_sparks(lane: int, count: int) -> void:
	var lane_ratio: float = -0.75 + lane * 0.5
	var center: Vector2 = project_floor_point(lane_ratio, 0.0)
	var color: Color = Global.LANE_COLORS[lane]
	
	for i in range(count):
		var angle: float = randf() * TAU
		var speed: float = randf_range(70.0, 260.0)
		hit_sparks.append({
			"pos": center,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"color": color.lerp(Color.WHITE, randf() * 0.6),
			"size": randf_range(3.0, 8.0),
			"life": 1.0
		})

func _spawn_lever_sparks(x_ratio: float, count: int) -> void:
	var center: Vector2 = project_lever_point(x_ratio, 0.0)
	for i in range(count):
		var angle: float = randf() * TAU
		var speed: float = randf_range(90.0, 320.0)
		hit_sparks.append({
			"pos": center,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"color": Color("d500f9").lerp(Color("00e5ff"), randf()),
			"size": randf_range(4.0, 10.0),
			"life": 1.0
		})

func _finish_game() -> void:
	music.stop()
	SFXManager.play_ui_select()
	screen = Screen.RESULT

# ==========================================
# 렌더링 (_draw)
# ==========================================
func _draw() -> void:
	var v: Vector2 = get_viewport_rect().size
	_draw_background(v)
	
	match screen:
		Screen.TITLE:
			_draw_title_screen(v)
		Screen.MODE:
			_draw_mode_screen(v)
		Screen.SONG:
			_draw_song_screen(v)
		Screen.PLAY:
			_draw_play_screen(v)
		Screen.RESULT:
			_draw_result_screen(v)

func _draw_background(v: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, v), Color("03060f"))
	
	# 상단 트러스 / 배경 구조물
	for i in range(7):
		var px := 40.0 + i * 200.0
		draw_line(Vector2(px, 0), Vector2(px + 60.0, 140.0), Color(0.12, 0.28, 0.5, 0.15), 1.5)
		
	# 사이드 홀로그램 파티클
	for p in bg_particles:
		var pos: Vector2 = p["pos"]
		var s: float = float(p["size"])
		var a: float = float(p["alpha"])
		var col: Color = p["color"]
		var tri := PackedVector2Array([
			pos + Vector2(0, -s * 0.6),
			pos + Vector2(-s * 0.5, s * 0.5),
			pos + Vector2(s * 0.5, s * 0.5)
		])
		draw_colored_polygon(tri, col * Color(1, 1, 1, a * 0.35))
		draw_polyline(tri, col * Color(1, 1, 1, a), 1.2)

# ==========================================
# 4. 3D 원근 인게임 화면 (사진 1:1 완벽 구현)
# ==========================================
func _draw_play_screen(v: Vector2) -> void:
	# 1. 3D 메탈릭 사이드 레일 월 (Shift/Space 등 키 라벨 완전 제거)
	_draw_3d_side_walls(v)
	
	# 2. 3D 메인 트랙 바닥
	_draw_3d_main_track(v)
	
	# 3. 4키 바닥 키 빔 (D F J K)
	_draw_3d_key_beams()
	
	# 4. 바닥 롱노트 바디 (하늘색/시안 솔리드 3D 트랙)
	_draw_3d_floor_hold_notes()
	
	# 5. 바닥 4키 탭/홀드 노트 헤드
	_draw_3d_floor_notes()
	
	# 6. 하단 판정선 (형광 시안 네온 레이저 라인)
	var p_floor_l: Vector2 = project_floor_point(-1.02, 0.0)
	var p_floor_r: Vector2 = project_floor_point(1.02, 0.0)
	draw_line(p_floor_l, p_floor_r, Color("00e5ff") * Color(1, 1, 1, 0.6), 8.0)
	draw_line(p_floor_l, p_floor_r, Color.WHITE, 3.5)
	
	# 7. 하단 3D 입체 키패드 (D, F, J, K)
	_draw_3d_floor_keypads()
	
	# ════════════════════════════════════════════════════════
	# [상단 공중 레이어] 바닥면과 완전히 분리된 공중 판정면
	# ════════════════════════════════════════════════════════
	
	# 8. 상단 공중 3D 리본 롱노트 (보라/핑크 와이어프레임 메쉬)
	_draw_3d_lever_ribbon_holds()
	
	# 9. 상단 공중 대형 갈고리 플릭 노트
	_draw_3d_aerial_flick_notes()
	
	# 10. 상단 판정선 (보라색 네온 레이저 + 크리스탈 파티클 띠)
	var p_lev_l: Vector2 = project_lever_point(-1.08, 0.0)
	var p_lev_r: Vector2 = project_lever_point(1.08, 0.0)
	draw_line(p_lev_l, p_lev_r, Color("d500f9") * Color(1, 1, 1, 0.6), 6.0)
	draw_line(p_lev_l, p_lev_r, Color("e040fb"), 2.5)
	
	# 브라켓 마커 [ ]
	draw_line(p_lev_l + Vector2(-8, -12), p_lev_l, Color("e040fb"), 3.0)
	draw_line(p_lev_l + Vector2(-8, 12), p_lev_l, Color("e040fb"), 3.0)
	draw_line(p_lev_r + Vector2(8, -12), p_lev_r, Color("e040fb"), 3.0)
	draw_line(p_lev_r + Vector2(8, 12), p_lev_r, Color("e040fb"), 3.0)
	
	# 사진 속 가로 크리스탈 입자 클라우드 (흰색+보라색 반짝임)
	for i in range(24):
		var ratio: float = -0.85 + i * (1.7 / 24.0)
		var pt: Vector2 = project_lever_point(ratio, 0.0)
		var offset_y: float = sin(anim_time * 5.0 + i * 1.4) * 6.0
		var p_size: float = 3.5 + (sin(anim_time * 8.0 + i) + 1.0) * 2.0
		var p_tri: PackedVector2Array = PackedVector2Array([
			pt + Vector2(0, offset_y - p_size),
			pt + Vector2(-p_size * 0.8, offset_y + p_size * 0.6),
			pt + Vector2(p_size * 0.8, offset_y + p_size * 0.6)
		])
		draw_colored_polygon(p_tri, Color.WHITE * Color(1, 1, 1, 0.8) if i % 2 == 0 else Color("d500f9") * Color(1, 1, 1, 0.65))
	
	# 11. 상단 레버 캐릭터 (보라색 화살표 + 황금빛 발광 궤적선)
	_draw_3d_lever_indicator()
	
	# 12. 히트 스파크 파티클
	for spark in hit_sparks:
		var s_life: float = float(spark["life"])
		var s_size: float = float(spark["size"])
		var s_pos: Vector2 = spark["pos"]
		var s_col: Color = spark["color"]
		draw_circle(s_pos, s_size * s_life, s_col * Color(1, 1, 1, s_life))
		
	# 13. 콤보 & 판정 텍스트
	_draw_track_judgement_and_combo(v)
	
	# 14. 아케이드 HUD
	_draw_arcade_hud(v)

func _draw_3d_side_walls(v: Vector2) -> void:
	var wall_w: float = Global.SIDE_WALL_WIDTH_RATIO
	var tl_out: Vector2 = project_floor_point(-1.0 - wall_w, Global.APPROACH_TIME)
	var tl_in: Vector2 = project_floor_point(-1.0, Global.APPROACH_TIME)
	var bl_in: Vector2 = project_floor_point(-1.0, 0.0)
	var bl_out: Vector2 = project_floor_point(-1.0 - wall_w, 0.0)
	
	# 좌측 사이드 레일 바디 (메탈릭 다크 버건디)
	var left_wall: PackedVector2Array = PackedVector2Array([tl_out, tl_in, bl_in, bl_out])
	draw_colored_polygon(left_wall, Color("1a0824"))
	draw_polyline(PackedVector2Array([tl_out, bl_out]), Color("d500f9"), 3.0)
	draw_polyline(PackedVector2Array([tl_in, bl_in]), Color("00e5ff"), 2.0)
	for i in range(5):
		var t: float = (i + 1.0) / 6.0
		draw_line(tl_out.lerp(tl_in, t), bl_out.lerp(bl_in, t), Color("d500f9") * Color(1, 1, 1, 0.18), 1.0)
	
	# 우측 사이드 레일 바디
	var tr_in: Vector2 = project_floor_point(1.0, Global.APPROACH_TIME)
	var tr_out: Vector2 = project_floor_point(1.0 + wall_w, Global.APPROACH_TIME)
	var br_out: Vector2 = project_floor_point(1.0 + wall_w, 0.0)
	var br_in: Vector2 = project_floor_point(1.0, 0.0)
	
	var right_wall: PackedVector2Array = PackedVector2Array([tr_in, tr_out, br_out, br_in])
	draw_colored_polygon(right_wall, Color("1a0824"))
	draw_polyline(PackedVector2Array([tr_out, br_out]), Color("d500f9"), 3.0)
	draw_polyline(PackedVector2Array([tr_in, br_in]), Color("00e5ff"), 2.0)
	for i in range(5):
		var t: float = (i + 1.0) / 6.0
		draw_line(tr_in.lerp(tr_out, t), br_in.lerp(br_out, t), Color("d500f9") * Color(1, 1, 1, 0.18), 1.0)

func _draw_3d_main_track(v: Vector2) -> void:
	var tl: Vector2 = project_floor_point(-1.0, Global.APPROACH_TIME)
	var tr: Vector2 = project_floor_point(1.0, Global.APPROACH_TIME)
	var br: Vector2 = project_floor_point(1.0, 0.0)
	var bl: Vector2 = project_floor_point(-1.0, 0.0)
	
	# 메인 트랙 바닥
	var track_poly: PackedVector2Array = PackedVector2Array([tl, tr, br, bl])
	draw_colored_polygon(track_poly, Color("081020"))
	
	# 4개 레인 구분 세로선 (D, F, J, K 사이 3개 라인)
	for i in range(1, 4):
		var ratio: float = -1.0 + i * 0.5
		var p_top: Vector2 = project_floor_point(ratio, Global.APPROACH_TIME)
		var p_bot: Vector2 = project_floor_point(ratio, 0.0)
		draw_line(p_top, p_bot, Color(0.18, 0.45, 0.85, 0.55), 1.5)
		
	draw_line(tl, bl, Color("00e5ff"), 2.5)
	draw_line(tr, br, Color("00e5ff"), 2.5)
	
	# 가로 비트 라인
	var beat_offset: float = fmod(song_time * 2.0, 1.0)
	for i in range(12):
		var time_d: float = (i - beat_offset) * (Global.APPROACH_TIME * 0.1)
		if time_d >= 0.0 and time_d <= Global.APPROACH_TIME:
			var p1: Vector2 = project_floor_point(-1.0, time_d)
			var p2: Vector2 = project_floor_point(1.0, time_d)
			var alpha: float = (1.0 - time_d / Global.APPROACH_TIME) * 0.3
			draw_line(p1, p2, Color(0.15, 0.55, 0.95, alpha), 1.2)

func _draw_3d_key_beams() -> void:
	for i in range(4):
		var beam_a: float = key_beam_timers[i] * 0.45
		if beam_a <= 0.0:
			continue
		var r_left: float = -1.0 + i * 0.5
		var r_right: float = r_left + 0.5
		var p_tl: Vector2 = project_floor_point(r_left, Global.APPROACH_TIME * 0.85)
		var p_tr: Vector2 = project_floor_point(r_right, Global.APPROACH_TIME * 0.85)
		var p_br: Vector2 = project_floor_point(r_right, 0.0)
		var p_bl: Vector2 = project_floor_point(r_left, 0.0)
		
		var beam_poly: PackedVector2Array = PackedVector2Array([p_tl, p_tr, p_br, p_bl])
		draw_colored_polygon(beam_poly, Global.LANE_COLORS[i] * Color(1, 1, 1, beam_a))

func _draw_3d_floor_keypads() -> void:
		# 판정선 바로 아래 4개의 3D 입체 베벨 키패드 (D, F, J, K)
		# 권장 방식: 함수 상단에 미리 선언하거나 안전하게 대입
	var key_names: Array[String] = []
	if selected_mode == Global.PlayMode.PRO_4KEY_LEVER:
		key_names.assign(["D", "F", "J", "K"])
	else:
		key_names.assign(["D/F", "D/F", "J/K", "J/K"])
		for i in range(4):
			var r_l: float = -1.0 + i * 0.5 + 0.02
			var r_r: float = r_l + 0.46
			var p_tl: Vector2 = project_floor_point(r_l, 0.0)
			var p_tr: Vector2 = project_floor_point(r_r, 0.0)
			var p_bl: Vector2 = p_tl + Vector2(-6, 42)
			var p_br: Vector2 = p_tr + Vector2(6, 42)
			
			var pad_poly: PackedVector2Array = PackedVector2Array([p_tl, p_tr, p_br, p_bl])
			var is_press: bool = key_pressed_states[i]
			var pad_col: Color = Color("00e5ff") * Color(1,1,1,0.35) if is_press else Color("0a182d")
			draw_colored_polygon(pad_poly, pad_col)
			draw_polyline(pad_poly, Color("00e5ff") if is_press else Color("1a3558"), 2.0)
			
			var pad_center: Vector2 = (p_tl + p_tr + p_bl + p_br) * 0.25
			_draw_text_centered(key_names[i], pad_center + Vector2(0, 6), 20, Color.WHITE if is_press else Color("80d8ff"))

func _draw_3d_floor_hold_notes() -> void:
	for lane in range(4):
		var note_var = holding_notes[lane]
		if note_var == null:
			continue
		var note: Dictionary = note_var
		var note_time: float = float(note.get("time", 0.0))
		var duration: float = float(note.get("duration", 0.6))
		var end_time: float = note_time + duration
		var end_diff: float = end_time - song_time
		var r_left: float = -1.0 + lane * 0.5 + 0.02
		var r_right: float = r_left + 0.46
		
		var p_tl: Vector2 = project_floor_point(r_left, end_diff)
		var p_tr: Vector2 = project_floor_point(r_right, end_diff)
		var p_br: Vector2 = project_floor_point(r_right, 0.0)
		var p_bl: Vector2 = project_floor_point(r_left, 0.0)
		
		# 사진 속 선명한 하늘색/시안 3D 솔리드 바닥 트랙
		var poly: PackedVector2Array = PackedVector2Array([p_tl, p_tr, p_br, p_bl])
		draw_colored_polygon(poly, Color("00b0ff") * Color(1, 1, 1, 0.75))
		draw_polyline(PackedVector2Array([p_tl, p_bl]), Color("80d8ff"), 2.5)
		draw_polyline(PackedVector2Array([p_tr, p_br]), Color("80d8ff"), 2.5)
		
		# 중앙 하이라이트 코어 빔
		draw_colored_polygon(PackedVector2Array([
			project_floor_point(r_left + 0.14, end_diff),
			project_floor_point(r_right - 0.14, end_diff),
			project_floor_point(r_right - 0.14, 0.0),
			project_floor_point(r_left + 0.14, 0.0)
		]), Color.WHITE * Color(1, 1, 1, 0.9))

func _draw_3d_floor_notes() -> void:
	for note_var in active_notes:
		var note: Dictionary = note_var
		var n_type: int = int(note.get("type", Global.NoteType.TAP))
		if n_type in [Global.NoteType.LEVER_FLICK_LEFT, Global.NoteType.LEVER_FLICK_RIGHT]:
			continue
		var note_time: float = float(note.get("time", 0.0))
		var time_diff: float = note_time - song_time
		if time_diff < -0.1 or time_diff > Global.APPROACH_TIME:
			continue
			
		var lane: int = int(note.get("lane", 0))
		var r_l: float = -1.0 + lane * 0.5 + 0.02
		var r_r: float = r_l + 0.46
		
		if n_type == Global.NoteType.HOLD:
			var duration: float = float(note.get("duration", 0.6))
			var end_diff: float = (note_time + duration) - song_time
			var p_tl: Vector2 = project_floor_point(r_l, end_diff)
			var p_tr: Vector2 = project_floor_point(r_r, end_diff)
			var p_br: Vector2 = project_floor_point(r_r, time_diff)
			var p_bl: Vector2 = project_floor_point(r_l, time_diff)
			
			draw_colored_polygon(PackedVector2Array([p_tl, p_tr, p_br, p_bl]), Color("00b0ff") * Color(1, 1, 1, 0.6))
			draw_polyline(PackedVector2Array([p_tl, p_bl]), Color("80d8ff"), 2.0)
			draw_polyline(PackedVector2Array([p_tr, p_br]), Color("80d8ff"), 2.0)
			
		_draw_3d_tap_head(r_l, r_r, time_diff, Global.LANE_COLORS[lane])

func _draw_3d_tap_head(r_l: float, r_r: float, time_d: float, col: Color) -> void:
	var p_bl: Vector2 = project_floor_point(r_l, time_d)
	var p_br: Vector2 = project_floor_point(r_r, time_d)
	var p_tl: Vector2 = project_floor_point(r_l, time_d + 0.04)
	var p_tr: Vector2 = project_floor_point(r_r, time_d + 0.04)
	
	var note_poly: PackedVector2Array = PackedVector2Array([p_tl, p_tr, p_br, p_bl])
	draw_colored_polygon(note_poly, col)
	draw_polyline(note_poly, Color.WHITE, 1.8)

func _draw_3d_lever_ribbon_holds() -> void:
	for hold_var in active_curve_holds:
		var hold: Dictionary = hold_var
		var start_time: float = float(hold.get("time", 0.0))
		var duration: float = float(hold.get("duration", 1.0))
		var end_time: float = start_time + duration
		var start_x: float = float(hold.get("start_x", 0.0))
		var end_x: float = float(hold.get("end_x", 0.0))
		
		var segments: int = 26
		var strip_w: float = 0.58
		var left_points: PackedVector2Array = PackedVector2Array()
		var right_points: PackedVector2Array = PackedVector2Array()
		var center_points: PackedVector2Array = PackedVector2Array()
		
		for s in range(segments + 1):
			var seg_t: float = float(s) / float(segments)
			var cur_t: float = lerpf(start_time, end_time, seg_t)
			var time_d: float = cur_t - song_time
			if time_d < -0.2 or time_d > Global.APPROACH_TIME:
				continue
			var cur_x: float = lerpf(start_x, end_x, seg_t)
			left_points.append(project_lever_point(cur_x - strip_w * 0.5, time_d))
			right_points.append(project_lever_point(cur_x + strip_w * 0.5, time_d))
			center_points.append(project_lever_point(cur_x, time_d))
			
		if left_points.size() >= 2:
			var ribbon_poly: PackedVector2Array = PackedVector2Array()
			for pt in left_points:
				ribbon_poly.append(pt)
			for idx in range(right_points.size() - 1, -1, -1):
				ribbon_poly.append(right_points[idx])
			# 사진 좌측과 완벽히 동일한 반투명 바이올렛/핑크 공중 3D 리본
			draw_colored_polygon(ribbon_poly, Color(0.85, 0.25, 0.95, 0.45))
			draw_polyline(left_points, Color("ff4081"), 3.0)
			draw_polyline(right_points, Color("ff4081"), 3.0)
			draw_polyline(center_points, Color(1.0, 0.9, 0.3, 0.85), 2.0)
			
			# 3D 메쉬 와이어프레임 격자선
			for s in range(0, left_points.size(), 2):
				draw_line(left_points[s], right_points[s], Color(1.0, 0.5, 0.9, 0.45), 1.2)
				if s + 2 < left_points.size():
					draw_line(left_points[s], right_points[s + 2], Color(1.0, 0.5, 0.9, 0.25), 1.0)

func _draw_3d_aerial_flick_notes() -> void:
	for note_var in active_notes:
		var note: Dictionary = note_var
		var n_type: int = int(note.get("type", Global.NoteType.TAP))
		if n_type != Global.NoteType.LEVER_FLICK_LEFT and n_type != Global.NoteType.LEVER_FLICK_RIGHT:
			continue
		var note_time: float = float(note.get("time", 0.0))
		var time_diff: float = note_time - song_time
		if time_diff < -0.1 or time_diff > Global.APPROACH_TIME:
			continue
			
		var flick_x: float = float(note.get("x", 0.0))
		var p_center: Vector2 = project_lever_point(flick_x, time_diff)
		var progress: float = clampf(1.0 - time_diff / Global.APPROACH_TIME, 0.0, 1.0)
		var size: float = lerpf(36.0, 92.0, pow(progress, 1.7))
		
		var is_left: bool = (n_type == Global.NoteType.LEVER_FLICK_LEFT)
		var flick_col: Color = Color("00e5ff") if is_left else Color("ff4081")
		
		var hook_pts: PackedVector2Array = PackedVector2Array()
		if is_left:
			hook_pts.append(p_center + Vector2(size * 0.4, -size * 0.25))
			hook_pts.append(p_center + Vector2(-size * 0.6, -size * 0.25))
			hook_pts.append(p_center + Vector2(-size * 0.88, 0.0))
			hook_pts.append(p_center + Vector2(-size * 0.5, size * 0.38))
			hook_pts.append(p_center + Vector2(-size * 0.25, size * 0.15))
			hook_pts.append(p_center + Vector2(size * 0.4, size * 0.15))
		else:
			hook_pts.append(p_center + Vector2(-size * 0.4, -size * 0.25))
			hook_pts.append(p_center + Vector2(size * 0.6, -size * 0.25))
			hook_pts.append(p_center + Vector2(size * 0.88, 0.0))
			hook_pts.append(p_center + Vector2(size * 0.5, size * 0.38))
			hook_pts.append(p_center + Vector2(size * 0.25, size * 0.15))
			hook_pts.append(p_center + Vector2(-size * 0.4, size * 0.15))
			
		draw_colored_polygon(hook_pts, flick_col)
		draw_polyline(hook_pts, Color.WHITE, 2.5)
		_draw_text_centered("◀◀" if is_left else "▶▶", p_center + Vector2(0, 4), int(size * 0.28), Color("060d1f"))

func _draw_3d_lever_indicator() -> void:
	var p_lever: Vector2 = project_lever_point(lever_current, 0.0)
	var p_top: Vector2 = project_lever_point(lever_current * 0.5, Global.APPROACH_TIME)
	
	# 발광 궤적 빔
	draw_line(p_top, p_lever, Color(0.9, 1.0, 0.2, 0.75), 2.5)
	
	# 보라색 다이아몬드 레버
	var arrow_h: float = 24.0
	var arrow_w: float = 30.0
	var lever_poly: PackedVector2Array = PackedVector2Array([
		p_lever + Vector2(0, -arrow_h),
		p_lever + Vector2(-arrow_w * 0.5, arrow_h * 0.4),
		p_lever + Vector2(0, 0),
		p_lever + Vector2(arrow_w * 0.5, arrow_h * 0.4)
	])
	draw_colored_polygon(lever_poly, Color("d500f9"))
	draw_polyline(lever_poly, Color.WHITE, 2.0)

func _draw_track_judgement_and_combo(v: Vector2) -> void:
	var center_x: float = v.x * 0.5
	var combo_y: float = Global.LEVER_JUDGEMENT_Y - 95.0
	
	if combo > 0:
		var combo_scale: float = 1.0 + combo_bounce * 0.2
		_draw_text_centered(str(combo), Vector2(center_x, combo_y), int(64 * combo_scale), Color(0.25, 0.65, 0.95, 0.4))
		
	if judge_anim_timer > 0.0:
		var j_y: float = Global.LEVER_JUDGEMENT_Y - 20.0
		var j_col: Color = judge_color
		j_col.a = clampf(judge_anim_timer * 1.5, 0.0, 1.0)
		_draw_text_centered(judge_text, Vector2(center_x, j_y), 32, j_col)

func _draw_arcade_hud(v: Vector2) -> void:
	# 좌측 상단 SCORE
	var hud_rect: Rect2 = Rect2(25, 18, 380, 62)
	draw_rect(hud_rect, Color("050c18") * Color(1, 1, 1, 0.9))
	draw_rect(hud_rect, Color("00e5ff"), false, 1.5)
	
	_draw_text("SCORE", Vector2(40, 36), 11, Color("80d8ff"))
	_draw_text("%03d'%03d'%03d" % [score / 1000000, (score / 1000) % 1000, score % 1000], Vector2(40, 68), 28, Color("00f0ff"))
	
	# 체력 게이지
	var hp_rect: Rect2 = Rect2(25, 84, 380, 12)
	draw_rect(hp_rect, Color("140818"))
	draw_rect(Rect2(25, 84, 380 * clampf(accuracy / 100.0, 0.0, 1.0), 12), Color("ff1787"))
	draw_rect(hp_rect, Color.WHITE, false, 1.0)
	
	# 우측 상단 곡 정보
	var right_box: Rect2 = Rect2(v.x - 390, 18, 365, 62)
	draw_rect(right_box, Color("050c18") * Color(1, 1, 1, 0.9))
	draw_rect(right_box, Color("d500f9"), false, 1.5)
	
	var song_info: Dictionary = Charts.get_song(current_song_idx)
	_draw_text(song_info.get("title", "JACKPOT"), Vector2(v.x - 370, 42), 20, Color.WHITE)
	_draw_text("ACC %05.2f%%   BPM %d" % [accuracy, song_info.get("bpm", 174)], Vector2(v.x - 370, 66), 13, Color("00e676"))
	
	var prog_len: float = music.stream.get_length() if music.stream else 20.0
	var prog_ratio: float = clampf(song_time / maxf(1.0, prog_len), 0.0, 1.0)
	draw_rect(Rect2(v.x - 210, 50, 160, 6), Color("142244"))
	draw_rect(Rect2(v.x - 210, 50, 160 * prog_ratio, 6), Color("00e5ff"))

# ==========================================
# 1. 타이틀 화면
# ==========================================
func _draw_title_screen(v: Vector2) -> void:
	var center: Vector2 = Vector2(v.x * 0.5, v.y * 0.42)
	var glow_pulse: float = (sin(anim_time * 3.0) + 1.0) * 0.5
	
	draw_arc(center, 180.0 + glow_pulse * 10.0, 0, TAU, 64, Color(0.0, 0.85, 1.0, 0.15 + glow_pulse * 0.2), 3.0)
	_draw_text_centered("RHYTHM", center + Vector2(0, -40), 96, Color.WHITE)
	_draw_text_centered("PROJECT", center + Vector2(0, 50), 96, Color("00e5ff"))
	
	var badge_rect: Rect2 = Rect2(v.x * 0.5 - 180.0, center.y + 85.0, 360.0, 32.0)
	draw_rect(badge_rect, Color(0.05, 0.15, 0.35, 0.8))
	draw_rect(badge_rect, Color("00e5ff"), false, 1.5)
	_draw_text_centered("4키 리듬게임입니다. 그런데 이제 레버를 곁들인", Vector2(v.x * 0.5, center.y + 107.0), 16, Color("e0f7fa"))
	
	var blink: float = (sin(anim_time * 4.5) + 1.0) * 0.5
	var start_color: Color = Color("00f0ff").lerp(Color.WHITE, blink)
	start_color.a = 0.6 + blink * 0.4
	_draw_text_centered("▶  PRESS ANY KEY TO START  ◀", Vector2(v.x * 0.5, v.y * 0.84), 26, start_color)

# ==========================================
# 2. 모드 선택 화면
# ==========================================
func _draw_mode_screen(v: Vector2) -> void:
	_draw_text_centered("SELECT PLAY MODE", Vector2(v.x * 0.5, 90), 42, Color.WHITE)
	_draw_text_centered("CHOOSE YOUR CONTROL STYLE", Vector2(v.x * 0.5, 125), 16, Color("00e5ff"))
	
	var card_w: float = minf(v.x * 0.72, 780.0)
	var card_h: float = 150.0
	var start_x: float = (v.x - card_w) * 0.5
	
	for i in range(2):
		var is_sel: bool = (i == mode_cursor)
		var card_y: float = 180.0 + i * (card_h + 35.0)
		var r: Rect2 = Rect2(start_x, card_y, card_w, card_h)
		
		var pulse: float = (sin(anim_time * 5.0) + 1.0) * 0.5 if is_sel else 0.0
		var bg_col: Color = Color("122244") if is_sel else Color("091222")
		var border_col: Color = Color("00e5ff").lerp(Color.WHITE, pulse * 0.4) if is_sel else Color("22365c")
		
		draw_rect(r, bg_col)
		draw_rect(r, border_col, false, 3.5 if is_sel else 1.5)
		
		if is_sel:
			draw_rect(Rect2(r.position.x, r.position.y, 8.0, r.size.y), Color("00e5ff"))
			
		var mode_title: String = "MODE 01 : CASUAL LEVER 2-KEY" if i == 0 else "MODE 02 : PRO 4-KEY + LEVER"
		var mode_sub: String = "[마우스 이동] 레버 조작 + [D,F / J,K] 2버튼" if i == 0 else "3D 4키(D F J K) + 상단 레버 곡선 롱노트 & 대형 갈고리 플릭"
		var mode_ctrl: String = "[마우스 좌우] 레버  |  [D, F] 좌측 2키, [J, K] 우측 2키" if i == 0 else "조작: [D, F, J, K] 4키  |  [마우스] 레버 롱노트  |  [A/←] 좌 플릭  |  [L/→] 우 플릭"
		
		_draw_text(mode_title, r.position + Vector2(30, 42), 24, Color.WHITE if is_sel else Color("90a4ae"))
		_draw_text(mode_sub, r.position + Vector2(30, 80), 16, Color("00e5ff") if is_sel else Color("546e7a"))
		_draw_text(mode_ctrl, r.position + Vector2(30, 118), 14, Color("ffd740") if is_sel else Color("455a64"))
		
		var badge_col: Color = Color("00e5ff") if i == 0 else Color("ff4081")
		var badge_r: Rect2 = Rect2(r.end.x - 130.0, r.position.y + 40.0, 100.0, 70.0)
		draw_rect(badge_r, badge_col * Color(1, 1, 1, 0.15))
		draw_rect(badge_r, badge_col, false, 2.0)
		_draw_text_centered("CASUAL" if i == 0 else "PRO 4K", badge_r.get_center() + Vector2(0, 7), 18, badge_col)
		
	_draw_text_centered("▲ ▼ SELECT MODE      [ENTER / SPACE] CONFIRM      [ESC] BACK", Vector2(v.x * 0.5, v.y - 45), 16, Color("78909c"))

# ==========================================
# 3. 곡 및 난이도 선택 화면
# ==========================================
func _draw_song_screen(v: Vector2) -> void:
	_draw_text_centered("MUSIC & DIFFICULTY SELECT", Vector2(v.x * 0.5, 75), 36, Color.WHITE)
	
	var song_info: Dictionary = Charts.get_song(current_song_idx)
	var card_w: float = minf(v.x * 0.74, 820.0)
	var card_h: float = 380.0
	var card_rect: Rect2 = Rect2((v.x - card_w) * 0.5, 120.0, card_w, card_h)
	
	draw_rect(card_rect, Color("0a152d"))
	draw_rect(card_rect, Color("00e5ff"), false, 2.5)
	
	var jacket_rect: Rect2 = Rect2(card_rect.position.x + 30.0, card_rect.position.y + 30.0, 320.0, 320.0)
	draw_rect(jacket_rect, Color("142244"))
	draw_rect(jacket_rect, Color("304d80"), false, 2.0)
	
	var j_center: Vector2 = jacket_rect.get_center()
	draw_arc(j_center, 90.0, 0, TAU, 32, Color("00e5ff") * Color(1,1,1,0.4), 4.0)
	draw_arc(j_center, 60.0, anim_time, anim_time + PI, 24, Color("ff4081"), 3.0)
	_draw_text_centered("JACKPOT", j_center + Vector2(0, 8), 36, Color.WHITE)
	_draw_text_centered("ORIGINAL TRACK", j_center + Vector2(0, 38), 14, Color("80d8ff"))
	
	var info_x: float = card_rect.position.x + 380.0
	_draw_text("TRACK 01", Vector2(info_x, card_rect.position.y + 65), 20, Color("00e5ff"))
	_draw_text(song_info.get("title", "UNKNOWN"), Vector2(info_x, card_rect.position.y + 125), 48, Color.WHITE)
	_draw_text("ARTIST : " + song_info.get("artist", "RHYTHM PROJECT"), Vector2(info_x, card_rect.position.y + 165), 18, Color("90caf9"))
	_draw_text("BPM : " + str(song_info.get("bpm", 174)), Vector2(info_x, card_rect.position.y + 198), 18, Color("ffd54f"))
	
	var diff_names: Array[String] = ["EASY", "NORMAL", "HARD"]
	var diff_colors: Array[Color] = [Color("00e676"), Color("ffea00"), Color("ff1744")]
	var diff_y: float = card_rect.position.y + 240.0
	
	for d in range(3):
		var is_active: bool = (d == selected_diff)
		var tab_rect: Rect2 = Rect2(info_x + d * 130.0, diff_y, 118.0, 75.0)
		var col: Color = diff_colors[d]
		
		draw_rect(tab_rect, col * Color(1, 1, 1, 0.25 if is_active else 0.08))
		draw_rect(tab_rect, col if is_active else col * Color(1, 1, 1, 0.4), false, 3.0 if is_active else 1.0)
		
		_draw_text_centered(diff_names[d], Vector2(tab_rect.get_center().x, tab_rect.position.y + 30), 16, col if is_active else Color("78909c"))
		var d_chart: Dictionary = Charts.get_chart(current_song_idx, d as Global.Difficulty)
		var d_level: int = int(d_chart.get("level", 1))
		_draw_text_centered("LV. %02d" % d_level, Vector2(tab_rect.get_center().x, tab_rect.position.y + 58), 20, Color.WHITE if is_active else Color("90a4ae"))
		
	_draw_text_centered("[TAB / 1,2,3 / ◀ ▶] DIFFICULTY      [ENTER / SPACE] GAME START      [ESC] MODE SELECT", Vector2(v.x * 0.5, v.y - 45), 16, Color("78909c"))

# ==========================================
# 5. 결과 화면
# ==========================================
func _draw_result_screen(v: Vector2) -> void:
	_draw_text_centered("STAGE RESULT", Vector2(v.x * 0.5, 80), 44, Color.WHITE)
	_draw_text_centered("JACKPOT - RHYTHM PROJECT", Vector2(v.x * 0.5, 118), 18, Color("00e5ff"))
	
	var rank: String = "F"
	var rank_col: Color = Color("ff1744")
	if accuracy >= 99.0 and int(judge_counts["MISS"]) == 0:
		rank = "S+"
		rank_col = Color("ffd700")
	elif accuracy >= 95.0 and int(judge_counts["MISS"]) == 0:
		rank = "S"
		rank_col = Color("00e5ff")
	elif accuracy >= 90.0:
		rank = "A"
		rank_col = Color("76ff03")
	elif accuracy >= 80.0:
		rank = "B"
		rank_col = Color("ff9100")
	elif accuracy >= 70.0:
		rank = "C"
		rank_col = Color("ff5252")
		
	var rank_center: Vector2 = Vector2(v.x * 0.28, 330.0)
	draw_arc(rank_center, 110.0, 0, TAU, 48, rank_col * Color(1,1,1,0.3), 6.0)
	_draw_text_centered(rank, rank_center + Vector2(0, 48), 140, rank_col)
	_draw_text_centered("CLEAR RANK", rank_center + Vector2(0, 150), 20, Color("90a4ae"))
	
	var panel_rect: Rect2 = Rect2(v.x * 0.48, 170.0, minf(v.x * 0.44, 520.0), 360.0)
	draw_rect(panel_rect, Color("0a162c"))
	draw_rect(panel_rect, Color("00e5ff"), false, 2.0)
	
	var px: float = panel_rect.position.x + 35.0
	_draw_text("FINAL SCORE", Vector2(px, panel_rect.position.y + 48), 20, Color("80d8ff"))
	_draw_text("%09d" % score, Vector2(px, panel_rect.position.y + 90), 42, Color.WHITE)
	
	_draw_text("ACCURACY", Vector2(px + 260.0, panel_rect.position.y + 48), 20, Color("80d8ff"))
	_draw_text("%05.2f%%" % accuracy, Vector2(px + 260.0, panel_rect.position.y + 90), 38, Color("00e676"))
	
	var stat_y: float = panel_rect.position.y + 155.0
	_draw_text("PERFECT", Vector2(px, stat_y), 20, Global.JUDGE_COLORS["PERFECT"])
	_draw_text("%03d" % int(judge_counts["PERFECT"]), Vector2(px + 280, stat_y), 20, Color.WHITE)
	
	_draw_text("GREAT", Vector2(px, stat_y + 35), 20, Global.JUDGE_COLORS["GREAT"])
	_draw_text("%03d" % int(judge_counts["GREAT"]), Vector2(px + 280, stat_y + 35), 20, Color.WHITE)
	
	_draw_text("GOOD", Vector2(px, stat_y + 70), 20, Global.JUDGE_COLORS["GOOD"])
	_draw_text("%03d" % int(judge_counts["GOOD"]), Vector2(px + 280, stat_y + 70), 20, Color.WHITE)
	
	_draw_text("MISS", Vector2(px, stat_y + 105), 20, Global.JUDGE_COLORS["MISS"])
	_draw_text("%03d" % int(judge_counts["MISS"]), Vector2(px + 280, stat_y + 105), 20, Color.WHITE)
	
	_draw_text("MAX COMBO", Vector2(px, stat_y + 150), 22, Color("ffd54f"))
	_draw_text("%03d" % max_combo, Vector2(px + 280, stat_y + 150), 22, Color("ffd54f"))
	
	_draw_text_centered("[ENTER / SPACE] BACK TO MUSIC SELECT      [ESC] MODE SELECT", Vector2(v.x * 0.5, v.y - 45), 16, Color("78909c"))

# ==========================================
# 헬퍼 텍스트 드로잉
# ==========================================
func _draw_text(s: String, pos: Vector2, size: int, col: Color = Color.WHITE) -> void:
	draw_string(ThemeDB.fallback_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, col)

func _draw_text_centered(s: String, pos: Vector2, size: int, col: Color = Color.WHITE) -> void:
	var font: Font = ThemeDB.fallback_font
	var str_size: Vector2 = font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size)
	draw_string(font, pos - Vector2(str_size.x * 0.5, -size * 0.3), s, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, col)
