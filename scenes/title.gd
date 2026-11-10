extends Control
## 타이틀 화면. 게임과 같은 3D 무대(일식을 향해 뻗은 길) 위에 워드마크를 올린다. 아무 키나 누르면 메인 메뉴로.

var _world: MenuWorld
var _logo: Control
var _press: Control
var _leaving: bool = false
var _t: float = 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	App.bgm_play("menu")
	_world = MenuWorld.new("title")
	add_child(_world)
	_build_logo()
	_build_press()
	_build_footer()

func _build_logo() -> void:
	var words: PackedStringArray = String(ProjectSettings.get_setting("application/config/name", "RHYTHM")).to_upper().split(" ", false)
	var main_word: String = words[0] if words.size() > 0 else "RHYTHM"
	var rest: String = " ".join(words.slice(1))

	_logo = Control.new()
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.place(_logo, 0.0, 0.42, 1.0, 0.42, 0.0, -130.0, 0.0, 130.0)
	add_child(_logo)

	var tag := Ui.caption("4 KEYS   ·   AIR FIELD   ·   FLICK", Ui.TEXT_2, 13)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Ui.place(tag, 0.0, 0.0, 1.0, 0.0, 0.0, 18.0, 0.0, 40.0)
	_logo.add_child(tag)

	var big := Ui.d(main_word, 132, Ui.TEXT, 700, 14, true)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Ui.gradient(big, Color(1, 1, 1), Color(0.8, 0.74, 1.0), 170.0)
	Ui.place(big, 0.0, 0.0, 1.0, 0.0, 0.0, 34.0, 0.0, 200.0)
	_logo.add_child(big)

	# 워드마크 아래: 가는 선 사이에 넓은 자간의 둘째 단어
	var row := Ui.hbox(22)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	Ui.place(row, 0.0, 0.0, 1.0, 0.0, 0.0, 196.0, 0.0, 232.0)
	_logo.add_child(row)
	row.add_child(_line(150.0, true))
	if rest != "":
		row.add_child(Ui.d(rest, 24, Ui.TEXT, 500, 18))
	row.add_child(_line(150.0, false))

	Ui.reveal(tag, 0.9, 0.8)
	Ui.reveal(row, 0.6, 0.8)
	big.modulate.a = 0.0
	big.pivot_offset = Vector2(get_viewport_rect().size.x * 0.5, 80.0)
	big.scale = Vector2(1.12, 1.12)
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.tween_property(big, "modulate:a", 1.0, 0.9).set_delay(0.15)
	tw.tween_property(big, "scale", Vector2.ONE, 1.6).set_delay(0.15)

## 한쪽 끝이 사라지는 가는 선
func _line(w: float, fade_left: bool) -> Control:
	var l := _FadeLine.new()
	l.fade_left = fade_left
	l.custom_minimum_size = Vector2(w, 2.0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l

func _build_press() -> void:
	_press = Ui.hbox(18)
	(_press as HBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	Ui.place(_press, 0.0, 0.84, 1.0, 0.84, 0.0, -16.0, 0.0, 16.0)
	add_child(_press)
	_press.add_child(_line(60.0, true))
	var l := Ui.d("PRESS ANY KEY", 17, Ui.TEXT, 600, 8)
	Ui.shadow(l, 0.7, 8)
	_press.add_child(l)
	_press.add_child(_line(60.0, false))
	Ui.reveal(_press, 1.5, 0.6)

func _build_footer() -> void:
	var foot := Ui.hbox(0)
	Ui.place(foot, 0.0, 1.0, 1.0, 1.0, 40.0, -44.0, -40.0, -18.0)
	add_child(foot)
	var ver: String = String(ProjectSettings.get_setting("application/config/version", ""))
	foot.add_child(Ui.caption(("VER " + ver) if ver != "" else "", Ui.TEXT_3, 11))
	foot.add_child(Ui.expander())
	foot.add_child(Ui.hints([["F11", "전체 화면"]]))
	Ui.reveal(foot, 1.8, 0.6)

func _process(delta: float) -> void:
	_t += delta
	if _t > 2.1 and not _leaving:
		_press.modulate.a = 0.55 + 0.45 * sin(_t * 3.2)

func _input(event: InputEvent) -> void:
	if _leaving or _t < 0.5:
		return
	var go: bool = false
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.physical_keycode == KEY_F11 or k.alt_pressed:
			return
		if k.physical_keycode == KEY_ESCAPE:
			return
		go = true
	elif event is InputEventMouseButton and event.pressed:
		go = true
	if go:
		_leaving = true
		get_viewport().set_input_as_handled()
		App.sfx("start", 0.55)
		_press.modulate.a = 1.0
		var tw := create_tween()
		tw.tween_property(_press, "modulate:a", 0.0, 0.08)
		tw.tween_property(_press, "modulate:a", 1.0, 0.08)
		tw.set_loops(2)
		App.goto(App.MENU_SCENE)

class _FadeLine extends Control:
	var fade_left: bool = true
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var a := Color(1, 1, 1, 0.0)
		var b := Color(1, 1, 1, 0.75)
		var l: Color = a if fade_left else b
		var r: Color = b if fade_left else a
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), Vector2(size.x, 1.5), Vector2(0.0, 1.5)]),
			PackedColorArray([l, r, r, l]))
