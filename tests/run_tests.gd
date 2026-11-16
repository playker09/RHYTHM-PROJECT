extends SceneTree
## 단위 테스트 러너 (GUT 없이 실행 가능). 순수 로직(JudgeLogic, TimingMap, Judge, ScoreManager)을 검증한다.
## 실행: Godot --headless --path . -s tests/run_tests.gd

var _checks: int = 0
var _fails: int = 0

func _init() -> void:
	test_grades()
	test_miss_window()
	test_timing_map()
	test_chart_loader()
	test_effects()
	test_tap_flow()
	test_hold_flow()
	test_score()
	test_score_rank()
	test_field_logic()
	test_field_flow()
	test_flick_logic()
	test_flick_flow()
	test_flick_width_and_air_alert()
	test_chart_summary()
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)

func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("FAIL: " + msg)

# --- JudgeLogic ---
func test_grades() -> void:
	var P := JudgeLogic.Grade.PERFECT
	var G := JudgeLogic.Grade.GREAT
	var M := JudgeLogic.Grade.MISS
	_check(JudgeLogic.grade_from_delta(0.0) == P, "0ms perfect")
	_check(JudgeLogic.grade_from_delta(35.0) == P, "+35 perfect")
	_check(JudgeLogic.grade_from_delta(-35.0) == P, "-35 perfect")
	_check(JudgeLogic.grade_from_delta(36.0) == G, "36 great")
	_check(JudgeLogic.grade_from_delta(-70.0) == G, "-70 great")
	_check(JudgeLogic.grade_from_delta(71.0) == M, "71 miss")

func test_miss_window() -> void:
	_check(not JudgeLogic.is_missed(1070.0, 1000.0), "1070 not yet missed")
	_check(JudgeLogic.is_missed(1071.0, 1000.0), "1071 missed")

# --- TimingMap ---
func test_timing_map() -> void:
	var tm := TimingMap.new([{"time": 0, "bpm": 120}])
	var ticks: Array[float] = tm.tick_times(2000.0, 3000.0, 0.125)
	_check(ticks.size() == 16, "120bpm 1s hold = 16 ticks, got %d" % ticks.size())
	_check(is_equal_approx(ticks[0], 2062.5), "first tick 2062.5")
	_check(is_equal_approx(ticks[15], 3000.0), "last tick = end")

	var tm2 := TimingMap.new([{"time": 0, "bpm": 120}, {"time": 1000, "bpm": 60}])
	var t2: Array[float] = tm2.tick_times(0.0, 2000.0, 0.125)
	_check(t2.size() == 24, "bpm change tick count, got %d" % t2.size())
	_check(is_equal_approx(t2[t2.size() - 1], 2000.0), "bpm change last = end")

# --- ChartLoader ---
func test_chart_loader() -> void:
	var chart: ChartData = ChartLoader.load_chart("res://charts/sample/nm.json")
	_check(chart != null, "sample chart loads")
	if chart == null:
		return
	_check(chart.notes.size() > 50, "sample has notes")
	var sorted: bool = true
	for i in range(1, chart.notes.size()):
		if chart.notes[i].time < chart.notes[i - 1].time:
			sorted = false
	_check(sorted, "notes sorted by time")
	_check(ChartLoader.load_chart("res://nope.json") == null, "missing file -> null")

# --- 연출 (effects) ---
func test_effects() -> void:
	var fx: Array[Dictionary] = ChartLoader.parse_effects([
		{"type": "spin", "time": 4000, "duration": 1000, "turns": 1, "dir": "ccw"},
		{"type": "flash", "time": 1000, "side": "right"},
		{"type": "flash", "time": 2000, "duration": 200, "side": "both", "strength": 0.5},
		{"type": "glitch", "time": 3000},
		{"type": "nope", "time": 0}, {"type": "flash"}, 7,
	])
	_check(fx.size() == 4, "bad effects dropped, got %d" % fx.size())
	_check(fx[0]["type"] == "flash" and fx[3]["type"] == "spin", "effects sorted by time")
	_check(is_equal_approx(fx[0]["strength"], 1.0) and is_equal_approx(fx[2]["duration"], 500.0), "effect defaults filled")
	_check(ChartLoader.parse_effects([{"type": "zoom", "time": 0}]).is_empty(), "removed type zoom dropped")
	var track := EffectTrack.new()
	track.setup(fx)
	var s: Dictionary = track.sample(999.0)
	_check(s["flash_r"] == 0.0 and s["glitch"] == 0.0 and s["spin"] == 0.0, "nothing before first effect")
	s = track.sample(1000.0)
	_check(is_equal_approx(s["flash_r"], 1.0) and s["flash_l"] == 0.0, "flash right only")
	_check(track.sample(1200.0)["flash_r"] < 1.0 and track.sample(1500.0)["flash_r"] == 0.0, "flash fades out")
	_check(is_equal_approx(track.sample(2100.0)["flash_l"], 0.5), "flash holds for duration, both sides")
	_check(track.sample(2700.0)["flash_l"] == 0.0, "held flash returns to 0")
	_check(is_equal_approx(track.sample(3100.0)["glitch"], 0.5) and track.sample(3500.0)["glitch"] == 0.0, "glitch window")
	_check(is_equal_approx(track.sample(4500.0)["spin"], PI), "spin halfway = half turn ccw")
	_check(track.sample(5000.0)["spin"] == 0.0, "spin ends at rest")

# --- Judge (순수 입력 시뮬레이션) ---
func _make_judge(notes: Array, log: Array) -> Judge:
	var chart := ChartData.new()
	for n in notes:
		chart.notes.append(n)
	var j := Judge.new()
	j.setup(chart)
	j.judged.connect(func(_n: NoteData, g: int, _d: float, tick: bool) -> void: log.append([g, tick]))
	return j

func test_tap_flow() -> void:
	var P := JudgeLogic.Grade.PERFECT
	var G := JudgeLogic.Grade.GREAT
	var M := JudgeLogic.Grade.MISS

	var log: Array = []
	var j := _make_judge([NoteData.make_tap(1000.0, 0)], log)
	j.press(0, 1010.0)
	_check(log.size() == 1 and log[0][0] == P, "tap perfect")
	j.free()

	log = []
	j = _make_judge([NoteData.make_tap(1000.0, 0)], log)
	j.press(0, 1050.0)
	_check(log.size() == 1 and log[0][0] == G, "tap great")
	j.free()

	log = []
	j = _make_judge([NoteData.make_tap(1000.0, 0)], log)
	j.press(0, 900.0)
	_check(log.size() == 0, "too-early press ignored")
	j.release(0, 950.0)
	j.press(0, 1000.0)
	_check(log.size() == 1 and log[0][0] == P, "note still hittable after early press")
	j.free()

	log = []
	j = _make_judge([NoteData.make_tap(1000.0, 0)], log)
	j.advance(1070.0)
	_check(log.size() == 0, "not missed at 1070")
	j.advance(1071.0)
	_check(log.size() == 1 and log[0][0] == M, "missed at 1071")
	j.free()

	log = []
	j = _make_judge([NoteData.make_tap(1000.0, 0)], log)
	j.press(1, 1000.0)
	_check(log.size() == 0, "wrong lane ignored")
	j.free()

func test_hold_flow() -> void:
	var log: Array = []
	var j := _make_judge([NoteData.make_hold(2000.0, 3000.0, 1)], log)
	_check(j.total_judgements == 17, "hold total = head + 16 ticks, got %d" % j.total_judgements)
	j.press(1, 2000.0)
	j.advance(2500.0)
	j.release(1, 2500.0)       # 2500 tick까지는 눌린 상태로 판정
	j.advance(2750.0)          # 2562.5 ~ 2750 : 4 tick MISS
	j.press(1, 2750.0)
	j.advance(3001.0)          # 2812.5 ~ 3000 : 4 tick OK
	var ok_ticks: int = 0
	var miss_ticks: int = 0
	var heads: int = 0
	for e in log:
		if not e[1]:
			heads += 1
		elif e[0] == JudgeLogic.Grade.PERFECT:
			ok_ticks += 1
		else:
			miss_ticks += 1
	_check(heads == 1, "one head judgement")
	_check(ok_ticks == 12, "12 ticks ok, got %d" % ok_ticks)
	_check(miss_ticks == 4, "4 ticks missed, got %d" % miss_ticks)
	j.free()

# --- Field ---
const KEYS := [{"time": 4000, "center": 0.3, "width": 0.25}, {"time": 6000, "center": 0.7, "width": 0.15}]

func test_field_logic() -> void:
	var mid: Dictionary = JudgeLogic.field_interp(KEYS, 5000.0)
	_check(is_equal_approx(mid["center"], 0.5) and is_equal_approx(mid["width"], 0.2), "field interp midpoint")
	var before: Dictionary = JudgeLogic.field_interp(KEYS, 3000.0)
	_check(is_equal_approx(before["center"], 0.3), "field clamp before start")
	var after: Dictionary = JudgeLogic.field_interp(KEYS, 7000.0)
	_check(is_equal_approx(after["width"], 0.15), "field clamp after end")
	_check(JudgeLogic.field_inside(0.55, 0.5, 0.2), "inside")
	_check(JudgeLogic.field_inside(0.6, 0.5, 0.2), "edge counts as inside")
	_check(not JudgeLogic.field_inside(0.61, 0.5, 0.2), "outside")
	_check(JudgeLogic.field_tick_result(true, 0.0, 150.0) == JudgeLogic.Grade.PERFECT, "tick inside")
	_check(JudgeLogic.field_tick_result(false, 150.0, 150.0) == JudgeLogic.GRADE_SKIP, "grace edge skip")
	_check(JudgeLogic.field_tick_result(false, 151.0, 150.0) == JudgeLogic.Grade.MISS, "past grace miss")

func test_field_flow() -> void:
	var chart := ChartData.new()
	var f := NoteData.new()
	f.type = NoteData.Type.FIELD
	f.keys = [{"time": 1000.0, "center": 0.5, "width": 0.2}, {"time": 2000.0, "center": 0.5, "width": 0.2}]
	f.time = 1000.0
	f.end_time = 2000.0
	chart.notes.append(f)
	var fc := FieldController.new()
	fc.setup(chart)
	var log: Array = []
	var j := Judge.new()
	j.field = fc
	j.setup(chart)
	j.judged.connect(func(_n: NoteData, g: int, _d: float, _t: bool) -> void: log.append(g))
	_check(j.total_judgements == 16, "field total 16 ticks, got %d" % j.total_judgements)

	j.advance(1500.0)                 # 안에 있음: tick 8개 PERFECT
	fc.set_cursor(0.9, 1500.0)        # 이탈
	j.advance(1600.0)                 # 1562.5: 유예 -> SKIP
	j.advance(1700.0)                 # 1625 SKIP, 1687.5 MISS
	j.advance(1750.0)                 # 1750 MISS
	_check(fc.is_outside, "controller reports outside")
	fc.set_cursor(0.5, 1750.0)        # 복귀
	_check(not fc.is_outside, "controller reports inside after return")
	j.advance(2001.0)                 # 4 tick PERFECT
	var ok: int = log.count(JudgeLogic.Grade.PERFECT)
	var miss: int = log.count(JudgeLogic.Grade.MISS)
	_check(ok == 12, "field 12 ok, got %d" % ok)
	_check(miss == 2, "field 2 miss, got %d" % miss)
	_check(log.size() == 14, "2 ticks skipped without judgement, got %d" % log.size())

	# 마우스 이동량 -> 커서 (감도 2.0, 250px = 0.5)
	fc.sensitivity = 2.0
	fc.set_cursor(0.0, 3000.0)
	fc.apply_motion(250.0, 3000.0)
	_check(is_equal_approx(fc.cursor_x, 0.5), "motion maps to cursor with sensitivity")
	fc.apply_motion(5000.0, 3000.0)
	_check(fc.cursor_x == 1.0, "cursor clamps at 1.0")
	j.free()
	fc.free()

# --- Flick ---
func test_flick_logic() -> void:
	_check(JudgeLogic.flick_crossed(0.4, 0.6, 0.5, "right"), "cross right")
	_check(not JudgeLogic.flick_crossed(0.6, 0.4, 0.5, "right"), "wrong way for right")
	_check(JudgeLogic.flick_crossed(0.6, 0.4, 0.5, "left"), "cross left")
	_check(not JudgeLogic.flick_crossed(0.4, 0.45, 0.5, "right"), "did not reach note")
	_check(JudgeLogic.flick_crossed(0.9, 1.0, 1.0, "right"), "reaching clamped edge counts")
	_check(JudgeLogic.flick_speed_ok(2.0, "right", 1.5), "fast enough right")
	_check(not JudgeLogic.flick_speed_ok(1.0, "right", 1.5), "too slow")
	_check(not JudgeLogic.flick_speed_ok(-2.0, "right", 1.5), "wrong sign speed")
	_check(JudgeLogic.flick_speed_ok(-2.0, "left", 1.5), "fast enough left")
	_check(JudgeLogic.flick_grade(35.0) == JudgeLogic.Grade.PERFECT, "flick perfect")
	_check(JudgeLogic.flick_grade(-130.0) == JudgeLogic.Grade.GREAT, "flick great at window edge")
	_check(JudgeLogic.flick_grade(131.0) == JudgeLogic.Grade.MISS, "flick miss outside window")

func _make_flick(t: float, x: float, dir: String) -> NoteData:
	var n := NoteData.new()
	n.type = NoteData.Type.FLICK
	n.time = t
	n.end_time = t
	n.x = x
	n.dir = dir
	return n

func _flick_rig(notes: Array, log: Array) -> Array:
	var chart := ChartData.new()
	for n in notes:
		chart.notes.append(n)
	var fc := FieldController.new()
	fc.sensitivity = 1.0
	fc.setup(chart)
	var j := Judge.new()
	j.field = fc
	j.setup(chart)
	j.judged.connect(func(_n: NoteData, g: int, _d: float, _t: bool) -> void: log.append(g))
	return [j, fc]

func test_flick_flow() -> void:
	var P := JudgeLogic.Grade.PERFECT
	var M := JudgeLogic.Grade.MISS

	# 빠르게 오른쪽으로 가로지름 -> PERFECT
	var log: Array = []
	var rig: Array = _flick_rig([_make_flick(3000.0, 0.5, "right")], log)
	var j: Judge = rig[0]
	var fc: FieldController = rig[1]
	_check(j.total_judgements == 1, "flick counts as one judgement")
	fc.set_cursor(0.3, 2950.0)
	j.move_cursor(300.0, 2970.0)          # 0.3 -> 0.6, 속도 15/s
	_check(log.size() == 1 and log[0] == P, "fast right flick perfect")
	j.free()
	fc.free()

	# 느리게 지나감 -> 무시되고 윈도우 뒤에 MISS
	log = []
	rig = _flick_rig([_make_flick(3000.0, 0.5, "right")], log)
	j = rig[0]
	fc = rig[1]
	fc.set_cursor(0.45, 2990.0)
	for i in range(1, 11):
		j.move_cursor(5.0, 2990.0 + i * 10.0)    # 0.005씩 -> 속도 0.5/s
	_check(log.size() == 0, "slow drift ignored")
	j.advance(3131.0)
	_check(log.size() == 1 and log[0] == M, "slow drift -> miss after window")
	j.free()
	fc.free()

	# 반대 방향 -> 무시
	log = []
	rig = _flick_rig([_make_flick(3000.0, 0.5, "right")], log)
	j = rig[0]
	fc = rig[1]
	fc.set_cursor(0.7, 2950.0)
	j.move_cursor(-300.0, 2970.0)
	_check(log.size() == 0, "wrong direction ignored")
	j.free()
	fc.free()

	# 왼쪽 플릭 성공
	log = []
	rig = _flick_rig([_make_flick(3000.0, 0.5, "left")], log)
	j = rig[0]
	fc = rig[1]
	fc.set_cursor(0.7, 2950.0)
	j.move_cursor(-300.0, 2970.0)
	_check(log.size() == 1 and log[0] == P, "left flick perfect")
	j.free()
	fc.free()

	# 윈도우 밖(너무 이름) -> 무시, 이후 MISS 한 번만
	log = []
	rig = _flick_rig([_make_flick(3000.0, 0.5, "right")], log)
	j = rig[0]
	fc = rig[1]
	fc.set_cursor(0.3, 2800.0)
	j.move_cursor(300.0, 2820.0)
	_check(log.size() == 0, "too-early crossing ignored")
	j.advance(3101.0)
	j.advance(3200.0)
	_check(log.size() == 1 and log[0] == M, "single miss judgement")
	j.free()
	fc.free()

# --- ScoreManager ---
func test_score() -> void:
	var s := ScoreManager.new()
	s.setup(2)
	s.on_judged(null, JudgeLogic.Grade.PERFECT, 0.0, false)
	s.on_judged(null, JudgeLogic.Grade.GREAT, 0.0, false)
	_check(s.score == 850000, "score 850000, got %d" % s.score)
	_check(s.combo == 2 and s.max_combo == 2, "combo 2")
	s.on_judged(null, JudgeLogic.Grade.MISS, 0.0, false)
	_check(s.combo == 0 and s.max_combo == 2, "combo reset keeps max")
	s.free()

func test_score_rank() -> void:
	var s := ScoreManager.new()
	s.setup(3)
	s.on_judged(null, JudgeLogic.Grade.PERFECT, 0.0, false)
	s.on_judged(null, JudgeLogic.Grade.PERFECT, 0.0, false)
	s.on_judged(null, JudgeLogic.Grade.PERFECT, 0.0, false)
	_check(s.rank() == "AP" and s.is_full_combo(), "all perfect -> AP")
	s.setup(3)
	s.on_judged(null, JudgeLogic.Grade.GREAT, -20.0, false)
	s.on_judged(null, JudgeLogic.Grade.GREAT, 20.0, false)
	s.on_judged(null, JudgeLogic.Grade.GREAT, 10.0, true)
	_check(s.fast == 1 and s.slow == 1, "fast/slow counted for non-tick GREAT only")
	_check(s.rank() == "C" and s.is_full_combo(), "70%% score -> C full combo, got %s" % s.rank())
	s.on_judged(null, JudgeLogic.Grade.MISS, 0.0, false)
	_check(not s.is_full_combo(), "miss breaks full combo")
	s.free()

# --- 선곡 화면용 요약 ---
func test_flick_width_and_air_alert() -> void:
	# 폭 0 = 한 줄을 가로질러야 한다. 폭이 있으면 그 안에서 움직이기만 해도 된다
	_check(not JudgeLogic.flick_crossed(0.20, 0.30, 0.5, "right"), "flick width 0: moving left of the line does not count")
	_check(JudgeLogic.flick_crossed(0.20, 0.30, 0.5, "right", 0.6), "flick width: movement inside the span counts")
	_check(not JudgeLogic.flick_crossed(0.05, 0.10, 0.5, "right", 0.6), "flick width: movement outside the span does not count")
	_check(not JudgeLogic.flick_crossed(0.30, 0.20, 0.5, "right", 0.6), "flick width: wrong direction does not count")
	var n: NoteData = ChartLoader._parse_note({"type": "flick", "time": 0, "x": 0.5, "dir": "left"})
	_check(is_equal_approx(n.width, GameConst.FLICK_DEFAULT_WIDTH), "flick without width uses the default")
	n = ChartLoader._parse_note({"type": "flick", "time": 0, "x": 0.5, "dir": "left", "width": 0.3})
	_check(is_equal_approx(n.width, 0.3), "flick width is read")
	n = ChartLoader._parse_note({"type": "flick", "time": 0, "x": 0.5, "dir": "left", "width": 0.0})
	_check(is_equal_approx(n.width, GameConst.FLICK_MIN_WIDTH), "flick width is clamped")
	# 스카이 알림: 모든 Flick 을 방향(LEFT/RIGHT)으로 알린다. Field 는 알리지 않는다
	var mk_flick := func(time: float, dir: String) -> NoteData:
		var an := NoteData.new()
		an.type = NoteData.Type.FLICK
		an.time = time
		an.end_time = time
		an.dir = dir
		return an
	var mk_field := func(t0: float, t1: float, center: float) -> NoteData:
		var an := NoteData.new()
		an.type = NoteData.Type.FIELD
		an.keys = [{"time": t0, "center": center, "width": 0.3}, {"time": t1, "center": 0.5, "width": 0.3}]
		an.time = t0
		an.end_time = t1
		return an
	var alert := AirAlert.new()
	alert.setup([NoteData.make_tap(1000.0, 0), mk_flick.call(5000.0, "left"), mk_flick.call(6000.0, "right"),
		mk_field.call(10000.0, 12000.0, 0.7), mk_field.call(12300.0, 13000.0, 0.5), mk_field.call(14000.0, 15000.0, 0.5),
		mk_flick.call(14500.0, "right")])
	_check(alert.entry_times() == [5000.0, 6000.0, 14500.0], "air alert: every flick, no fields")
	_check(alert.sample(3000.0) == Vector4.ZERO and alert.sample(6001.0) == Vector4.ZERO, "air alert is off outside the lead-in")
	var mid: Vector4 = alert.sample(5000.0 - AirAlert.LEAD_MS * 0.5)
	_check(mid.y == 1.0 and mid.w == 0.0, "left flick -> LEFT panel only")
	_check(alert.sample(5000.0 - AirAlert.LEAD_MS * 0.9).x > mid.x and mid.x > alert.sample(5000.0 - AirAlert.LEAD_MS * 0.1).x, "air alert flashes once, then settles")
	mid = alert.sample(6000.0 - AirAlert.LEAD_MS * 0.5)
	_check(mid.y == 0.0 and mid.w == 1.0, "right flick -> RIGHT panel only")
	_check(alert.sample(10000.0 - AirAlert.LEAD_MS * 0.5) == Vector4.ZERO and alert.sample(12300.0 - AirAlert.LEAD_MS * 0.5) == Vector4.ZERO, "fields do not raise the alert")

func test_chart_summary() -> void:
	var tm := TimingMap.new([{"time": 0, "bpm": 120}, {"time": 1000, "bpm": 60}])
	_check(is_equal_approx(tm.beat_at(500.0), 1.0), "beat_at first segment")
	_check(is_equal_approx(tm.beat_at(2000.0), 3.0), "beat_at across bpm change")
	_check(is_equal_approx(tm.beat_at(-500.0), -1.0), "beat_at extrapolates before start")
	var chart: ChartData = ChartLoader.load_chart("res://charts/sample/nm.json")
	var judge := Judge.new()
	judge.setup(chart)
	_check(chart.total_judgements() == judge.total_judgements, "chart total matches judge total")
	judge.free()
	_check(chart.difficulty == "NM", "difficulty name comes from the file slot")
	var list: Array = ChartLoader.list_songs()
	_check(not list.is_empty() and (list[0]["diffs"] as Array).size() == 3, "list_songs has 3 difficulty slots")
	var nm: Dictionary = list[0]["diffs"][1]
	_check(int(nm["total"]) == chart.total_judgements(), "list_songs total")
	var d: PackedFloat32Array = nm["density"]
	_check(d.size() == 64 and Array(d).max() == 1.0, "density normalized")
	_check(ChartLoader.nearest_diff([{}, {"a": 1}, {"a": 1}], 0) == 1, "nearest_diff skips empty slot")
	_check(ChartLoader.nearest_diff([{"a": 1}, {}, {"a": 1}], 1) == 0, "nearest_diff tie -> easier")
	_check(ChartLoader.nearest_diff([{}, {}, {}], 1) == -1, "nearest_diff none -> -1")
	_check(ChartLoader.diff_of_path("res://charts/x/hd.json") == 2, "diff_of_path")
	# 튜토리얼: 선곡 목록에는 없고, 채보와 안내 문구는 읽힌다
	var listed: bool = false
	for s: Dictionary in list:
		listed = listed or String(s["dir"]).ends_with("/" + ChartLoader.TUTORIAL_DIR)
	_check(not listed, "tutorial is hidden from list_songs")
	var tut: ChartData = ChartLoader.load_chart(ChartLoader.TUTORIAL_CHART)
	_check(tut != null and tut.notes.size() > 0 and tut.end_time_ms() <= 40000.0, "tutorial chart loads (about 40s)")
	var guides: Array[Dictionary] = ChartLoader.load_guides("res://charts/tutorial")
	_check(guides.size() >= 4, "tutorial guides load")
	_check(ChartLoader.guide_at(guides, 5000.0, false).contains("A S D F"), "guide_at picks the active text")
	_check(ChartLoader.guide_at(guides, 25000.0, true) != ChartLoader.guide_at(guides, 25000.0, false), "guide_at controller variant")
	_check(ChartLoader.focus_at(guides, 5000.0) == "keys" and ChartLoader.focus_at(guides, 25000.0) == "air" and ChartLoader.focus_at(guides, -1000.0) == "", "focus_at picks the control to highlight")
	_check(ChartLoader.guide_at(guides, -1000.0, false) == "" and ChartLoader.load_guides("res://charts/sample").is_empty(), "no guide outside ranges / without guide.json")
	# 오디오 4초 중 채보 2초 구간만 쓰고, 그 구간 최댓값을 1로 맞춘다
	var w: PackedFloat32Array = ChartLoader.resample_peaks(PackedFloat32Array([0.5, 0.25, 1.0, 1.0]), 4000.0, 2000.0, 2)
	_check(w.size() == 2 and is_equal_approx(w[0], 1.0) and is_equal_approx(w[1], 0.5), "waveform crops to chart length")
	# 오디오가 채보보다 짧으면 뒤쪽은 0
	w = ChartLoader.resample_peaks(PackedFloat32Array([1.0, 1.0]), 1000.0, 2000.0, 2)
	_check(is_equal_approx(w[0], 1.0) and w[1] == 0.0, "waveform pads past audio end")
	_check(ChartLoader.load_waveform("res://charts/no_such_song", 1000.0).is_empty(), "missing waveform -> empty")
	w = ChartLoader.envelope(PackedFloat32Array([1.0, 0.0, 0.8]), 0.5)
	_check(is_equal_approx(w[1], 0.5) and is_equal_approx(w[2], 0.8), "envelope decays after peak, keeps higher value")
