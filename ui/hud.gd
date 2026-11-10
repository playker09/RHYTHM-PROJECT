class_name Hud
extends CanvasLayer
## 플레이 HUD: 진행 선, 점수/정확도, 곡 정보, 판정 수, 콤보, 판정 글자, 타이밍 오차 막대, 카운트다운.
## 패널 없이 3D 위에 글자만 올린다. 보이는 숫자는 전부 ScoreManager/채보의 실제 값이다.

signal result_action(action: String)    # "retry" | "quit"

const COMBO_SIZE := Vector2(360.0, 150.0)
const JUDGE_SIZE := Vector2(520.0, 96.0)
const COUNT_SIZE := Vector2(400.0, 240.0)

var _root: Control
var _score_lead: Label
var _score: Label
var _rate: Label
var _counts: Array[Label] = []
var _combo_box: Control
var _combo: Label
var _judge_box: Control
var _judge: Label
var _judge_sub: Label
var _speed: Label
var _progress: _ProgressLine
var _time: Label
var _jacket: Jacket
var _title: Label
var _artist: Label
var _chip_slot: HBoxContainer
var _intro: Control
var _count_box: Control
var _count: Label
var _count_ring: _CountRing
var _meter: _ErrorMeter
var _banner: Control
var _result: ResultScreen
var _song: Dictionary = {}
var _judge_time: float = 0.0
var _speed_flash: float = 0.0
var _combo_punch: float = 0.0
var _judge_punch: float = 0.0
var _shown_score: float = 0.0
var _count_shown: int = -1
var _score_mgr: ScoreManager

func _ready() -> void:
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.place(_root, 0.0, 0.0, 1.0, 1.0)
	add_child(_root)
	_progress = _ProgressLine.new()
	Ui.place(_progress, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 4.0)
	_root.add_child(_progress)
	_build_score()
	_build_song()
	_build_counts()
	_build_center()
	_build_intro()
	_build_countdown()
	_speed = Ui.caption("", Ui.TEXT_3, 13)
	Ui.place(_speed, 0.0, 1.0, 0.0, 1.0, 32.0, -42.0, 300.0, -18.0)
	_root.add_child(_speed)
	set_speed(Settings.hispeed)
	_speed_flash = 0.0

func bind(score_mgr: ScoreManager, judge: Judge) -> void:
	_score_mgr = score_mgr
	score_mgr.changed.connect(_refresh)
	judge.judged.connect(_on_judged)

## song = {title, artist, level, diff(슬롯 번호), jacket(경로)}
func set_song(song: Dictionary) -> void:
	_song = song
	_title.text = String(song["title"])
	_artist.text = String(song["artist"])
	_jacket.set_song(String(song["title"]), String(song.get("jacket", "")))
	var slot: int = int(song.get("diff", -1))
	if slot >= 0:
		_chip_slot.add_child(Ui.diff_chip(slot, int(song.get("level", 0)), false, 13))
	_fill_intro()

## 콤보 숫자를 이 화면 지점(일식 원반 중심)에 놓는다.
func set_combo_anchor(center: Vector2) -> void:
	_combo_box.position = center - COMBO_SIZE * 0.5 + Vector2(0.0, 6.0)

## 판정 글자를 화면의 이 지점(픽셀)을 중심으로 표시한다.
func set_judge_anchor(center: Vector2) -> void:
	_judge_box.position = center - JUDGE_SIZE * 0.5

## 곡 진행도 0~1 과 현재/전체 시각
func set_progress(now_ms: float, end_ms: float) -> void:
	_progress.value = clampf(now_ms / maxf(end_ms, 1.0), 0.0, 1.0)
	_time.text = "%s / %s" % [Ui.fmt_time(clampf(now_ms, 0.0, end_ms)), Ui.fmt_time(end_ms)]

func set_speed(v: float) -> void:
	_speed.text = "SPEED  %.1f" % v
	_speed_flash = 1.0

## 곡 시작 전 카운트다운. now_ms < 0 인 동안 3·2·1, 0 을 지나면 GO 를 잠깐 보여 준다.
func set_countdown(now_ms: float) -> void:
	var n: int = ceili(-now_ms / 1000.0) if now_ms < 0.0 else 0
	if now_ms > 700.0:
		if _count_box.visible:
			_count_box.visible = false
		return
	if n != _count_shown:
		_count_shown = n
		_count_box.visible = true
		_count.text = str(n) if n > 0 else "GO"
		Ui.set_color(_count, Ui.TEXT if n > 0 else Ui.CYAN)
		_count_box.scale = Vector2.ONE * 1.35
		_count_box.modulate.a = 1.0
		App.sfx("count" if n > 0 else "go", 0.45)
		if n == 0:
			var tw := create_tween()
			tw.tween_property(_intro, "modulate:a", 0.0, 0.35)
	_count_ring.value = fposmod(-now_ms, 1000.0) / 1000.0 if n > 0 else 0.0
	if n == 0:
		_count_box.modulate.a = clampf(1.0 - now_ms / 600.0, 0.0, 1.0)

## 곡이 끝났을 때 잠깐 띄우는 문구 (FULL COMBO 등)
func show_banner(text: String, color: Color) -> void:
	_banner = Control.new()
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.place(_banner, 0.0, 0.5, 1.0, 0.5, 0.0, -70.0, 0.0, 30.0)
	_root.add_child(_banner)
	var line := ColorRect.new()
	line.color = Color(color, 0.9)
	Ui.place(line, 0.5, 1.0, 0.5, 1.0, -230.0, -2.0, 230.0, 0.0)
	_banner.add_child(line)
	var l := Ui.d(text, 62, Ui.TEXT, 700, 10, true)
	Ui.gradient(l, Ui.TEXT, color, 80.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Ui.place(l, 0.0, 0.0, 1.0, 1.0)
	_banner.add_child(l)
	_banner.pivot_offset = Vector2(get_viewport().get_visible_rect().size.x * 0.5, 50.0)
	_banner.scale = Vector2(1.5, 1.5)
	_banner.modulate.a = 0.0
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.tween_property(_banner, "scale", Vector2.ONE, 0.5)
	tw.tween_property(_banner, "modulate:a", 1.0, 0.25)
	App.sfx("clear", 0.5)

func _process(delta: float) -> void:
	if _score_mgr != null:
		_shown_score = lerpf(_shown_score, float(_score_mgr.score), 1.0 - exp(-delta * 18.0))
		var parts: PackedStringArray = Ui.fmt_score7(roundi(_shown_score))
		_score_lead.text = parts[0]
		_score.text = parts[1]
	if _judge_time > 0.0:
		_judge_time -= delta
		_judge_box.modulate.a = clampf(_judge_time / 0.14, 0.0, 1.0)
		_judge_punch = lerpf(_judge_punch, 0.0, 1.0 - exp(-delta * 22.0))
		_judge_box.scale = Vector2.ONE * (1.0 + _judge_punch)
	_combo_punch = lerpf(_combo_punch, 0.0, 1.0 - exp(-delta * 18.0))
	_combo_box.scale = Vector2.ONE * (1.0 + _combo_punch)
	_count_box.scale = _count_box.scale.lerp(Vector2.ONE, 1.0 - exp(-delta * 14.0))
	_speed_flash = maxf(_speed_flash - delta * 0.8, 0.0)
	Ui.set_color(_speed, Ui.TEXT_3.lerp(Ui.CYAN, _speed_flash))

func _refresh() -> void:
	var c: int = _score_mgr.combo
	_rate.text = "%.2f%%" % _score_mgr.accuracy()
	for i in 3:
		_counts[i].text = str(_score_mgr.counts[i])
	if c > 1:
		if _combo.text != str(c):
			_combo_punch = 0.12
		_combo.text = str(c)
		_combo_box.visible = true
	else:
		_combo.text = ""
		_combo_box.visible = false

func _on_judged(_note: NoteData, grade: int, delta_ms: float, is_tick: bool) -> void:
	if not is_tick and grade != JudgeLogic.Grade.MISS:
		_meter.push(delta_ms, Ui.GRADE_COLORS[grade])
	if is_tick and grade != JudgeLogic.Grade.MISS:
		return
	var col: Color = Ui.GRADE_COLORS[grade]
	_judge.text = JudgeLogic.grade_name(grade)
	Ui.set_color(_judge, col.lerp(Color.WHITE, 0.35))
	Ui.glow(_judge, col, 10, 0.16)
	_judge_sub.text = ""
	if grade == JudgeLogic.Grade.GREAT:
		_judge_sub.text = "FAST  %d" % roundi(delta_ms) if delta_ms < 0.0 else "SLOW  +%d" % roundi(delta_ms)
		Ui.set_color(_judge_sub, Ui.VIOLET.lerp(Color.WHITE, 0.4) if delta_ms < 0.0 else Ui.MAGENTA.lerp(Color.WHITE, 0.4))
	_judge_time = 0.45
	_judge_punch = 0.2 if not is_tick else 0.0
	_judge_box.modulate.a = 1.0

# --- 결과 화면 ---
func show_result(score_mgr: ScoreManager, new_record: bool = false, best: Dictionary = {}) -> void:
	hide_result()
	create_tween().tween_property(_root, "modulate:a", 0.0, 0.3)
	_result = ResultScreen.new()
	add_child(_result)
	_result.build(score_mgr, _song, new_record, best)
	_result.action.connect(func(id: String): result_action.emit(id))

func hide_result() -> void:
	if _result != null:
		_result.queue_free()
		_result = null

func is_result_open() -> bool:
	return _result != null

# --- 빌더 ---
func _build_score() -> void:
	var shade := _CornerShade.new()
	Ui.place(shade, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 520.0, 150.0)
	_root.add_child(shade)
	var v := Ui.vbox(-6)
	Ui.place(v, 0.0, 0.0, 0.0, 0.0, 32.0, 20.0, 460.0, 130.0)
	_root.add_child(v)
	v.add_child(Ui.caption("SCORE"))
	var row := Ui.hbox(0)
	v.add_child(row)
	_score_lead = Ui.d("000000", 50, Color(1, 1, 1, 0.22), 600, 1, true)
	row.add_child(_score_lead)
	_score = Ui.d("0", 50, Ui.TEXT, 600, 1, true)
	Ui.shadow(_score, 0.5, 6)
	row.add_child(_score)
	var sub := Ui.hbox(10)
	v.add_child(sub)
	_rate = Ui.d("0.00%", 18, Ui.CYAN, 600, 1)
	sub.add_child(_rate)

func _build_song() -> void:
	var shade := _CornerShade.new()
	shade.flip = true
	Ui.place(shade, 1.0, 0.0, 1.0, 0.0, -520.0, 0.0, 0.0, 150.0)
	_root.add_child(shade)
	var h := Ui.hbox(14)
	Ui.place(h, 1.0, 0.0, 1.0, 0.0, -560.0, 24.0, -32.0, 96.0)
	h.alignment = BoxContainer.ALIGNMENT_END
	_root.add_child(h)
	var v := Ui.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	_title = Ui.d("", 22, Ui.TEXT, 600)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_title.clip_text = true
	v.add_child(_title)
	_artist = Ui.t("", 13, Ui.TEXT_2)
	_artist.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_artist.clip_text = true
	v.add_child(_artist)
	v.add_child(Ui.gap(3.0))
	_chip_slot = Ui.hbox(10)
	_chip_slot.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(_chip_slot)
	_time = Ui.d("", 13, Ui.TEXT_3, 500, 1)
	_time.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_chip_slot.add_child(_time)
	var frame := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Color(1, 1, 1, 0.35)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(3.0)
	frame.add_theme_stylebox_override("panel", sb)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(frame)
	_jacket = Jacket.new()
	_jacket.custom_minimum_size = Vector2(66.0, 66.0)
	frame.add_child(_jacket)

## 오른쪽 아래: 지금까지의 판정 수
func _build_counts() -> void:
	var v := Ui.vbox(0)
	Ui.place(v, 1.0, 1.0, 1.0, 1.0, -210.0, -98.0, -32.0, -16.0)
	v.alignment = BoxContainer.ALIGNMENT_END
	_root.add_child(v)
	for i in 3:
		var row := Ui.hbox(10)
		row.alignment = BoxContainer.ALIGNMENT_END
		v.add_child(row)
		row.add_child(Ui.caption(JudgeLogic.grade_name(i), Color(Ui.GRADE_COLORS[i], 0.85), 12))
		var n := Ui.d("0", 17, Ui.TEXT, 600, 1)
		n.custom_minimum_size = Vector2(46.0, 0.0)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(n)
		_counts.append(n)
	_meter = _ErrorMeter.new()
	Ui.place(_meter, 0.5, 1.0, 0.5, 1.0, -170.0, -30.0, 170.0, -10.0)
	_root.add_child(_meter)

func _build_center() -> void:
	_combo_box = Control.new()
	_combo_box.size = COMBO_SIZE
	_combo_box.pivot_offset = COMBO_SIZE * 0.5
	_combo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo_box.visible = false
	_root.add_child(_combo_box)
	_combo = Ui.d("", 74, Color(1, 1, 1, 0.96), 600, 0, true)
	Ui.glow(_combo, Ui.VIOLET, 18, 0.2)
	_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Ui.place(_combo, 0.0, 0.0, 1.0, 0.0, 0.0, 8.0, 0.0, 100.0)
	_combo_box.add_child(_combo)
	var cap := Ui.caption("COMBO", Color(1, 1, 1, 0.7), 12)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Ui.place(cap, 0.0, 0.0, 1.0, 0.0, 0.0, 96.0, 0.0, 116.0)
	_combo_box.add_child(cap)

	_judge_box = Control.new()
	_judge_box.size = JUDGE_SIZE
	_judge_box.pivot_offset = JUDGE_SIZE * 0.5
	_judge_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_judge_box.modulate.a = 0.0
	_root.add_child(_judge_box)
	_judge = Ui.d("", 40, Ui.TEXT, 700, 8, true)
	_judge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Ui.place(_judge, 0.0, 0.0, 1.0, 0.0, 0.0, 10.0, 0.0, 64.0)
	_judge_box.add_child(_judge)
	_judge_sub = Ui.d("", 14, Ui.TEXT_2, 600, 3)
	Ui.shadow(_judge_sub, 0.6, 6)
	_judge_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Ui.place(_judge_sub, 0.0, 0.0, 1.0, 0.0, 0.0, 62.0, 0.0, 86.0)
	_judge_box.add_child(_judge_sub)

## 곡 시작 전 화면 가운데 위에 보이는 곡 카드
func _build_intro() -> void:
	_intro = Ui.vbox(2)
	Ui.place(_intro, 0.0, 0.5, 1.0, 0.5, 0.0, -250.0, 0.0, -120.0)
	_root.add_child(_intro)

func _fill_intro() -> void:
	var cap := Ui.caption("NOW PLAYING", Ui.TEXT_2, 13)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro.add_child(cap)
	var t := Ui.d(String(_song["title"]), 52, Ui.TEXT, 700)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Ui.shadow(t, 0.6, 12)
	_intro.add_child(t)
	var a := Ui.t(String(_song["artist"]), 17, Ui.TEXT_2)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro.add_child(a)
	Ui.reveal(_intro, 0.15, 0.4)

func _build_countdown() -> void:
	_count_box = Control.new()
	_count_box.size = COUNT_SIZE
	_count_box.pivot_offset = COUNT_SIZE * 0.5
	_count_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count_box.visible = false
	Ui.place(_count_box, 0.5, 0.5, 0.5, 0.5, -COUNT_SIZE.x * 0.5, -COUNT_SIZE.y * 0.5 + 10.0, COUNT_SIZE.x * 0.5, COUNT_SIZE.y * 0.5 + 10.0)
	_root.add_child(_count_box)
	_count_ring = _CountRing.new()
	Ui.place(_count_ring, 0.0, 0.0, 1.0, 1.0)
	_count_box.add_child(_count_ring)
	_count = Ui.d("", 110, Ui.TEXT, 600, 0, true)
	Ui.glow(_count, Ui.VIOLET, 22, 0.25)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Ui.place(_count, 0.0, 0.0, 1.0, 1.0)
	_count_box.add_child(_count)

## 화면 맨 위 진행 선
class _ProgressLine extends Control:
	var value: float = 0.0:
		set(v):
			value = v
			queue_redraw()
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_rect(Rect2(0.0, 0.0, size.x, 2.0), Color(1, 1, 1, 0.1))
		var w: float = size.x * value
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0.0), Vector2(w, 2.0), Vector2(0.0, 2.0)]),
			PackedColorArray([Ui.VIOLET, Ui.MAGENTA, Ui.MAGENTA, Ui.VIOLET]))
		# 머리 표시
		draw_rect(Rect2(w - 1.5, 0.0, 3.0, size.y), Ui.TEXT)

## 글자 뒤 구석을 살짝 어둡게 (패널 대신)
class _CornerShade extends Control:
	var flip: bool = false
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var strong := Color(0.02, 0.015, 0.05, 0.66)
		var clear := Color(0.02, 0.015, 0.05, 0.0)
		var a: Color = clear if flip else strong
		var b: Color = strong if flip else clear
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)]),
			PackedColorArray([a, b, clear, clear]))

## 카운트다운 숫자를 둘러싼 고리. value 1 -> 0 으로 줄어든다.
class _CountRing extends Control:
	var value: float = 0.0:
		set(v):
			value = v
			queue_redraw()
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.5 - 14.0
		draw_arc(c, r, 0.0, TAU, 96, Color(1, 1, 1, 0.1), 1.5, true)
		if value > 0.0:
			draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * value, 96, Ui.VIOLET.lerp(Ui.MAGENTA, 1.0 - value), 3.0, true)

## 타이밍 오차 막대: 가운데 = 정확, 왼쪽 = 빠름, 오른쪽 = 느림. 최근 타격이 눈금으로 남았다 사라진다.
class _ErrorMeter extends Control:
	const KEEP := 24
	const LIFE := 2.4
	var _hits: Array[Vector3] = []       # (delta_ms, 남은 시간, 등급 색 인덱스)
	var _colors: Array[Color] = []
	var _avg: float = 0.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func push(delta_ms: float, color: Color) -> void:
		_hits.append(Vector3(delta_ms, LIFE, 0.0))
		_colors.append(color)
		if _hits.size() > KEEP:
			_hits.pop_front()
			_colors.pop_front()
		_avg = lerpf(_avg, delta_ms, 0.25)
	func _process(delta: float) -> void:
		for i in _hits.size():
			_hits[i].y = maxf(_hits[i].y - delta, 0.0)
		queue_redraw()
	func _draw() -> void:
		var mid: float = size.x * 0.5
		var cy: float = size.y * 0.5
		var span: float = GameConst.GREAT_MS
		var px: float = (size.x * 0.5) / span
		# 구간 바탕: GREAT 폭 전체, PERFECT 폭은 조금 더 밝게
		draw_rect(Rect2(0.0, cy - 1.0, size.x, 2.0), Color(1, 1, 1, 0.12))
		var pw: float = GameConst.PERFECT_MS * px
		draw_rect(Rect2(mid - pw, cy - 1.0, pw * 2.0, 2.0), Color(Ui.GOLD, 0.4))
		draw_rect(Rect2(mid - 0.75, cy - 8.0, 1.5, 16.0), Color(1, 1, 1, 0.7))
		for i in _hits.size():
			var h: Vector3 = _hits[i]
			if h.y <= 0.0:
				continue
			var x: float = mid + clampf(h.x, -span, span) * px
			draw_rect(Rect2(x - 1.0, cy - 6.0, 2.0, 12.0), Color(_colors[i], clampf(h.y / LIFE, 0.0, 1.0) * 0.9))
		# 최근 평균 위치
		var ax: float = mid + clampf(_avg, -span, span) * px
		draw_colored_polygon(PackedVector2Array([Vector2(ax - 4.0, cy - 10.0), Vector2(ax + 4.0, cy - 10.0), Vector2(ax, cy - 5.0)]), Ui.TEXT)
