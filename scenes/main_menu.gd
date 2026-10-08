extends Control
## 메인 메뉴. 왼쪽 밝은 패널에 선택 항목 제목, 오른쪽 어두운 패널에 목록.

const ITEMS := [
	{"id": "play", "name": "PLAY", "sub": "PICK YOUR SONG", "desc": "곡을 골라 플레이합니다", "no": "01"},
	{"id": "option", "name": "OPTION", "sub": "SET UP YOUR PERSONALITY", "desc": "싱크 오프셋, 감도, 배속 설정", "no": "02"},
	{"id": "quit", "name": "QUIT", "sub": "SEE YOU NEXT TIME", "desc": "게임을 종료합니다", "no": "03"},
]
const ACCENT := Color(0.35, 0.95, 0.75)
const NAVY := Color(0.0, 0.05, 0.35)

var _index: int = 0
var _big: Label
var _big_sub: Label
var _desc: Label
var _mode_no: Label
var _rows: Array[Dictionary] = []
var _settings: PauseMenu
var _busy: bool = false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var left_w: float = 1280.0 * 0.62

	# 왼쪽 밝은 패널
	var grad := Gradient.new()
	grad.set_color(0, Color(0.97, 0.99, 1.0))
	grad.set_color(1, Color(0.72, 0.95, 0.92))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.3, 0.0)
	gt.fill_to = Vector2(0.7, 1.0)
	var light := TextureRect.new()
	light.texture = gt
	light.stretch_mode = TextureRect.STRETCH_SCALE
	light.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	light.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	light.offset_right = left_w
	add_child(light)
	light.add_child(_HudFrame.new())

	_mode_no = _lbl("", 16, NAVY)
	_mode_no.position = Vector2(64.0, 62.0)
	light.add_child(_mode_no)
	_big = _lbl("", 120, NAVY)
	_big.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_big.add_theme_color_override("font_outline_color", Color(0.1, 0.4, 0.95, 0.35))
	_big.add_theme_constant_override("outline_size", 6)
	_big.offset_top = -40.0
	light.add_child(_big)
	_big_sub = _lbl("", 17, NAVY)
	_big_sub.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_big_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big_sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_big_sub.offset_top = 92.0
	light.add_child(_big_sub)
	_desc = _lbl("", 18, NAVY)
	_desc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_desc.offset_top = 132.0
	light.add_child(_desc)

	# 오른쪽 어두운 패널
	var dark_grad := Gradient.new()
	dark_grad.set_color(0, Color(0.02, 0.03, 0.04))
	dark_grad.set_color(1, Color(0.02, 0.2, 0.18))
	var dgt := GradientTexture2D.new()
	dgt.gradient = dark_grad
	dgt.fill_from = Vector2(0.5, 0.2)
	dgt.fill_to = Vector2(0.5, 1.0)
	var dark := TextureRect.new()
	dark.texture = dgt
	dark.stretch_mode = TextureRect.STRETCH_SCALE
	dark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dark.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	dark.offset_left = -(1280.0 - left_w)
	add_child(dark)
	var edge := ColorRect.new()
	edge.color = ACCENT
	edge.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	edge.offset_left = -6.0
	dark.add_child(edge)

	for i in ITEMS.size():
		var row := Control.new()
		row.position = Vector2(80.0, 120.0 + i * 120.0)
		row.size = Vector2(380.0, 90.0)
		dark.add_child(row)
		var n := _lbl(String(ITEMS[i]["name"]), 56, Color(1, 1, 1, 0.85))
		row.add_child(n)
		var s := _lbl(String(ITEMS[i]["sub"]), 15, Color(1, 1, 1, 0.45))
		s.position = Vector2(2.0, 72.0)
		row.add_child(s)
		var hit := Button.new()
		hit.flat = true
		hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hit.focus_mode = Control.FOCUS_NONE
		hit.mouse_entered.connect(func(): _select(i))
		hit.pressed.connect(func(): _select(i); _activate())
		row.add_child(hit)
		_rows.append({"name": n, "sub": s})
	_select(0)

	_settings = PauseMenu.new()
	add_child(_settings)

func _select(i: int) -> void:
	_index = i
	var it: Dictionary = ITEMS[i]
	_big.text = String(it["name"])
	_big_sub.text = "I N T O   " + String(it["sub"])
	_desc.text = String(it["desc"])
	_mode_no.text = "MODE NO.\n" + String(it["no"])
	for k in _rows.size():
		var sel: bool = k == i
		var n: Label = _rows[k]["name"]
		n.add_theme_color_override("font_color", ACCENT if sel else Color(1, 1, 1, 0.8))
		(_rows[k]["sub"] as Label).add_theme_color_override("font_color", ACCENT.darkened(0.2) if sel else Color(1, 1, 1, 0.4))

func _input(event: InputEvent) -> void:
	if _busy or _settings.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).physical_keycode:
			KEY_UP:
				_select(posmod(_index - 1, ITEMS.size()))
			KEY_DOWN:
				_select(posmod(_index + 1, ITEMS.size()))
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_activate()
			KEY_ESCAPE:
				App.goto(App.TITLE_SCENE)

func _activate() -> void:
	match String(ITEMS[_index]["id"]):
		"play":
			_busy = true
			App.goto(App.SELECT_SCENE)
		"option":
			_settings.open_settings_only()
		"quit":
			get_tree().quit()

func _lbl(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

## 밝은 패널의 장식 프레임 (레퍼런스의 HUD 선)
class _HudFrame extends Control:
	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := Color(0.25, 0.4, 0.95, 0.55)
		var s: Vector2 = size
		var m := 36.0
		var cut := 60.0
		draw_polyline(PackedVector2Array([
			Vector2(m, m + cut), Vector2(m + cut, m), Vector2(s.x - m - cut, m),
			Vector2(s.x - m, m + cut), Vector2(s.x - m, s.y - m), Vector2(m, s.y - m), Vector2(m, m + cut)]), c, 1.5)
		draw_circle(Vector2(s.x * 0.5, s.y * 0.5), s.y * 0.30, Color(0.4, 0.55, 1.0, 0.06))
		draw_arc(Vector2(s.x * 0.5, s.y * 0.5), s.y * 0.30, 0.3, 5.5, 64, Color(0.4, 0.55, 1.0, 0.45), 1.5)
		draw_arc(Vector2(s.x * 0.5, s.y * 0.5), s.y * 0.42, 3.6, 8.3, 64, Color(0.4, 0.55, 1.0, 0.3), 1.5)
		for i in 4:
			draw_circle(Vector2(s.x * 0.28 + i * 14.0, s.y * 0.26), 4.0, Color(0.0, 0.2, 0.85, 0.9))
			draw_circle(Vector2(s.x * 0.72 + i * 14.0 - 40.0, s.y * 0.26), 4.0, Color(0.0, 0.2, 0.85, 0.9))
		draw_rect(Rect2(m + 20.0, s.y * 0.34, 18.0, 4.0), Color(0.0, 0.2, 0.85, 0.9))
		draw_rect(Rect2(s.x - m - 100.0, s.y * 0.58, 50.0, 4.0), Color(0.0, 0.2, 0.85, 0.9))
