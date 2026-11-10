extends Control
## 선곡 화면. 왼쪽 = 곡 휠, 오른쪽 = 고른 곡의 정보/난이도/그래프/기록. 뒤는 3D 무대.
## ↑↓ 곡, ←→ 난이도, 1/2 배속, Tab 설정, Enter 시작, Esc 뒤로.
## 화면에 보이는 숫자는 전부 채보/기록에서 계산한 값이다.

const PREVIEW_DELAY := 0.35
const GRAPH_CAPTION_W := 62.0
const SPEED_STEP := 0.1

var _songs: Array = []
var _index: int = 0
var _slot: int = 1                   # 지금 보여 주는 난이도 슬롯
var _busy: bool = false
var _preview_wait: float = -1.0

var _world: MenuWorld
var _wheel: _Wheel
var _hero: Control
var _jacket: Jacket
var _title: Label
var _artist: Label
var _bpm: Label
var _length: Label
var _tiles: Array[_DiffTile] = []
var _notes: Label
var _combo: Label
var _types: Label
var _wave: TimelineGraph
var _wave_empty: Label
var _density: TimelineGraph
var _graph_end: Label
var _record: GlassPanel
var _record_box: HBoxContainer
var _speed: Label
var _counter: Label
var _settings: SettingsPanel

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_songs = ChartLoader.list_songs()
	# 선곡 배경 음악은 고른 곡의 미리듣기가 안 나올 때만 튼다 (_process 참고)
	if _songs.is_empty():
		App.bgm_play("select")
	else:
		App.bgm_stop()
	_world = MenuWorld.new("select", 0.42, 1.6)
	add_child(_world)
	_build_header()
	_build_wheel()
	_build_hero()
	_build_footer()
	_settings = SettingsPanel.new()
	add_child(_settings)
	_settings.changed.connect(_refresh_speed)
	_refresh_speed()
	if _songs.is_empty():
		_title.text = "곡이 없습니다"
		_artist.text = "charts/<곡 폴더>/ 에 ez.json · nm.json · hd.json 을 넣어 주세요"
		return
	var last: int = 0
	for i in _songs.size():
		if App.selected_chart.begins_with(String(_songs[i]["dir"]) + "/"):
			last = i
	_wheel.setup(_songs)
	_select(last, false)
	_wheel.snap()

# ---------------- 구성 ----------------
func _build_header() -> void:
	var head := Ui.vbox(-4)
	Ui.place(head, 0.0, 0.0, 0.5, 0.0, 56.0, 26.0, 0.0, 96.0)
	add_child(head)
	head.add_child(Ui.caption("SONG SELECT", Ui.VIOLET, 13))
	head.add_child(Ui.t("곡 선택", 32, Ui.TEXT, 700))
	Ui.reveal(head, 0.05)

	var right := Ui.hbox(12)
	right.alignment = BoxContainer.ALIGNMENT_END
	Ui.place(right, 0.5, 0.0, 1.0, 0.0, 0.0, 36.0, -56.0, 80.0)
	add_child(right)
	_counter = Ui.caption("", Ui.TEXT_3, 12)
	_counter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.add_child(_counter)
	right.add_child(Ui.gap(18.0))
	var cap := Ui.caption("SPEED", Ui.TEXT_3, 12)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.add_child(cap)
	_speed = Ui.d("1.0", 28, Ui.CYAN, 600, 1, true)
	right.add_child(_speed)
	Ui.reveal(right, 0.05)

func _build_wheel() -> void:
	_wheel = _Wheel.new()
	Ui.place(_wheel, 0.0, 0.0, 0.43, 1.0, 0.0, 108.0, 0.0, -84.0)
	add_child(_wheel)
	_wheel.picked.connect(func(i: int):
		if i != _index:
			_select(i))
	_wheel.confirmed.connect(_start)
	Ui.slide_in(_wheel, -60.0, 0.1)

func _build_hero() -> void:
	var back := GlassPanel.new(0.0, Color(0.03, 0.026, 0.07, 0.42), 2.5)
	Ui.place(back, 0.46, 0.0, 1.0, 1.0, -26.0, 84.0, -34.0, -74.0)
	add_child(back)
	Ui.slide_in(back, 60.0, 0.16)
	_hero = Ui.vbox(0)
	Ui.place(_hero, 0.46, 0.0, 1.0, 1.0, 0.0, 106.0, -60.0, -96.0)
	add_child(_hero)

	# --- 재킷 + 곡 정보 + 난이도 ---
	var top := Ui.hbox(26)
	_hero.add_child(top)
	var frame := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.3)
	sb.border_color = Color(1, 1, 1, 0.3)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(5.0)
	frame.add_theme_stylebox_override("panel", sb)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(frame)
	_jacket = Jacket.new()
	_jacket.custom_minimum_size = Vector2(196.0, 196.0)
	frame.add_child(_jacket)

	var info := Ui.vbox(0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(info)
	_title = Ui.d("", 38, Ui.TEXT, 700)
	_title.clip_text = true
	info.add_child(_title)
	_artist = Ui.t("", 15, Ui.TEXT_2)
	_artist.clip_text = true
	info.add_child(_artist)
	info.add_child(Ui.gap(12.0))
	var meta := Ui.hbox(36)
	info.add_child(meta)
	var bpm: Dictionary = Ui.stat("BPM", "-", 24)
	_bpm = bpm["value"]
	meta.add_child(bpm["root"])
	var length: Dictionary = Ui.stat("LENGTH", "-", 24)
	_length = length["value"]
	meta.add_child(length["root"])
	info.add_child(Ui.expander())
	info.add_child(Ui.caption("DIFFICULTY", Ui.TEXT_3, 11))
	info.add_child(Ui.gap(4.0))
	var tiles := Ui.hbox(8)
	info.add_child(tiles)
	for i in ChartLoader.DIFFS.size():
		var tile := _DiffTile.new()
		tile.setup(i)
		tile.pressed.connect(_set_slot.bind(i))
		tiles.add_child(tile)
		_tiles.append(tile)

	# --- 채보 수치 ---
	_hero.add_child(Ui.gap(16.0))
	var stats := Ui.hbox(36)
	_hero.add_child(stats)
	var notes: Dictionary = Ui.stat("NOTES", "-", 24)
	_notes = notes["value"]
	stats.add_child(notes["root"])
	var combo: Dictionary = Ui.stat("MAX COMBO", "-", 24)
	_combo = combo["value"]
	stats.add_child(combo["root"])
	stats.add_child(Ui.expander())
	_types = Ui.d("", 13, Ui.TEXT_2, 500, 1)
	_types.size_flags_vertical = Control.SIZE_SHRINK_END
	stats.add_child(_types)

	# --- 그래프: 위 = 소리 파형, 아래 = 노트 밀도 (시간축 동일) ---
	_hero.add_child(Ui.gap(10.0))
	_wave = TimelineGraph.new()
	_wave.silhouette = true
	_hero.add_child(_graph_row("WAVE", _wave, 40.0))
	_wave_empty = Ui.t("파형 파일 없음", 12, Ui.TEXT_3)
	_wave_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Ui.place(_wave_empty, 0.0, 0.0, 1.0, 1.0, 4.0, 0.0, 0.0, 0.0)
	_wave.add_child(_wave_empty)
	_hero.add_child(Ui.gap(5.0))
	_density = TimelineGraph.new()
	_hero.add_child(_graph_row("NOTES", _density, 40.0))
	var axis := Ui.hbox(0)
	_hero.add_child(axis)
	axis.add_child(Ui.gap(GRAPH_CAPTION_W))
	axis.add_child(Ui.d("0:00", 11, Ui.TEXT_3, 500))
	axis.add_child(Ui.expander())
	_graph_end = Ui.d("", 11, Ui.TEXT_3, 500)
	axis.add_child(_graph_end)

	# --- 최고 기록 ---
	_hero.add_child(Ui.expander())
	_record = GlassPanel.new(16.0, Color(0.0, 0.0, 0.0, 0.25), 2.5)
	_record.custom_minimum_size = Vector2(0.0, 88.0)
	_hero.add_child(_record)
	_record_box = Ui.hbox(28)
	_record.content.add_child(_record_box)
	Ui.slide_in(_hero, 60.0, 0.16)

func _graph_row(caption: String, graph: TimelineGraph, height: float) -> HBoxContainer:
	var row := Ui.hbox(0)
	var cap := Ui.caption(caption, Ui.TEXT_3, 11)
	cap.custom_minimum_size = Vector2(GRAPH_CAPTION_W, 0.0)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(cap)
	graph.custom_minimum_size = Vector2(0.0, height)
	graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(graph)
	return row

func _build_footer() -> void:
	var foot := Ui.hbox(0)
	Ui.place(foot, 0.0, 1.0, 1.0, 1.0, 56.0, -68.0, -56.0, -22.0)
	add_child(foot)
	var hints := Ui.hints([["↑↓", "곡"], ["←→", "난이도"], ["1 2", "배속"], ["Tab", "설정"], ["Esc", "뒤로"]])
	hints.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(hints)
	foot.add_child(Ui.expander())
	var start := Ui.button("시작   Enter", true)
	start.custom_minimum_size = Vector2(220.0, 46.0)
	start.pressed.connect(_start)
	foot.add_child(start)
	Ui.reveal(foot, 0.3)

# ---------------- 동작 ----------------
func _process(delta: float) -> void:
	if _preview_wait >= 0.0:
		_preview_wait -= delta
		if _preview_wait < 0.0 and not _songs.is_empty() and not _busy:
			var s: Dictionary = _songs[_index]
			if App.preview_play(String(s["audio"]), float(s["duration_ms"]) * 0.3, float(s["bpm"])):
				App.bgm_stop()
			else:
				App.bgm_play("select")
	# 미리듣기 재생 위치를 그래프에 표시
	var head: float = -1.0
	if not _songs.is_empty():
		var pos: float = App.preview_position_ms()
		var dur: float = float(_songs[_index]["duration_ms"])
		if pos >= 0.0 and dur > 0.0 and pos <= dur:
			head = pos / dur
	_wave.playhead = head
	_density.playhead = head
	_wheel.pulse = _world.pulse

func _input(event: InputEvent) -> void:
	if _busy or _settings.is_open() or App.is_busy():
		return
	if event is InputEventKey and event.pressed:
		var k := event as InputEventKey
		var handled: bool = true
		match k.physical_keycode:
			KEY_UP:
				_move(-1)
			KEY_DOWN:
				_move(1)
			KEY_LEFT:
				_move_slot(-1)
			KEY_RIGHT:
				_move_slot(1)
			KEY_1:
				_change_speed(-SPEED_STEP)
			KEY_2:
				_change_speed(SPEED_STEP)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if not k.echo and not k.alt_pressed:
					_start()
				else:
					handled = false
			KEY_TAB:
				if not k.echo:
					_settings.open()
			KEY_ESCAPE:
				if not k.echo:
					App.sfx("back")
					App.goto(App.MENU_SCENE)
			_:
				handled = false
		if handled:
			get_viewport().set_input_as_handled()

func _move(step: int) -> void:
	if _songs.size() > 1:
		_select(posmod(_index + step, _songs.size()))

func _select(i: int, with_sound: bool = true) -> void:
	_index = i
	if with_sound:
		App.sfx("move")
	var s: Dictionary = _songs[i]
	_slot = ChartLoader.nearest_diff(s["diffs"], App.selected_diff)
	_wheel.select(i)
	_title.text = String(s["title"])
	_artist.text = String(s["artist"])
	_jacket.set_song(String(s["title"]), String(s["jacket"]))
	var lo: float = float(s["bpm"])
	var hi: float = float(s["bpm_hi"])
	_bpm.text = "%d" % roundi(lo) if is_equal_approx(lo, hi) else "%d-%d" % [roundi(lo), roundi(hi)]
	_length.text = Ui.fmt_time(float(s["duration_ms"]))
	_graph_end.text = Ui.fmt_time(float(s["duration_ms"]))
	var wave: PackedFloat32Array = s["waveform"]
	_wave.set_data(wave)
	_wave_empty.visible = wave.is_empty()
	_counter.text = "%d / %d" % [i + 1, _songs.size()]
	for t in _tiles.size():
		var d: Dictionary = s["diffs"][t]
		_tiles[t].set_level(-1 if d.is_empty() else int(d["level"]))
	_refresh_diff()
	App.preview_stop()
	_preview_wait = PREVIEW_DELAY

func _move_slot(step: int) -> void:
	if _songs.is_empty():
		return
	var diffs: Array = _songs[_index]["diffs"]
	var i: int = _slot + step
	while i >= 0 and i < diffs.size():
		if not (diffs[i] as Dictionary).is_empty():
			_set_slot(i)
			return
		i += step

func _set_slot(i: int) -> void:
	if _songs.is_empty() or i == _slot or (_songs[_index]["diffs"][i] as Dictionary).is_empty():
		return
	_slot = i
	App.selected_diff = i
	App.sfx("tab", 0.4)
	_wheel.refresh_levels()
	_refresh_diff()

## 고른 난이도의 수치/밀도/기록을 채운다
func _refresh_diff() -> void:
	for t in _tiles.size():
		_tiles[t].set_selected(t == _slot)
	if _slot < 0:
		return
	var d: Dictionary = _songs[_index]["diffs"][_slot]
	var col: Color = Ui.DIFF_COLORS[_slot]
	_notes.text = Ui.fmt_int(int(d["notes"]))
	_combo.text = Ui.fmt_int(int(d["total"]))
	var c: Dictionary = d["types"]
	_types.text = "TAP %d   ·   HOLD %d   ·   FIELD %d   ·   FLICK %d" % [c["tap"], c["hold"], c["field"], c["flick"]]
	_density.color_a = col.lerp(Ui.VIOLET, 0.4)
	_density.color_b = col
	_density.set_data(d["density"])
	_record.accent = col
	_fill_record(App.get_record(String(d["path"])))

func _fill_record(rec: Dictionary) -> void:
	for c in _record_box.get_children():
		c.queue_free()
	if rec.is_empty():
		var v := Ui.vbox(-2)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(Ui.caption("BEST", Ui.TEXT_3, 11))
		v.add_child(Ui.t("아직 플레이 기록이 없습니다", 15, Ui.TEXT_2))
		_record_box.add_child(v)
		return
	var rank: String = String(rec["rank"])
	var rank_l := Ui.d(rank, 58, Ui.TEXT, 700, 0, true)
	Ui.gradient(rank_l, Ui.TEXT, Ui.RANK_COLORS.get(rank, Ui.TEXT), 70.0)
	rank_l.custom_minimum_size = Vector2(64.0, 0.0)
	rank_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_record_box.add_child(rank_l)
	_record_box.add_child(Ui.stat("BEST SCORE", Ui.fmt_int(int(rec["score"])), 28)["root"])
	_record_box.add_child(Ui.stat("ACCURACY", "%.2f%%" % float(rec["rate"]), 22, Ui.CYAN)["root"])
	_record_box.add_child(Ui.stat("MAX COMBO", Ui.fmt_int(int(rec["max_combo"])), 22)["root"])
	_record_box.add_child(Ui.stat("PLAYS", str(int(rec["plays"])), 22)["root"])
	_record_box.add_child(Ui.expander())
	if rank == "AP":
		_record_box.add_child(Ui.chip("ALL PERFECT", Ui.GOLD, true, 12))
	elif bool(rec["full_combo"]):
		_record_box.add_child(Ui.chip("FULL COMBO", Ui.CYAN, true, 12))

func _start() -> void:
	if _busy or _songs.is_empty() or _slot < 0 or App.is_busy():
		return
	_busy = true
	App.sfx("start", 0.55)
	App.start_game(String(_songs[_index]["diffs"][_slot]["path"]))

func _change_speed(step: float) -> void:
	Settings.hispeed = clampf(snappedf(Settings.hispeed + step, SPEED_STEP), 0.5, 4.0)
	Settings.save_settings()
	App.sfx("tab", 0.3)
	_refresh_speed()

func _refresh_speed() -> void:
	_speed.text = "%.1f" % Settings.hispeed

# ---------------- 난이도 타일 ----------------
## 사선 타일 하나: 난이도 이름 + 레벨. 채보가 없으면 "-" 로 흐리게.
class _DiffTile extends Control:
	signal pressed

	var _slot: int = 0
	var _level: int = -1
	var _selected: bool = false
	var _name: Label
	var _lv: Label
	var _k: float = 0.0

	func setup(slot: int) -> void:
		_slot = slot
		custom_minimum_size = Vector2(118.0, 58.0)
		_name = Ui.d(Ui.DIFF_LONG[slot], 11, Ui.TEXT_2, 600, 3)
		Ui.place(_name, 0.0, 0.0, 1.0, 0.0, 20.0, 7.0, 0.0, 24.0)
		add_child(_name)
		_lv = Ui.d("-", 30, Ui.TEXT, 600, 0, true)
		Ui.place(_lv, 0.0, 0.0, 1.0, 1.0, 16.0, 18.0, 0.0, 0.0)
		add_child(_lv)
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func set_level(level: int) -> void:
		_level = level
		_lv.text = str(level) if level >= 0 else "-"
		_refresh()

	func set_selected(on: bool) -> void:
		_selected = on
		_refresh()

	func _refresh() -> void:
		var col: Color = Ui.DIFF_COLORS[_slot]
		if _level < 0:
			Ui.set_color(_name, Ui.TEXT_3)
			Ui.set_color(_lv, Ui.TEXT_3)
		elif _selected:
			Ui.set_color(_name, Color(Ui.INK, 0.75))
			Ui.set_color(_lv, Ui.INK)
		else:
			Ui.set_color(_name, col)
			Ui.set_color(_lv, Ui.TEXT)
		queue_redraw()

	func _process(delta: float) -> void:
		var target: float = 1.0 if _selected and _level >= 0 else 0.0
		if not is_equal_approx(_k, target):
			_k = lerpf(_k, target, 1.0 - exp(-delta * 22.0))
			queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()

	func _draw() -> void:
		var col: Color = Ui.DIFF_COLORS[_slot]
		var skew: float = size.y * Ui.SLANT
		var pts := PackedVector2Array([Vector2(skew, 0.0), Vector2(size.x, 0.0), Vector2(size.x - skew, size.y), Vector2(0.0, size.y)])
		if _level < 0:
			draw_colored_polygon(pts, Color(1, 1, 1, 0.03))
			draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(1, 1, 1, 0.12), 1.0, true)
			return
		draw_colored_polygon(pts, Color(col, 0.1).lerp(col, _k))
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(col, 0.9), 1.5, true)

# ---------------- 곡 휠 ----------------
## 세로 곡 목록. 고른 곡이 가운데 흰 사선 슬랩 위에 오고 위아래 곡은 멀어질수록 흐려진다.
class _Wheel extends Control:
	signal picked(index: int)
	signal confirmed

	const ROW_H := 78.0
	const LEFT := 56.0

	var pulse: float = 0.0
	var _songs: Array = []
	var _rows: Array[Dictionary] = []
	var _index: int = 0
	var _scroll: float = 0.0

	func _ready() -> void:
		clip_contents = true

	func setup(songs: Array) -> void:
		_songs = songs
		for s: Dictionary in songs:
			var row := Control.new()
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.size = Vector2(520.0, ROW_H)
			add_child(row)
			var jacket := Jacket.new()
			jacket.position = Vector2(0.0, 12.0)
			jacket.size = Vector2(54.0, 54.0)
			jacket.set_song(String(s["title"]), String(s["jacket"]))
			row.add_child(jacket)
			var title := Ui.d(String(s["title"]), 24, Ui.TEXT, 600)
			title.position = Vector2(72.0, 11.0)
			title.size = Vector2(236.0, 32.0)
			title.clip_text = true
			row.add_child(title)
			var artist := Ui.t(String(s["artist"]), 13, Ui.TEXT_2)
			artist.position = Vector2(72.0, 43.0)
			artist.size = Vector2(236.0, 22.0)
			artist.clip_text = true
			row.add_child(artist)
			var rank := Ui.d("", 22, Ui.TEXT, 700, 0, true)
			rank.position = Vector2(306.0, 0.0)
			rank.size = Vector2(44.0, ROW_H)
			rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			rank.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(rank)
			var level := Ui.d("", 30, Ui.TEXT, 600, 0, true)
			level.position = Vector2(352.0, 0.0)
			level.size = Vector2(48.0, ROW_H)
			level.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			level.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(level)
			_rows.append({"root": row, "title": title, "artist": artist, "rank": rank, "level": level})
		refresh_levels()

	func select(i: int) -> void:
		_index = i
		refresh_levels()

	func snap() -> void:
		_scroll = float(_index)
		_layout()

	## 고른 난이도(없으면 가까운 난이도)의 레벨과 그 채보의 최고 등급을 줄마다 다시 쓴다
	func refresh_levels() -> void:
		for i in _rows.size():
			var s: Dictionary = _songs[i]
			var slot: int = ChartLoader.nearest_diff(s["diffs"], App.selected_diff)
			var sel: bool = i == _index
			var r: Dictionary = _rows[i]
			var level: Label = r["level"]
			var rank: Label = r["rank"]
			Ui.set_color(r["title"], Ui.INK if sel else Ui.TEXT)
			Ui.set_color(r["artist"], Color(Ui.INK, 0.62) if sel else Ui.TEXT_2)
			if slot < 0:
				level.text = "-"
				rank.text = ""
				continue
			var d: Dictionary = s["diffs"][slot]
			level.text = str(int(d["level"]))
			var col: Color = Ui.DIFF_COLORS[slot]
			Ui.set_color(level, col.darkened(0.45) if sel else col)
			var rec: Dictionary = App.get_record(String(d["path"]))
			rank.text = String(rec["rank"]) if not rec.is_empty() else ""
			Ui.set_color(rank, Color(Ui.INK, 0.7) if sel else Ui.RANK_COLORS.get(rank.text, Ui.TEXT))

	func _process(delta: float) -> void:
		_scroll = lerpf(_scroll, float(_index), 1.0 - exp(-delta * 16.0))
		_layout()
		queue_redraw()

	func _layout() -> void:
		var cy: float = size.y * 0.5
		for i in _rows.size():
			var d: float = float(i) - _scroll
			var root: Control = _rows[i]["root"]
			var near: float = clampf(1.0 - absf(d), 0.0, 1.0)
			root.position = Vector2(LEFT + near * 22.0, cy + d * ROW_H - ROW_H * 0.5)
			root.modulate.a = clampf(1.0 - absf(d) * 0.24, 0.0, 1.0)

	func _draw() -> void:
		var cy: float = size.y * 0.5
		# 줄 자리 안내선
		var n: int = ceili(size.y / ROW_H / 2.0)
		for k in range(-n, n + 1):
			if k == 0 or k == 1:
				continue
			var y: float = cy + (k - 0.5) * ROW_H
			draw_line(Vector2(LEFT, y), Vector2(size.x - 84.0, y), Color(1, 1, 1, 0.05), 1.0)
		if _rows.is_empty():
			return
		var grow: float = pulse * 3.0
		Ui.draw_slab(self, 0.0, size.x - 84.0 + grow, cy - ROW_H * 0.5 + 4.0, cy + ROW_H * 0.5 - 4.0, Ui.TEXT)

	func _gui_input(event: InputEvent) -> void:
		if not event is InputEventMouseButton or not event.pressed or _rows.is_empty():
			return
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				picked.emit(posmod(_index - 1, _rows.size()))
			MOUSE_BUTTON_WHEEL_DOWN:
				picked.emit(posmod(_index + 1, _rows.size()))
			MOUSE_BUTTON_LEFT:
				var i: int = roundi(_scroll + (mb.position.y - size.y * 0.5) / ROW_H)
				if i == _index:
					confirmed.emit()
				elif i >= 0 and i < _rows.size():
					picked.emit(i)
