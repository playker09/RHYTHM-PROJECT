class_name SettingsPanel
extends CanvasLayer
## 설정 드로어. 어느 화면에서나 오른쪽에서 밀려 나온다. 값은 즉시 저장된다.
## ↑↓ 항목, ←→ 값, Esc 닫기, 마우스 드래그 가능.

signal changed
signal closed

const WIDTH := 540.0
const ROWS := [
	{"key": "section", "name": "PLAY", "sub": "플레이"},
	{"key": "speed", "name": "배속", "lo": 0.5, "hi": 4.0, "step": 0.1, "fmt": "%.1f",
		"help": "노트가 내려오는 속도입니다. 플레이 중에도 1, 2 키로 바꿀 수 있습니다."},
	{"key": "offset", "name": "싱크 오프셋", "lo": -200.0, "hi": 200.0, "step": 1.0, "fmt": "%+.0f ms",
		"help": "노트가 소리보다 늦게 느껴지면 + 쪽으로 올리세요."},
	{"key": "sens", "name": "마우스 감도", "lo": 0.2, "hi": 3.0, "step": 0.05, "fmt": "%.2f",
		"help": "공중 커서가 마우스 이동에 반응하는 정도입니다."},
	{"key": "section", "name": "AUDIO / DISPLAY", "sub": "소리 / 화면"},
	{"key": "volume", "name": "전체 음량", "lo": 0.0, "hi": 1.0, "step": 0.05, "fmt": "pct",
		"help": "게임 전체 음량입니다."},
	{"key": "hit", "name": "타격음", "lo": 0.0, "hi": 1.0, "step": 0.05, "fmt": "pct",
		"help": "노트를 맞혔을 때 나는 소리의 크기입니다. 0% 로 두면 꺼집니다."},
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
	_dim.color = Color(0.02, 0.015, 0.04, 0.5)
	Ui.place(_dim, 0.0, 0.0, 1.0, 1.0)
	_dim.gui_input.connect(_on_dim_input)
	add_child(_dim)

	_drawer = Control.new()
	Ui.place(_drawer, 1.0, 0.0, 1.0, 1.0, -WIDTH, 0.0, 0.0, 0.0)
	add_child(_drawer)
	var bg := Ui.backdrop(3.5, Color(0.04, 0.034, 0.08, 0.86))
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_drawer.add_child(bg)
	var edge := _Edge.new()
	Ui.place(edge, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 2.0, 0.0)
	_drawer.add_child(edge)

	var v := Ui.vbox(0)
	Ui.place(v, 0.0, 0.0, 1.0, 1.0, 44.0, 40.0, -44.0, -30.0)
	_drawer.add_child(v)
	v.add_child(Ui.caption("SETTINGS", Ui.VIOLET, 13))
	v.add_child(Ui.t("설정", 36, Ui.TEXT, 700))
	v.add_child(Ui.gap(4.0))

	for spec in ROWS:
		if String(spec["key"]) == "section":
			v.add_child(Ui.gap(16.0))
			var head := Ui.hbox(10)
			v.add_child(head)
			head.add_child(Ui.caption(String(spec["name"]), Ui.TEXT_2, 12))
			var line := Ui.rule(Ui.LINE_SOFT)
			line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			head.add_child(line)
			v.add_child(Ui.gap(4.0))
			continue
		var row := _Row.new()
		row.setup(spec)
		row.hovered.connect(_select_row.bind(_rows.size()))
		row.value_set.connect(_on_row_value.bind(String(spec["key"])))
		_rows.append(row)
		v.add_child(row)

	v.add_child(Ui.gap(16.0))
	_help = Ui.t("", 13, Ui.TEXT_2)
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
	_drawer.offset_left = -WIDTH + 80.0
	_drawer.offset_right = 80.0
	_drawer.modulate.a = 0.0
	_dim.modulate.a = 0.0
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.tween_property(_drawer, "offset_left", -WIDTH, 0.3)
	tw.tween_property(_drawer, "offset_right", 0.0, 0.3)
	tw.tween_property(_drawer, "modulate:a", 1.0, 0.16)
	tw.tween_property(_dim, "modulate:a", 1.0, 0.2)

func close() -> void:
	if not _is_open:
		return
	_is_open = false
	App.sfx("back")
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_drawer, "offset_left", -WIDTH + 80.0, 0.14)
	tw.tween_property(_drawer, "offset_right", 80.0, 0.14)
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
		"hit":
			return Settings.hit_volume
		"fullscreen":
			return 1.0 if Settings.fullscreen else 0.0
	return 0.0

func _on_row_value(v: float, key: String) -> void:
	match key:
		"speed":
			Settings.hispeed = v
		"offset":
			Settings.offset_ms = v
		"sens":
			Settings.sensitivity = v
		"volume":
			Settings.volume = v
			Settings.apply_audio()
		"hit":
			Settings.hit_volume = v
			App.sfx("hit_tap", v)
		"fullscreen":
			Settings.fullscreen = v > 0.5
			Settings.apply_window()
	Settings.save_settings()
	if key != "hit":
		App.sfx("tab", 0.3)
	changed.emit()

## 드로어 왼쪽 가장자리의 보라→자홍 선
class _Edge extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)]),
			PackedColorArray([Ui.VIOLET, Ui.VIOLET, Ui.MAGENTA, Ui.MAGENTA]))

## 설정 한 줄: 이름 + 값 + 슬라이더(또는 토글)
class _Row extends Control:
	signal hovered
	signal value_set(v: float)

	const H := 58.0

	var key: String = ""
	var help: String = ""
	var _spec: Dictionary = {}
	var _value: float = 0.0
	var _selected: bool = false
	var _name: Label
	var _val: Label
	var _drag: bool = false
	var _glow: float = 0.0

	func setup(spec: Dictionary) -> void:
		_spec = spec
		key = String(spec["key"])
		help = String(spec.get("help", ""))
		custom_minimum_size = Vector2(0.0, H)
		_name = Ui.t(String(spec["name"]), 17, Ui.TEXT_2, 500)
		Ui.place(_name, 0.0, 0.0, 0.6, 0.0, 16.0, 6.0, 0.0, 34.0)
		add_child(_name)
		_val = Ui.d("", 19, Ui.TEXT, 600, 1)
		_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		Ui.place(_val, 0.4, 0.0, 1.0, 0.0, 0.0, 5.0, -16.0, 34.0)
		add_child(_val)
		mouse_entered.connect(func(): hovered.emit())

	func is_toggle() -> bool:
		return bool(_spec.get("toggle", false))

	func set_selected(on: bool) -> void:
		_selected = on
		Ui.set_color(_name, Ui.TEXT if on else Ui.TEXT_2)
		queue_redraw()

	func set_value(v: float) -> void:
		_value = v
		if is_toggle():
			_val.text = "ON" if v > 0.5 else "OFF"
			Ui.set_color(_val, Ui.CYAN if v > 0.5 else Ui.TEXT_3)
		elif String(_spec["fmt"]) == "pct":
			_val.text = "%d%%" % roundi(v * 100.0)
		else:
			_val.text = String(_spec["fmt"]) % v
		queue_redraw()

	func nudge(dir: int) -> void:
		if is_toggle():
			_commit(0.0 if _value > 0.5 else 1.0)
		else:
			_commit(_value + float(_spec["step"]) * dir)

	func _commit(v: float) -> void:
		if not is_toggle():
			v = clampf(snappedf(v, float(_spec["step"])), float(_spec["lo"]), float(_spec["hi"]))
		if is_equal_approx(v, _value):
			return
		set_value(v)
		_glow = 1.0
		value_set.emit(v)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var mb := event as InputEventMouseButton
			if is_toggle():
				if mb.pressed:
					nudge(1)
				return
			_drag = mb.pressed
			if _drag:
				_set_from_x(mb.position.x)
		elif event is InputEventMouseMotion and _drag:
			_set_from_x((event as InputEventMouseMotion).position.x)

	func _set_from_x(x: float) -> void:
		var u: float = clampf((x - 16.0) / maxf(size.x - 32.0, 1.0), 0.0, 1.0)
		_commit(lerpf(float(_spec["lo"]), float(_spec["hi"]), u))

	func _process(delta: float) -> void:
		if _glow > 0.0:
			_glow = maxf(_glow - delta * 3.0, 0.0)
			queue_redraw()

	func _draw() -> void:
		if _selected:
			draw_rect(Rect2(0.0, 2.0, size.x, size.y - 4.0), Color(1, 1, 1, 0.055))
			draw_rect(Rect2(0.0, 2.0, 3.0, size.y - 4.0), Ui.TEXT)
		if is_toggle():
			return
		var x0: float = 16.0
		var w: float = size.x - 32.0
		var y: float = size.y - 14.0
		var u: float = inverse_lerp(float(_spec["lo"]), float(_spec["hi"]), _value)
		draw_rect(Rect2(x0, y, w, 2.0), Color(1, 1, 1, 0.12))
		if w * u > 0.5:
			draw_polygon(PackedVector2Array([Vector2(x0, y), Vector2(x0 + w * u, y), Vector2(x0 + w * u, y + 2.0), Vector2(x0, y + 2.0)]),
				PackedColorArray([Ui.VIOLET, Ui.MAGENTA, Ui.MAGENTA, Ui.VIOLET]))
		# 손잡이 (마름모)
		var c := Vector2(x0 + w * u, y + 1.0)
		var r: float = 6.0 if _selected else 4.5
		var col: Color = Ui.TEXT.lerp(Ui.CYAN, _glow)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -r), c + Vector2(r, 0.0), c + Vector2(0.0, r), c + Vector2(-r, 0.0)]), col)
		# 오프셋처럼 0 이 가운데인 항목은 0 위치 눈금
		if float(_spec["lo"]) < 0.0:
			var zx: float = x0 + w * inverse_lerp(float(_spec["lo"]), float(_spec["hi"]), 0.0)
			draw_rect(Rect2(zx - 0.5, y - 4.0, 1.0, 10.0), Color(1, 1, 1, 0.3))
