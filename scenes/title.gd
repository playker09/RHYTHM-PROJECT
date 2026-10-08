extends Control
## 타이틀 화면. 아무 키나 누르면 메인 메뉴로.

var _prompt: Label
var _t: float = 0.0
var _go: bool = false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	add_child(NightBg.new())

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	center.add_child(v)

	var studio := _lbl("S T U D I O", 22, Color(0.82, 0.82, 0.95))
	studio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(studio)
	v.add_child(_spacer(46))

	var logo := _lbl("RHYTHM PROJECT", 84, Color(0.86, 0.86, 1.0))
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_theme_constant_override("outline_size", 4)
	logo.add_theme_color_override("font_outline_color", Color(0.4, 0.3, 0.8, 0.6))
	v.add_child(logo)
	var sub := _lbl("4 Lane + Air Field", 26, Color(1.0, 0.35, 0.55))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	v.add_child(_spacer(70))

	_prompt = _lbl("PRESS ANY KEY TO START", 26, Color.WHITE)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_prompt)

	var copy := _lbl("v0.5  -  Godot 4.7", 15, Color(1, 1, 1, 0.55))
	copy.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	copy.offset_top = -40.0
	copy.offset_left = -200.0
	copy.offset_right = 200.0
	copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(copy)

func _process(delta: float) -> void:
	_t += delta
	_prompt.modulate.a = 0.55 + 0.45 * sin(_t * 3.0)

func _input(event: InputEvent) -> void:
	if _go:
		return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed)
	if not pressed:
		return
	if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		get_tree().quit()
		return
	_go = true
	App.goto(App.MENU_SCENE)

func _lbl(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0.0, h)
	return c
