extends Control
## 선곡 화면. 오른쪽 곡 목록, 왼쪽 곡 정보/최고 기록/배속.
## ↑↓ 곡 선택, ←→ 배속, Enter 시작, Esc 뒤로, Tab 설정.

const ACCENT := Color(0.35, 0.95, 0.85)
const ROW_H := 54.0
const LIST_TOP := 96.0
const VISIBLE_ROWS := 9

var _charts: Array = []
var _index: int = 0
var _scroll: int = 0
var _busy: bool = false

var _list: Control
var _jacket: ColorRect
var _jacket_letter: Label
var _title: Label
var _artist: Label
var _bpm: Label
var _level: Label
var _diff: Label
var _rec_score: Label
var _rec_rate: Label
var _rec_combo: Label
var _rec_rank: Label
var _speed: Label
var _settings: PauseMenu
var _bg: _SelectBg

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_charts = ChartLoader.list_charts()
	_bg = _SelectBg.new()
	add_child(_bg)
	_build_left()
	_build_right()
	_build_footer()
	_settings = PauseMenu.new()
	add_child(_settings)
	_settings.settings_changed.connect(_refresh_speed)
	var last: int = _charts.map(func(c): return c["path"]).find(App.selected_chart)
	_index = maxi(last, 0)
	_select(_index)

# ---------------- 구성 ----------------
func _build_left() -> void:
	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.04, 0.08, 0.88)
	sb.border_color = Color(1, 1, 1, 0.25)
	sb.set_border_width_all(1)
	sb.content_margin_left = 0.0
	sb.content_margin_right = 0.0
	sb.content_margin_top = 0.0
	sb.content_margin_bottom = 0.0
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(40.0, 52.0)
	panel.size = Vector2(312.0, 430.0)
	add_child(panel)

	var head := ColorRect.new()
	head.color = Color(0.1, 0.12, 0.16, 0.95)
	head.position = Vector2(0.0, 0.0)
	head.size = Vector2(312.0, 62.0)
	panel.add_child(head)
	_level = _lbl("8", 52, Color.WHITE)
	_level.position = Vector2(16.0, 2.0)
	panel.add_child(_level)
	_diff = _lbl("NORMAL", 20, Color(1, 1, 1, 0.9))
	_diff.position = Vector2(76.0, 8.0)
	panel.add_child(_diff)
	var tunes := _lbl("BUTTON TUNES", 13, Color(1, 1, 1, 0.6))
	tunes.position = Vector2(76.0, 36.0)
	panel.add_child(tunes)

	_jacket = ColorRect.new()
	_jacket.position = Vector2(0.0, 62.0)
	_jacket.size = Vector2(312.0, 150.0)
	panel.add_child(_jacket)
	_jacket_letter = _lbl("", 96, Color(1, 1, 1, 0.35))
	_jacket_letter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_jacket_letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_jacket_letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_jacket.add_child(_jacket_letter)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.25)
	_jacket.add_child(shade)

	_title = _lbl("", 32, Color.WHITE)
	_title.position = Vector2(14.0, 216.0)
	_title.size = Vector2(290.0, 40.0)
	_title.clip_text = true
	panel.add_child(_title)
	_artist = _lbl("", 16, Color(1, 1, 1, 0.75))
	_artist.position = Vector2(16.0, 256.0)
	panel.add_child(_artist)
	_bpm = _lbl("", 14, Color(1, 1, 1, 0.6))
	_bpm.position = Vector2(16.0, 278.0)
	panel.add_child(_bpm)

	var y := 312.0
	_rec_score = _record_row(panel, "Score", y)
	_rec_rate = _record_row(panel, "Rate", y + 22.0)
	_rec_combo = _record_row(panel, "Max Combo", y + 44.0)
	_rec_rank = _lbl("", 44, Color(1.0, 0.85, 0.3))
	_rec_rank.position = Vector2(238.0, 318.0)
	panel.add_child(_rec_rank)

	# 이펙터(배속)
	var eff := _lbl("EFFECTOR", 13, Color(1, 1, 1, 0.6))
	eff.position = Vector2(16.0, 384.0)
	panel.add_child(eff)
	_speed = _lbl("", 22, Color(1.0, 0.45, 0.4))
	_speed.position = Vector2(100.0, 378.0)
	panel.add_child(_speed)

func _record_row(parent: Control, caption: String, y: float) -> Label:
	var c := _lbl(caption, 15, Color(1, 1, 1, 0.65))
	c.position = Vector2(16.0, y)
	parent.add_child(c)
	var v := _lbl("-", 16, Color(1.0, 0.85, 0.3))
	v.position = Vector2(110.0, y)
	parent.add_child(v)
	return v

func _build_right() -> void:
	var sort_box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.4)
	sb.border_color = Color(1, 1, 1, 0.3)
	sb.set_border_width_all(1)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	sort_box.add_theme_stylebox_override("panel", sb)
	sort_box.position = Vector2(400.0, 20.0)
	sort_box.add_child(_lbl("≡ 정렬: 곡 제목 (A to Z)", 17, Color.WHITE))
	add_child(sort_box)

	var tabs := _lbl("ALL SONGS", 22, Color(1.0, 0.85, 0.35))
	tabs.position = Vector2(404.0, 62.0)
	add_child(tabs)

	_list = Control.new()
	_list.position = Vector2(400.0, LIST_TOP + 10.0)
	_list.size = Vector2(840.0, ROW_H * VISIBLE_ROWS)
	_list.clip_contents = true
	_list.gui_input.connect(_on_list_input)
	add_child(_list)

func _build_footer() -> void:
	var bar := ColorRect.new()
	bar.color = Color(0, 0, 0, 0.55)
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -44.0
	add_child(bar)
	var hints := HBoxContainer.new()
	hints.add_theme_constant_override("separation", 26)
	hints.position = Vector2(24.0, 684.0)
	add_child(hints)
	for h in ["↑↓ 음악 선택", "←→ 배속", "Tab 설정", "Enter 시작", "Esc 메뉴"]:
		hints.add_child(_lbl(h, 16, Color(1, 1, 1, 0.85)))

# ---------------- 동작 ----------------
func _select(i: int) -> void:
	if _charts.is_empty():
		_title.text = "채보가 없습니다"
		return
	_index = clampi(i, 0, _charts.size() - 1)
	if _index < _scroll:
		_scroll = _index
	elif _index >= _scroll + VISIBLE_ROWS:
		_scroll = _index - VISIBLE_ROWS + 1
	var c: Dictionary = _charts[_index]
	_title.text = String(c["title"])
	_artist.text = String(c["artist"])
	_bpm.text = "BPM %d    NOTES %d" % [int(c["bpm"]), int(c["notes"])]
	_level.text = str(int(c["level"]))
	_diff.text = String(c["difficulty"])
	var hue: float = float(String(c["title"]).hash() % 360) / 360.0
	_jacket.color = Color.from_hsv(hue, 0.55, 0.55)
	_jacket_letter.text = String(c["title"]).substr(0, 1).to_upper()
	_bg.tint = Color.from_hsv(hue, 0.5, 0.35)
	var rec: Dictionary = App.get_record(String(c["path"]))
	if rec.is_empty():
		_rec_score.text = "-"
		_rec_rate.text = "-"
		_rec_combo.text = "-"
		_rec_rank.text = ""
	else:
		_rec_score.text = str(int(rec["score"]))
		_rec_rate.text = "%.2f%%" % float(rec["rate"])
		_rec_combo.text = str(int(rec["max_combo"]))
		_rec_rank.text = String(rec["rank"])
	_refresh_speed()
	_rebuild_rows()

func _refresh_speed() -> void:
	_speed.text = "SPEED  %.1f" % Settings.hispeed

func _rebuild_rows() -> void:
	for ch in _list.get_children():
		ch.queue_free()
	for r in VISIBLE_ROWS:
		var i: int = _scroll + r
		if i >= _charts.size():
			break
		_list.add_child(_make_row(i, r))

func _make_row(i: int, r: int) -> Control:
	var sel: bool = i == _index
	var c: Dictionary = _charts[i]
	var row := _Row.new()
	row.selected = sel
	row.position = Vector2(0.0, r * ROW_H)
	row.size = Vector2(840.0, ROW_H - 4.0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := _lbl(String(c["title"]), 24, Color.WHITE if sel else Color(1, 1, 1, 0.9))
	t.position = Vector2(66.0, 2.0)
	row.add_child(t)
	var a := _lbl(String(c["artist"]), 13, Color(1, 1, 1, 0.55 if not sel else 0.85))
	a.position = Vector2(68.0, 31.0)
	row.add_child(a)
	var thumb := ColorRect.new()
	thumb.color = Color.from_hsv(float(String(c["title"]).hash() % 360) / 360.0, 0.55, 0.6)
	thumb.position = Vector2(8.0, 4.0)
	thumb.size = Vector2(46.0, 42.0)
	row.add_child(thumb)
	var lv := _lbl("Lv %d" % int(c["level"]), 18, Color(1, 1, 1, 0.9))
	lv.position = Vector2(740.0, 12.0)
	row.add_child(lv)
	return row

func _on_list_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_select(_index - 1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_select(_index + 1)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			var i: int = _scroll + int(mb.position.y / ROW_H)
			if i >= 0 and i < _charts.size():
				if i == _index:
					_start()
				else:
					_select(i)

func _input(event: InputEvent) -> void:
	if _busy or _settings.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).physical_keycode:
			KEY_UP:
				_select(_index - 1)
			KEY_DOWN:
				_select(_index + 1)
			KEY_LEFT:
				_change_speed(-0.1)
			KEY_RIGHT:
				_change_speed(0.1)
			KEY_TAB:
				_settings.open_settings_only()
			KEY_ENTER, KEY_KP_ENTER:
				_start()
			KEY_ESCAPE:
				_busy = true
				App.goto(App.MENU_SCENE)

func _change_speed(step: float) -> void:
	Settings.hispeed = clampf(snappedf(Settings.hispeed + step, 0.1), 0.5, 4.0)
	Settings.save_settings()
	_refresh_speed()

func _start() -> void:
	if _charts.is_empty() or _busy:
		return
	_busy = true
	App.start_game(String(_charts[_index]["path"]))

func _lbl(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

## 목록 한 줄. 선택 시 주황 -> 보라 가로 그라데이션.
class _Row extends Control:
	var selected: bool = false
	func _draw() -> void:
		if selected:
			var steps := 40
			for i in steps:
				var k: float = float(i) / steps
				var col := Color(1.0, 0.65, 0.05).lerp(Color(0.62, 0.3, 1.0), clampf((k - 0.35) / 0.65, 0.0, 1.0))
				draw_rect(Rect2(size.x * k, 0.0, size.x / steps + 1.0, size.y), col)
		else:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.04, 0.45))
			draw_rect(Rect2(0.0, size.y - 1.0, size.x, 1.0), Color(1, 1, 1, 0.08))

## 곡 색에 맞춰 은은하게 바뀌는 어두운 배경 (블러 배경 느낌)
class _SelectBg extends Control:
	var tint: Color = Color(0.2, 0.15, 0.3):
		set(v):
			tint = v
			queue_redraw()
	var _t: float = 0.0
	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.04, 0.07))
		for i in 6:
			var p := Vector2(size.x * (0.3 + 0.12 * i) + sin(_t * 0.3 + i) * 40.0, size.y * (0.3 + 0.1 * (i % 3)) + cos(_t * 0.25 + i) * 30.0)
			for r in 8:
				draw_circle(p, 260.0 - r * 28.0, Color(tint.r, tint.g, tint.b, 0.05))
