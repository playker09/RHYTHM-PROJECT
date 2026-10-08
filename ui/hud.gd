class_name Hud
extends CanvasLayer

signal result_action(action: String)    # "retry" | "settings" | "quit"

const GRADE_COLORS := [Color(1.0, 0.9, 0.4), Color(0.4, 0.9, 1.0), Color(1.0, 0.35, 0.35)]
const RANK_COLORS := {
	"AP": Color(1.0, 0.85, 0.3), "S": Color(1.0, 0.85, 0.3), "A": Color(0.4, 0.95, 0.85),
	"B": Color(0.5, 0.7, 1.0), "C": Color(0.8, 0.6, 1.0), "D": Color(0.7, 0.7, 0.7)}

var _score: Label
var _combo: Label
var _judge: Label
var _speed: Label
var _title: Label
var _artist: Label
var _progress: ProgressBar
var _rate: Label
var _jacket: ColorRect
var _jacket_letter: Label
var _level_chip: Label
var _result: Control
var _judge_timer: float = 0.0
var _score_mgr: ScoreManager

func _ready() -> void:
	_build_score_panel()
	_build_song_panel()
	_combo = _make_label(150, Control.PRESET_TOP_WIDE, 0.0)
	_combo.modulate = Color(0.85, 0.95, 1.0, 0.2)
	_combo.add_theme_constant_override("outline_size", 0)
	_judge = _make_label(44, Control.PRESET_TOP_WIDE, 0.0)
	_judge.add_theme_constant_override("outline_size", 12)
	_judge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_speed = _make_label(20, Control.PRESET_BOTTOM_LEFT, 0.0)
	_speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_speed.offset_left = 16.0
	_speed.offset_top = -36.0
	_speed.offset_bottom = -8.0
	_speed.modulate = Color(1, 1, 1, 0.7)
	_score.text = fmt_score(0)
	set_speed(Settings.hispeed)

func bind(score_mgr: ScoreManager, judge: Judge) -> void:
	_score_mgr = score_mgr
	score_mgr.changed.connect(_refresh)
	judge.judged.connect(_on_judged)

func set_song(title: String, artist: String, level: int = 0, difficulty: String = "") -> void:
	_title.text = title
	_artist.text = artist
	_level_chip.text = "%s  Lv %d" % [difficulty, level] if level > 0 else difficulty
	_jacket.color = Color.from_hsv(float(title.hash() % 360) / 360.0, 0.55, 0.6)
	_jacket_letter.text = title.substr(0, 1).to_upper()

## 큰 콤보 숫자(배경처럼 깔리는 연한 숫자)를 이 화면 지점에 놓는다.
func set_combo_anchor(center: Vector2) -> void:
	var sz := Vector2(700.0, 200.0)
	_combo.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_combo.position = center - sz * 0.5
	_combo.size = sz
	_combo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

## 곡 진행도 0~1
func set_progress(p: float) -> void:
	_progress.value = clampf(p, 0.0, 1.0)

## 판정 텍스트를 화면의 이 지점(픽셀)을 중심으로 표시한다.
func set_judge_anchor(center: Vector2) -> void:
	var size := Vector2(600.0, 110.0)
	_judge.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_judge.position = center - size * 0.5
	_judge.size = size

func set_speed(v: float) -> void:
	_speed.text = "SPEED %.1f   (1: -  2: +)   Esc: 메뉴" % v

func _process(delta: float) -> void:
	if _judge_timer > 0.0:
		_judge_timer -= delta
		if _judge_timer <= 0.0:
			_judge.text = ""

func _refresh() -> void:
	_score.text = fmt_score(_score_mgr.score)
	var c: Array[int] = _score_mgr.counts
	var judged: int = c[0] + c[1] + c[2]
	_rate.text = "%.2f%%" % (100.0 * (c[0] + c[1] * GameConst.GREAT_WEIGHT) / maxf(judged, 1)) if judged > 0 else "0.00%"
	_combo.text = str(_score_mgr.combo) if _score_mgr.combo > 1 else ""

func _on_judged(_note: NoteData, grade: int, delta_ms: float, is_tick: bool) -> void:
	if is_tick:
		return
	var text: String = JudgeLogic.grade_name(grade)
	if grade == JudgeLogic.Grade.GREAT:
		text += "\n" + ("FAST" if delta_ms < 0.0 else "SLOW")
	_judge.text = text
	_judge.add_theme_color_override("font_color", Color.WHITE)
	var oc: Color = GRADE_COLORS[grade]
	_judge.add_theme_color_override("font_outline_color", Color(oc.r * 0.55, oc.g * 0.35, oc.b * 0.8, 0.9))
	_judge_timer = 0.5

# --- 결과 화면 ---
func show_result(score_mgr: ScoreManager, title: String, new_record: bool = false) -> void:
	if _result != null:
		_result.queue_free()
	var rank: String = score_mgr.rank()
	var rank_color: Color = RANK_COLORS[rank]

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result = root
	add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.02, 0.05, 0.8)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620.0, 0.0)
	panel.add_theme_stylebox_override("panel", Ui.panel_style(rank_color))
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	var head := HBoxContainer.new()
	v.add_child(head)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(left)
	left.add_child(_plain("RESULT", 18, Color(1, 1, 1, 0.6)))
	left.add_child(_plain(title, 26, Color.WHITE))
	var rank_l := _plain(rank, 84, rank_color)
	rank_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(rank_l)

	var score_l := _plain(fmt_score(score_mgr.score), 56, Ui.CYAN)
	score_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(score_l)
	if new_record:
		var nr := _plain("NEW RECORD", 20, Color(1.0, 0.5, 0.7))
		nr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(nr)
	if rank != "AP" and score_mgr.is_full_combo():
		var fc := _plain("FULL COMBO", 22, Color(1.0, 0.85, 0.3))
		fc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(fc)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 4)
	v.add_child(grid)
	_stat(grid, "PERFECT", str(score_mgr.counts[0]), GRADE_COLORS[0])
	_stat(grid, "GREAT", str(score_mgr.counts[1]), GRADE_COLORS[1])
	_stat(grid, "   FAST / SLOW", "%d / %d" % [score_mgr.fast, score_mgr.slow], Color(1, 1, 1, 0.6))
	_stat(grid, "MISS", str(score_mgr.counts[2]), GRADE_COLORS[2])
	_stat(grid, "MAX COMBO", str(score_mgr.max_combo), Color.WHITE)
	var total: int = score_mgr.counts[0] + score_mgr.counts[1] + score_mgr.counts[2]
	var acc: float = 100.0 * (score_mgr.counts[0] + score_mgr.counts[1]) / maxf(total, 1)
	_stat(grid, "정확도(MISS 제외)", "%.2f%%" % acc, Color.WHITE)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 12)
	v.add_child(btns)
	_btn(btns, "다시 하기 (R)", "retry")
	_btn(btns, "설정", "settings")
	_btn(btns, "곡 선택 (Esc)", "quit")

func hide_result() -> void:
	if _result != null:
		_result.queue_free()
		_result = null

func is_result_open() -> bool:
	return _result != null

static func fmt_score(n: int) -> String:
	return "%03d'%03d'%03d" % [floori(n / 1000000.0), floori(n / 1000.0) % 1000, n % 1000]

# --- 빌더 ---
func _build_score_panel() -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _bar_style())
	p.position = Vector2(16.0, 14.0)
	add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	v.add_child(_plain("SCORE", 14, Color(1, 1, 1, 0.6)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	_score = _plain("", 50, Ui.CYAN)
	_score.add_theme_constant_override("outline_size", 6)
	row.add_child(_score)
	_rate = _plain("0.00%", 18, Color(1, 1, 1, 0.7))
	_rate.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(_rate)

func _build_song_panel() -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _bar_style())
	p.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	p.offset_right = -16.0
	p.offset_left = -396.0
	p.offset_top = 14.0
	add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	_jacket = ColorRect.new()
	_jacket.custom_minimum_size = Vector2(76.0, 76.0)
	h.add_child(_jacket)
	_jacket_letter = _plain("", 44, Color(1, 1, 1, 0.45))
	_jacket_letter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_jacket_letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_jacket_letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_jacket.add_child(_jacket_letter)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	_title = _plain("", 24, Color.WHITE)
	_title.clip_text = true
	_artist = _plain("", 15, Color(1, 1, 1, 0.65))
	_level_chip = _plain("", 13, Color(0.8, 0.6, 1.0))
	v.add_child(_title)
	v.add_child(_artist)
	v.add_child(_level_chip)
	_progress = ProgressBar.new()
	_progress.max_value = 1.0
	_progress.step = 0.0
	_progress.show_percentage = false
	_progress.custom_minimum_size = Vector2(0.0, 5.0)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Ui.CYAN
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.15)
	_progress.add_theme_stylebox_override("fill", fill)
	_progress.add_theme_stylebox_override("background", bg)
	v.add_child(_progress)

func _bar_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.07, 0.12, 0.6)
	sb.border_color = Ui.CYAN
	sb.border_width_left = 4
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 8.0
	return sb

func _plain(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _stat(grid: GridContainer, caption: String, value: String, color: Color) -> void:
	var a := _plain(caption, 22, Color(1, 1, 1, 0.8))
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b := _plain(value, 22, color)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(a)
	grid.add_child(b)

func _btn(parent: Control, text: String, action: String) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0.0, 46.0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 20)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): result_action.emit(action))
	parent.add_child(b)

func _make_label(font_size: int, preset: int, top: float) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_constant_override("outline_size", 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
	l.set_anchors_and_offsets_preset(preset)
	l.offset_top = top
	l.offset_bottom = top + font_size * 1.4
	return l
