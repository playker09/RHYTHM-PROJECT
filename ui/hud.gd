class_name Hud
extends CanvasLayer
## 플레이 HUD: 진행 바, 점수, 곡 정보, 콤보, 판정 표시. 패널 없이 3D 위에 글자만 올린다.

signal result_action(action: String)    # "retry" | "quit"

const COMBO_SIZE := Vector2(500.0, 150.0)
const JUDGE_SIZE := Vector2(500.0, 90.0)

var _score: Label
var _rate: Label
var _combo_box: Control
var _combo: Label
var _judge_box: Control
var _judge: Label
var _judge_sub: Label
var _speed: Label
var _progress: _ProgressLine
var _jacket: Jacket
var _title: Label
var _artist: Label
var _chip_slot: HBoxContainer
var _intro: Control
var _result: ResultScreen
var _song: Dictionary = {}
var _judge_time: float = 0.0
var _speed_flash: float = 0.0
var _combo_punch: float = 0.0
var _judge_punch: float = 0.0
var _shown_score: float = 0.0
var _score_mgr: ScoreManager

func _ready() -> void:
	_progress = _ProgressLine.new()
	Ui.place(_progress, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 3.0)
	add_child(_progress)
	_build_score()
	_build_song()
	_build_center()
	_build_intro()
	_speed = Ui.d("", 15, Ui.TEXT_3, 500, 1)
	Ui.place(_speed, 0.0, 1.0, 0.0, 1.0, 28.0, -36.0, 300.0, -10.0)
	add_child(_speed)
	set_speed(Settings.hispeed)
	_speed_flash = 0.0

func bind(score_mgr: ScoreManager, judge: Judge) -> void:
	_score_mgr = score_mgr
	score_mgr.changed.connect(_refresh)
	judge.judged.connect(_on_judged)

func set_song(title: String, artist: String, level: int = 0, difficulty: String = "") -> void:
	_song = {"title": title, "artist": artist}
	_title.text = title
	_artist.text = artist
	_jacket.set_song(title)
	if difficulty != "":
		_chip_slot.add_child(Ui.chip("%s  %d" % [difficulty, level] if level > 0 else difficulty, Ui.TEXT, false))
	_play_intro(title, artist)

## 콤보 숫자를 이 화면 지점에 놓는다.
func set_combo_anchor(center: Vector2) -> void:
	_combo_box.position = center - COMBO_SIZE * 0.5

## 곡 진행도 0~1
func set_progress(p: float) -> void:
	_progress.value = clampf(p, 0.0, 1.0)

## 판정 텍스트를 화면의 이 지점(픽셀)을 중심으로 표시한다.
func set_judge_anchor(center: Vector2) -> void:
	_judge_box.position = center - JUDGE_SIZE * 0.5

func set_speed(v: float) -> void:
	_speed.text = "SPEED  %.1f" % v
	_speed_flash = 1.0

func _process(delta: float) -> void:
	if _score_mgr != null:
		_shown_score = lerpf(_shown_score, float(_score_mgr.score), 1.0 - exp(-delta * 18.0))
		_score.text = fmt_score(roundi(_shown_score))
	if _judge_time > 0.0:
		_judge_time -= delta
		_judge_box.modulate.a = clampf(_judge_time / 0.14, 0.0, 1.0)
		_judge_punch = lerpf(_judge_punch, 0.0, 1.0 - exp(-delta * 20.0))
		_judge_box.scale = Vector2.ONE * (1.0 + _judge_punch)
	_combo_punch = lerpf(_combo_punch, 0.0, 1.0 - exp(-delta * 18.0))
	_combo_box.scale = Vector2.ONE * (1.0 + _combo_punch)
	_speed_flash = maxf(_speed_flash - delta * 0.8, 0.0)
	Ui.set_color(_speed, Ui.TEXT_3.lerp(Ui.CYAN, _speed_flash))

func _refresh() -> void:
	var c: int = _score_mgr.combo
	_rate.text = "%.2f%%" % _score_mgr.accuracy()
	if c > 1:
		if _combo.text != str(c):
			_combo_punch = 0.11
		_combo.text = str(c)
		_combo_box.visible = true
	else:
		_combo.text = ""
		_combo_box.visible = false

func _on_judged(_note: NoteData, grade: int, delta_ms: float, is_tick: bool) -> void:
	if is_tick and grade != JudgeLogic.Grade.MISS:
		return
	_judge.text = JudgeLogic.grade_name(grade)
	Ui.set_color(_judge, Ui.GRADE_COLORS[grade])
	_judge.add_theme_color_override("font_outline_color", Color(Ui.GRADE_COLORS[grade], 0.25))
	_judge_sub.text = ""
	if grade == JudgeLogic.Grade.GREAT:
		_judge_sub.text = "FAST  %d" % roundi(delta_ms) if delta_ms < 0.0 else "SLOW  +%d" % roundi(delta_ms)
	_judge_time = 0.42
	_judge_punch = 0.16 if not is_tick else 0.0
	_judge_box.modulate.a = 1.0

# --- 결과 화면 ---
func show_result(score_mgr: ScoreManager, new_record: bool = false) -> void:
	hide_result()
	_result = ResultScreen.new()
	add_child(_result)
	_result.build(score_mgr, _song, new_record)
	_result.action.connect(func(id: String): result_action.emit(id))

func hide_result() -> void:
	if _result != null:
		_result.queue_free()
		_result = null

func is_result_open() -> bool:
	return _result != null

static func fmt_score(n: int) -> String:
	return Ui.fmt_int(n)

# --- 빌더 ---
func _build_score() -> void:
	var shade := _CornerShade.new()
	Ui.place(shade, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 460.0, 130.0)
	add_child(shade)
	var v := Ui.vbox(0)
	Ui.place(v, 0.0, 0.0, 0.0, 0.0, 28.0, 18.0, 420.0, 120.0)
	add_child(v)
	_score = Ui.d("0", 52, Ui.TEXT, 700)
	v.add_child(_score)
	var row := Ui.hbox(12)
	v.add_child(row)
	_rate = Ui.d("0.00%", 19, Ui.CYAN, 600)
	row.add_child(_rate)

func _build_song() -> void:
	var shade := _CornerShade.new()
	shade.flip = true
	Ui.place(shade, 1.0, 0.0, 1.0, 0.0, -460.0, 0.0, 0.0, 130.0)
	add_child(shade)
	var h := Ui.hbox(14)
	Ui.place(h, 1.0, 0.0, 1.0, 0.0, -520.0, 22.0, -28.0, 94.0)
	h.alignment = BoxContainer.ALIGNMENT_END
	add_child(h)
	var v := Ui.vbox(1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	_title = Ui.d("", 24, Ui.TEXT, 600)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_title.clip_text = true
	v.add_child(_title)
	_artist = Ui.t("", 14, Ui.TEXT_2)
	_artist.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_artist.clip_text = true
	v.add_child(_artist)
	_chip_slot = Ui.hbox(0)
	_chip_slot.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(_chip_slot)
	_jacket = Jacket.new()
	_jacket.custom_minimum_size = Vector2(72.0, 72.0)
	h.add_child(_jacket)

func _build_center() -> void:
	_combo_box = Control.new()
	_combo_box.size = COMBO_SIZE
	_combo_box.pivot_offset = COMBO_SIZE * 0.5
	_combo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo_box.visible = false
	add_child(_combo_box)
	_combo = Ui.d("", 92, Color(1, 1, 1, 0.92), 700, 0, true)
	_combo.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.1, 0.55))
	_combo.add_theme_constant_override("outline_size", 10)
	_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Ui.place(_combo, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 118.0)
	_combo_box.add_child(_combo)
	var cap := Ui.d("COMBO", 15, Color(1, 1, 1, 0.75), 600, 5)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Ui.place(cap, 0.0, 0.0, 1.0, 0.0, 0.0, 112.0, 0.0, 136.0)
	_combo_box.add_child(cap)

	_judge_box = Control.new()
	_judge_box.size = JUDGE_SIZE
	_judge_box.pivot_offset = JUDGE_SIZE * 0.5
	_judge_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_judge_box.modulate.a = 0.0
	add_child(_judge_box)
	_judge = Ui.d("", 38, Ui.TEXT, 700, 6)
	_judge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_judge.add_theme_constant_override("outline_size", 12)
	Ui.place(_judge, 0.0, 0.0, 1.0, 0.0, 0.0, 12.0, 0.0, 62.0)
	_judge_box.add_child(_judge)
	_judge_sub = Ui.d("", 15, Ui.TEXT_2, 600, 2)
	_judge_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Ui.place(_judge_sub, 0.0, 0.0, 1.0, 0.0, 0.0, 60.0, 0.0, 84.0)
	_judge_box.add_child(_judge_sub)

func _build_intro() -> void:
	_intro = Ui.vbox(4)
	Ui.place(_intro, 0.0, 0.5, 1.0, 0.5, 0.0, -130.0, 0.0, -30.0)
	_intro.modulate.a = 0.0
	add_child(_intro)

## 곡 시작 직후 잠깐 보이는 곡 이름 카드
func _play_intro(title: String, artist: String) -> void:
	var t := Ui.d(title, 54, Ui.TEXT, 700)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.1, 0.6))
	t.add_theme_constant_override("outline_size", 12)
	_intro.add_child(t)
	var a := Ui.t(artist, 18, Ui.TEXT_2)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro.add_child(a)
	var tw := create_tween()
	tw.tween_property(_intro, "modulate:a", 1.0, 0.3).set_delay(0.15)
	tw.tween_interval(1.1)
	tw.tween_property(_intro, "modulate:a", 0.0, 0.4)

## 화면 맨 위 진행 선
class _ProgressLine extends Control:
	var value: float = 0.0:
		set(v):
			value = v
			queue_redraw()
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.1))
		var w: float = size.x * value
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0.0), Vector2(w, size.y), Vector2(0.0, size.y)]),
			PackedColorArray([Ui.VIOLET, Ui.MAGENTA, Ui.MAGENTA, Ui.VIOLET]))

## 글자 뒤 구석을 살짝 어둡게 (패널 대신)
class _CornerShade extends Control:
	var flip: bool = false
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var strong := Color(0.02, 0.015, 0.05, 0.62)
		var clear := Color(0.02, 0.015, 0.05, 0.0)
		var a: Color = clear if flip else strong
		var b: Color = strong if flip else clear
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)]),
			PackedColorArray([a, b, clear, clear]))
