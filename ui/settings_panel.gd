class_name SettingsPanel
extends CanvasLayer
## 설정 드로어. 어느 화면에서나 오른쪽에서 밀려 나온다. 값은 즉시 저장된다.
## ↑↓ 항목, ←→ 값, Esc 닫기, 마우스 드래그 가능.

signal changed
signal closed

const WIDTH := 560.0
const ROWS := [
	{"key": "section", "name": "플레이"},
	{"key": "speed", "name": "배속", "lo": 0.5, "hi": 4.0, "step": 0.1, "fmt": "%.1f",
		"help": "노트가 내려오는 속도입니다. 플레이 중에도 1, 2 키로 바꿀 수 있습니다."},
	{"key": "offset", "name": "싱크 오프셋", "lo": -200.0, "hi": 200.0, "step": 1.0, "fmt": "%+.0f ms",
		"help": "노트가 소리보다 늦게 느껴지면 + 쪽으로 올리세요."},
	{"key": "sens", "name": "마우스 감도", "lo": 0.2, "hi": 3.0, "step": 0.05, "fmt": "%.2f",
		"help": "공중 커서가 마우스 이동에 반응하는 정도입니다."},
	{"key": "section", "name": "소리 / 화면"},
	{"key": "volume", "name": "음량", "lo": 0.0, "hi": 1.0, "step": 0.05, "fmt": "pct",
		"help": "게임 전체 음량입니다."},
	{"key": "fullscreen", "name": "전체 화면", "toggle": true,
		"help": "F11 또는 Alt+Enter 로도 전환할 수 있습니다."},
]

var _drawer: Control
var _dim: ColorRect
var _rows: Array[_Row] = []
var _index: int = 0
var _help: Label
var _is_open: bool = false

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.015, 0.04, 0.6)
	Ui.place(_dim, 0.0, 0.0, 1.0, 1.0)
	_dim.gui_input.connect(_on_dim_input)
	add_child(_dim)

	_drawer = Control.new()
	Ui.place(_drawer, 1.0, 0.0, 1.0, 1.0, -WIDTH, 0.0, 0.0, 0.0)
	add_child(_drawer)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.043, 0.09, 0.98)
	Ui.place(bg, 0.0, 0.0, 1.0, 1.0)
	_drawer.add_child(bg)
	var edge := _Edge.new()
	Ui.place(edge, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 3.0, 0.0)
	_drawer.add_child(edge)

	var v := Ui.vbox(0)
	Ui.place(v, 0.0, 0.0, 1.0, 1.0, 48.0, 44.0, -48.0, -32.0)
	_drawer.add_child(v)
	v.add_child(Ui.d("설정", 38, Ui.TEXT, 700))
	v.add_child(Ui.gap(14.0))

	for spec in ROWS:
		if String(spec["key"]) == "section":
			v.add_child(Ui.gap(14.0))
			v.add_child(Ui.t(String(spec["name"]), 13, Ui.VIOLET, 700, 1))
			v.add_child(Ui.gap(4.0))
			continue
		var row := _Row.new()
		row.setup(spec)
		row.hovered.connect(_select_row.bind(_rows.size()))
		row.value_set.connect(_on_row_value.bind(String(spec["key"])))
		_rows.append(row)
		v.add_child(row)

	v.add_child(Ui.gap(16.0))
	_help = Ui.t("", 14, Ui.TEXT_2)
	_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help.custom_minimum_size = Vector2(0.0, 44.0)
	v.add_child(_help)
	v.add_child(Ui.expander())
	v.add_child(Ui.hints([["↑↓", "항목"], ["←→", "값 조절"], ["Esc", "닫기"]]))

func open() -> void:
	if _is_open:
		return
	_is_open = true
	visible = true
	_sync()
	_select_row(0)
	App.sfx("confirm")
	_drawer.position.x = 0.0
	_drawer.offset_left = -WIDTH + 60.0
	_drawer.offset_right = 60.0
	_drawer.modulate.a = 0.0
	_dim.modulate.a = 0.0
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_drawer, "offset_left", -WIDTH, 0.22)
	tw.tween_property(_drawer, "offset_right", 0.0, 0.22)
	tw.tween_property(_drawer, "modulate:a", 1.0, 0.16)
	tw.tween_property(_dim, "modulate:a", 1.0, 0.2)

func close() -> void:
	if not _is_open:
		return
	_is_open = false
	App.sfx("back")
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_drawer, "offset_left", -WIDTH + 60.0, 0.14)
	tw.tween_property(_drawer, "offset_right", 60.0, 0.14)
	tw.tween_property(_drawer, "modulate:a", 0.0, 0.14)
	tw.tween_property(_dim, "modulate:a", 0.0, 0.14)
	tw.chain().tween_callback(func():
		visible = false
		closed.emit())

func is_open() -> bool:
	return _is_open

func _input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event is InputEventKey and event.pressed:
		var k := event as InputEventKey
		if k.physical_keycode == KEY_F11 or (k.alt_pressed and k.physical_keycode == KEY_ENTER):
			_sync.call_deferred()
			return
		get_viewport().set_input_as_handled()
		match k.physical_keycode:
			KEY_ESCAPE, KEY_TAB:
				if not k.echo:
					close()
			KEY_UP:
				_select_row(posmod(_index - 1, _rows.size()), true)
			KEY_DOWN:
				_select_row(posmod(_index + 1, _rows.size()), true)
			KEY_LEFT:
				_rows[_index].nudge(-1)
			KEY_RIGHT:
				_rows[_index].nudge(1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if not k.echo:
					_rows[_index].nudge(1)

func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		close()

func _select_row(i: int, with_sound: bool = false) -> void:
	_index = i
	for k in _rows.size():
		_rows[k].set_selected(k == i)
	_help.text = _rows[i].help
	if with_sound:
		App.sfx("move")

func _sync() -> void:
	for r in _rows:
		r.set_value(_read(r.key))

func _read(key: String) -> float:
	match key:
		"speed":
			return Settings.hispeed
		"offset":
			return Settings.offset_ms
		"sens":
			return Settings.sensitivity
		"volume":
			return Settings.volume
		"fullscreen":
			return 1.0 if Settings.fullscreen else 0.0
	return 0.0

func _on_row_value(v: float, key: String) -> void:
	match key:
		"speed":
			Settings.hispeed = snappedf(v, 0.1)
		"offset":
			Settings.offset_ms = v
		"sens":
			Settings.sensitivity = v
		"volume":
			Settings.volume = v
			Settings.apply_audio()
		"fullscreen":
			Settings.fullscreen = v > 0.5
			Settings.apply_window()
	Settings.save_settings()
	changed.emit()

## 드로어 왼쪽 그라데이션 테두리
class _Edge extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)]),
			PackedColorArray([Ui.VIOLET, Ui.VIOLET, Ui.MAGENTA, Ui.MAGENTA]))

## 설정 한 줄 (슬라이더 또는 토글)
class _Row extends Control:
	signal hovered
	signal value_set(v: float)

	var key: String = ""
	var help: String = ""
	var _lo: float = 0.0
	var _hi: float = 1.0
	var _step: float = 0.1
	var _fmt: String = "%.1f"
	var _toggle: bool = false
	var _value: float = 0.0
	var _selected: bool = false
	var _shown: float = 0.0
	var _name: Label
	var _val: Label
	var _dragging: bool = false

	func setup(spec: Dictionary) -> void:
		key = String(spec["key"])
		help = String(spec.get("help", ""))
		_toggle = bool(spec.get("toggle", false))
		_lo = float(spec.get("lo", 0.0))
		_hi = float(spec.get("hi", 1.0))
		_step = float(spec.get("step", 1.0))
		_fmt = String(spec.get("fmt", ""))
		custom_minimum_size = Vector2(0.0, 58.0)
		_name = Ui.t(String(spec["name"]), 17, Ui.TEXT_2, 500)
		Ui.place(_name, 0.0, 0.0, 0.6, 0.0, 14.0, 7.0, 0.0, 34.0)
		add_child(_name)
		_val = Ui.d("", 19, Ui.TEXT, 600)
		_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		Ui.place(_val, 0.5, 0.0, 1.0, 0.0, 0.0, 6.0, -14.0, 34.0)
		add_child(_val)
		mouse_entered.connect(func(): hovered.emit())

	func set_value(v: float) -> void:
		_value = v
		_shown = _frac()
		_refresh()

	func set_selected(on: bool) -> void:
		_selected = on
		Ui.set_color(_name, Ui.TEXT if on else Ui.TEXT_2)
		queue_redraw()

	func nudge(dir: int) -> void:
		if _toggle:
			_commit(0.0 if _value > 0.5 else 1.0)
		else:
			_commit(_value + dir * _step)
		App.sfx("move")

	func _commit(v: float) -> void:
		var nv: float = clampf(snappedf(v, _step) if not _toggle else v, _lo, _hi)
		if nv == _value:
			return
		_value = nv
		_refresh()
		value_set.emit(nv)

	func _frac() -> float:
		return (_value - _lo) / maxf(_hi - _lo, 0.001)

	func _refresh() -> void:
		if _toggle:
			_val.text = "켜짐" if _value > 0.5 else "꺼짐"
			Ui.set_color(_val, Ui.CYAN if _value > 0.5 else Ui.TEXT_2)
		elif _fmt == "pct":
			_val.text = "%d%%" % roundi(_value * 100.0)
		else:
			_val.text = _fmt % _value
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var mb := event as InputEventMouseButton
			_dragging = mb.pressed and not _toggle
			if mb.pressed:
				if _toggle:
					nudge(1)
				else:
					_drag_to(mb.position.x)
		elif event is InputEventMouseMotion and _dragging:
			_drag_to((event as InputEventMouseMotion).position.x)

	func _drag_to(x: float) -> void:
		var k: float = clampf((x - 14.0) / maxf(size.x - 28.0, 1.0), 0.0, 1.0)
		_commit(lerpf(_lo, _hi, k))

	func _process(delta: float) -> void:
		var target: float = _frac()
		if absf(_shown - target) > 0.001:
			_shown = lerpf(_shown, target, 1.0 - exp(-delta * 22.0))
			queue_redraw()

	func _draw() -> void:
		if _selected:
			draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.055))
			draw_rect(Rect2(0.0, 0.0, 3.0, size.y), Ui.CYAN)
		if _toggle:
			return
		var y: float = size.y - 13.0
		var w: float = size.x - 28.0
		draw_rect(Rect2(14.0, y, w, 2.0), Color(1, 1, 1, 0.14))
		var fx: float = w * _shown
		draw_rect(Rect2(14.0, y, fx, 2.0), Ui.CYAN if _selected else Ui.TEXT_2)
		var kx: float = 14.0 + fx
		draw_colored_polygon(PackedVector2Array([
			Vector2(kx, y - 6.0), Vector2(kx + 6.0, y + 1.0), Vector2(kx, y + 8.0), Vector2(kx - 6.0, y + 1.0)]),
			Ui.CYAN if _selected else Ui.TEXT)
