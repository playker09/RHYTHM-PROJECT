extends Control
## 선곡 화면. 왼쪽 = 선택한 곡의 실제 정보, 오른쪽 = 곡 휠.
## ↑↓ 곡 선택, ←→ 배속, Enter 시작, Esc 뒤로, Tab 설정.
## 화면에 보이는 숫자는 전부 채보/기록에서 계산한 값이다.

const PREVIEW_DELAY := 0.3
const GRAPH_CAPTION_W := 66.0

var _charts: Array = []
var _index: int = 0
var _busy: bool = false
var _preview_wait: float = -1.0

var _bg: AmbientBg
var _wheel: _Wheel
var _hero: Control
var _jacket: Jacket
var _chip_box: HBoxContainer
var _title: Label
var _artist: Label
var _stats: HBoxContainer
var _types: Label
var _wave: TimelineGraph
var _wave_empty: Label
var _density: TimelineGraph
var _graph_end: Label
var _best: PanelContainer
var _speed: Label
var _settings: SettingsPanel

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_charts = ChartLoader.list_charts()
	_bg = AmbientBg.new()
	add_child(_bg)
	_build_top()
	_build_hero()
	_build_wheel()
	_build_footer()
	_settings = SettingsPanel.new()
	add_child(_settings)
	_settings.changed.connect(_refresh_speed)
	_refresh_speed()
	if _charts.is_empty():
		_title.text = "곡이 없습니다"
		_artist.text = "charts 폴더에 chart.json 을 넣어 주세요"
		return
	var last: int = _charts.map(func(c): return c["path"]).find(App.selected_chart)
	_select(maxi(last, 0), false)
	_wheel.snap()

# ---------------- 구성 ----------------
func _build_top() -> void:
	var top := Ui.hbox(14)
	Ui.place(top, 0.0, 0.0, 0.62, 0.0, 56.0, 26.0, 0.0, 74.0)
	add_child(top)
	var title := Ui.d("곡 선택", 30, Ui.TEXT, 700)
	top.add_child(title)
	top.add_child(Ui.expander())
	var speed_box := Ui.hbox(10)
	speed_box.alignment = BoxContainer.ALIGNMENT_END
	top.add_child(speed_box)
	var cap := Ui.t("배속", 13, Ui.TEXT_3, 500, 1)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	speed_box.add_child(cap)
	_speed = Ui.d("", 26, Ui.CYAN, 600)
	speed_box.add_child(_speed)

func _build_hero() -> void:
	_hero = Control.new()
	Ui.place(_hero, 0.0, 0.0, 0.62, 1.0, 56.0, 88.0, 0.0, -72.0)
	add_child(_hero)
	var v := Ui.vbox(16)
	Ui.place(v, 0.0, 0.0, 1.0, 1.0)
	_hero.add_child(v)

	# 재킷 + 곡 정보
	var upper := Ui.hbox(28)
	v.add_child(upper)
	_jacket = Jacket.new()
	_jacket.custom_minimum_size = Vector2(280.0, 280.0)
	upper.add_child(_jacket)
	var info := Ui.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upper.add_child(info)
	_chip_box = Ui.hbox(8)
	info.add_child(_chip_box)
	info.add_child(Ui.gap(6.0))
	_title = Ui.d("", 42, Ui.TEXT, 700)
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.clip_text = true
	_title.custom_minimum_size = Vector2(120.0, 0.0)
	info.add_child(_title)
	_artist = Ui.t("", 18, Ui.TEXT_2)
	_artist.clip_text = true
	info.add_child(_artist)
	info.add_child(Ui.expander())
	_stats = Ui.hbox(32)
	info.add_child(_stats)
	info.add_child(Ui.gap(8.0))
	_types = Ui.t("", 13, Ui.TEXT_2, 500)
	info.add_child(_types)

	# 위 = 소리 파형, 아래 = 노트 밀도 (같은 시간축)
	var graph_box := Ui.vbox(4)
	graph_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(graph_box)
	_wave = _add_graph_row(graph_box, "파형")
	_wave.silhouette = true
	_wave_empty = Ui.t("파형 파일 없음", 12, Ui.TEXT_3)
	_wave_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Ui.place(_wave_empty, 0.0, 0.0, 1.0, 1.0)
	_wave.add_child(_wave_empty)
	_density = _add_graph_row(graph_box, "노트 밀도")
	var axis := Ui.hbox(0)
	graph_box.add_child(axis)
	var axis_inset := Control.new()     # 눈금을 그래프 왼쪽 끝에 맞춘다
	axis_inset.custom_minimum_size = Vector2(GRAPH_CAPTION_W, 0.0)
	axis.add_child(axis_inset)
	axis.add_child(Ui.d("0:00", 13, Ui.TEXT_3, 500))
	axis.add_child(Ui.expander())
	_graph_end = Ui.d("", 13, Ui.TEXT_3, 500)
	axis.add_child(_graph_end)

	# 최고 기록
	_best = PanelContainer.new()
	var sb := Ui.panel_style()
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 12.0
	_best.add_theme_stylebox_override("panel", sb)
	_best.custom_minimum_size = Vector2(0.0, 86.0)
	_best.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_best)

func _add_graph_row(parent: Control, caption: String) -> TimelineGraph:
	var row := Ui.hbox(0)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	var cap := Ui.t(caption, 12, Ui.TEXT_3, 500, 1)
	cap.custom_minimum_size = Vector2(GRAPH_CAPTION_W, 0.0)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(cap)
	var graph := TimelineGraph.new()
	graph.custom_minimum_size = Vector2(0.0, 58.0)
	graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(graph)
	return graph

func _build_wheel() -> void:
	_wheel = _Wheel.new()
	Ui.place(_wheel, 0.62, 0.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0)
	add_child(_wheel)
	_wheel.setup(_charts)
	_wheel.picked.connect(func(i: int):
		if i == _index:
			_start()
		else:
			_select(i))
	_wheel.scrolled.connect(func(d: int): _select(_index + d))

func _build_footer() -> void:
	var foot := Ui.hbox(0)
	Ui.place(foot, 0.0, 1.0, 1.0, 1.0, 56.0, -56.0, -40.0, -14.0)
	add_child(foot)
	foot.add_child(Ui.hints([["↑↓", "곡"], ["←→", "배속"], ["Tab", "설정"], ["Esc", "뒤로"]]))
	foot.add_child(Ui.expander())
	var go := Ui.button("시작  Enter", true)
	go.custom_minimum_size = Vector2(190.0, 42.0)
	go.pressed.connect(_start)
	foot.add_child(go)

# ---------------- 동작 ----------------
func _select(i: int, with_sound: bool = true) -> void:
	if _charts.is_empty():
		return
	var ni: int = clampi(i, 0, _charts.size() - 1)
	if with_sound:
		if ni == _index:
			return
		App.sfx("move")
	_index = ni
	var c: Dictionary = _charts[_index]
	_wheel.set_index(_index)
	_jacket.set_song(String(c["title"]))
	_title.text = String(c["title"])
	_artist.text = String(c["artist"])

	for ch in _chip_box.get_children():
		_chip_box.remove_child(ch)
		ch.queue_free()
	_chip_box.add_child(Ui.chip("%s  %d" % [String(c["difficulty"]), int(c["level"])], Ui.TEXT))

	for ch in _stats.get_children():
		_stats.remove_child(ch)
		ch.queue_free()
	var bpm_lo: int = roundi(float(c["bpm"]))
	var bpm_hi: int = roundi(float(c["bpm_hi"]))
	_stats.add_child(Ui.stat("BPM", str(bpm_lo) if bpm_lo == bpm_hi else "%d-%d" % [bpm_lo, bpm_hi])["root"])
	_stats.add_child(Ui.stat("길이", Ui.fmt_time(float(c["duration_ms"])))["root"])
	_stats.add_child(Ui.stat("노트", Ui.fmt_int(int(c["notes"])))["root"])
	_stats.add_child(Ui.stat("최대 콤보", Ui.fmt_int(int(c["total"])))["root"])
	var ty: Dictionary = c["types"]
	_types.text = "TAP %d   ·   HOLD %d   ·   FIELD %d   ·   FLICK %d" % [ty["tap"], ty["hold"], ty["field"], ty["flick"]]

	var wave: PackedFloat32Array = c["waveform"]
	_wave.set_data(wave)
	_wave_empty.visible = wave.is_empty()
	_density.set_data(c["density"])
	_graph_end.text = Ui.fmt_time(float(c["duration_ms"]))
	_build_best(c)

	var pal: Array = Jacket.palette(String(c["title"]))
	_bg.set_tint(pal[1], pal[2])

	# 전환 모션
	_hero.modulate.a = 0.35
	_hero.offset_left = 56.0 + 14.0
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_hero, "modulate:a", 1.0, 0.2)
	tw.tween_property(_hero, "offset_left", 56.0, 0.24)

	App.preview_stop()
	_preview_wait = PREVIEW_DELAY

func _build_best(c: Dictionary) -> void:
	for ch in _best.get_children():
		_best.remove_child(ch)
		ch.queue_free()
	var rec: Dictionary = App.get_record(String(c["path"]))
	if rec.is_empty():
		var none := Ui.t("아직 플레이 기록이 없습니다", 16, Ui.TEXT_3)
		none.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_best.add_child(none)
		return
	var h := Ui.hbox(26)
	_best.add_child(h)
	var rank := String(rec["rank"])
	var rank_l := Ui.d(rank, 54, Ui.RANK_COLORS.get(rank, Ui.TEXT), 700, 0, true)
	rank_l.custom_minimum_size = Vector2(64.0, 0.0)
	rank_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(rank_l)
	var score_box := Ui.vbox(0)
	score_box.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(score_box)
	score_box.add_child(Ui.d(Ui.fmt_int(int(rec["score"])), 34, Ui.TEXT, 700))
	score_box.add_child(Ui.t("최고 점수", 12, Ui.TEXT_3, 500, 1))
	h.add_child(Ui.expander())
	var acc: Dictionary = Ui.stat("정확도", "%.2f%%" % (float(rec["score"]) / 10000.0), 22)
	(acc["root"] as Control).alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(acc["root"])
	var combo: Dictionary = Ui.stat("콤보", "%s / %s" % [Ui.fmt_int(int(rec["max_combo"])), Ui.fmt_int(int(c["total"]))], 22)
	(combo["root"] as Control).alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(combo["root"])
	if rank == "AP":
		h.add_child(Ui.chip("ALL PERFECT", Ui.GOLD))
	elif int(rec["max_combo"]) >= int(c["total"]):
		h.add_child(Ui.chip("FULL COMBO", Ui.CYAN))

func _refresh_speed() -> void:
	_speed.text = "%.1f" % Settings.hispeed

func _process(delta: float) -> void:
	if _charts.is_empty():
		return
	if _preview_wait >= 0.0:
		_preview_wait -= delta
		if _preview_wait < 0.0 and not _busy:
			var c: Dictionary = _charts[_index]
			App.preview_play(String(c["audio"]), float(c["duration_ms"]) * 0.2, float(c["bpm"]))
	_bg.pulse = App.preview_pulse()
	var pos: float = App.preview_position_ms()
	var dur: float = float(_charts[_index]["duration_ms"])
	var head: float = clampf(pos / maxf(dur, 1.0), 0.0, 1.0) if pos >= 0.0 and pos <= dur else -1.0
	_wave.playhead = head
	_density.playhead = head

func _input(event: InputEvent) -> void:
	if _busy or _settings.is_open():
		return
	if event is InputEventKey and event.pressed:
		var k := event as InputEventKey
		match k.physical_keycode:
			KEY_UP:
				_select(_index - 1)
			KEY_DOWN:
				_select(_index + 1)
			KEY_LEFT:
				_change_speed(-0.1)
			KEY_RIGHT:
				_change_speed(0.1)
			KEY_TAB:
				if not k.echo:
					_settings.open()
			KEY_ENTER, KEY_KP_ENTER:
				if not k.echo and not k.alt_pressed:
					_start()
			KEY_ESCAPE:
				if not k.echo:
					_busy = true
					App.sfx("back")
					App.goto(App.MENU_SCENE)

func _change_speed(step: float) -> void:
	Settings.hispeed = clampf(snappedf(Settings.hispeed + step, 0.1), 0.5, 4.0)
	Settings.save_settings()
	_refresh_speed()
	App.sfx("move")

func _start() -> void:
	if _charts.is_empty() or _busy:
		return
	_busy = true
	App.sfx("confirm")
	App.start_game(String(_charts[_index]["path"]))

## 곡 휠: 선택 곡이 세로 중앙에 오고, 멀어질수록 오른쪽으로 휘며 흐려진다.
class _Wheel extends Control:
	signal picked(i: int)
	signal scrolled(d: int)

	const ROW_H := 92.0

	var _rows: Array[_WheelRow] = []
	var _pos: float = 0.0
	var _index: int = 0

	func setup(charts: Array) -> void:
		clip_contents = true
		for i in charts.size():
			var r := _WheelRow.new()
			r.setup(charts[i])
			add_child(r)
			_rows.append(r)

	func set_index(i: int) -> void:
		_index = i
		for k in _rows.size():
			_rows[k].set_selected(k == i)

	func snap() -> void:
		_pos = _index

	func _process(delta: float) -> void:
		_pos = lerpf(_pos, _index, 1.0 - exp(-delta * 14.0))
		var cy: float = size.y * 0.5 - 18.0
		for i in _rows.size():
			var d: float = float(i) - _pos
			var r: _WheelRow = _rows[i]
			var ad: float = absf(d)
			r.position = Vector2(26.0 + pow(ad, 1.5) * 26.0, cy + d * ROW_H - ROW_H * 0.5)
			r.size = Vector2(size.x + 40.0, ROW_H - 10.0)
			r.fit_width(size.x - r.position.x)
			r.modulate.a = clampf(1.15 - ad * 0.24, 0.0, 1.0)
			r.visible = r.modulate.a > 0.01

	func _gui_input(event: InputEvent) -> void:
		if not event is InputEventMouseButton or not event.pressed:
			return
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				scrolled.emit(-1)
			MOUSE_BUTTON_WHEEL_DOWN:
				scrolled.emit(1)
			MOUSE_BUTTON_LEFT:
				var cy: float = size.y * 0.5 - 18.0
				var i: int = roundi((mb.position.y - cy) / ROW_H + _pos)
				if i >= 0 and i < _rows.size():
					picked.emit(i)

## 휠 한 줄. 선택되면 메뉴와 같은 흰 슬랩이 된다.
class _WheelRow extends Control:
	var _sel: float = 0.0
	var _target: float = 0.0
	var _title: Label
	var _sub: Label
	var _level: Label
	var _rank: Label
	var _rank_text: String = ""

	func setup(c: Dictionary) -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var jacket := Jacket.new()
		jacket.position = Vector2(26.0, 7.0)
		jacket.size = Vector2(68.0, 68.0)
		jacket.set_song(String(c["title"]))
		add_child(jacket)
		_title = Ui.d(String(c["title"]), 25, Ui.TEXT, 600)
		_title.position = Vector2(112.0, 11.0)
		add_child(_title)
		_sub = Ui.t("%s" % String(c["artist"]), 14, Ui.TEXT_2)
		_sub.position = Vector2(113.0, 44.0)
		add_child(_sub)
		_level = Ui.d("Lv %d" % int(c["level"]), 22, Ui.TEXT, 700, 0, true)
		_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_level.position = Vector2(330.0, 11.0)
		_level.size = Vector2(70.0, 30.0)
		add_child(_level)
		var rec: Dictionary = App.get_record(String(c["path"]))
		_rank_text = String(rec.get("rank", ""))
		_rank = Ui.d(_rank_text, 20, Ui.RANK_COLORS.get(_rank_text, Ui.TEXT), 700, 0, true)
		_rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_rank.position = Vector2(330.0, 41.0)
		_rank.size = Vector2(70.0, 28.0)
		add_child(_rank)
		_title.clip_text = true
		_title.size = Vector2(190.0, 34.0)
		_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_sub.clip_text = true
		_sub.size = Vector2(190.0, 22.0)

	## 휠이 휘어도 오른쪽 글자가 화면 안에 들어오게 맞춘다. w = 줄의 보이는 폭
	func fit_width(w: float) -> void:
		_level.position.x = w - 92.0
		_rank.position.x = w - 92.0
		_title.size.x = maxf(w - 212.0, 40.0)
		_sub.size.x = maxf(w - 212.0, 40.0)

	func set_selected(on: bool) -> void:
		_target = 1.0 if on else 0.0
		var fg: Color = Ui.INK if on else Ui.TEXT
		Ui.set_color(_title, fg)
		Ui.set_color(_level, fg)
		Ui.set_color(_sub, Color(Ui.INK, 0.65) if on else Ui.TEXT_2)
		var rc: Color = Ui.RANK_COLORS.get(_rank_text, Ui.TEXT)
		Ui.set_color(_rank, rc.darkened(0.5) if on else rc)

	func _process(delta: float) -> void:
		if absf(_sel - _target) > 0.002:
			_sel = lerpf(_sel, _target, 1.0 - exp(-delta * 18.0))
			queue_redraw()

	func _draw() -> void:
		var skew: float = size.y * Ui.SLANT
		var bg: Color = Color(0.09, 0.08, 0.15, 0.62).lerp(Ui.TEXT, _sel)
		draw_colored_polygon(PackedVector2Array([
			Vector2(skew, 0.0), Vector2(size.x, 0.0), Vector2(size.x, size.y), Vector2(0.0, size.y)]), bg)
		if _sel > 0.02:
			var a: float = _sel
			var x0: float = skew - 13.0
			var ca := Color(Ui.VIOLET, a)
			var cb := Color(Ui.MAGENTA, a)
			draw_polygon(PackedVector2Array([
				Vector2(x0 - 7.0, 0.0), Vector2(x0, 0.0), Vector2(x0 - skew, size.y), Vector2(x0 - skew - 7.0, size.y)]),
				PackedColorArray([ca, ca, cb, cb]))
