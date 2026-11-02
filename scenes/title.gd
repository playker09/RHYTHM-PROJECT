extends Control
## 타이틀 화면. 아무 키나 누르면 메인 메뉴로.

const BG_SHADER := preload("res://ui/shaders/title_bg.gdshader")

var _prompt: Label
var _t: float = 0.0
var _go: bool = false
var _bg_mat: ShaderMaterial

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bg := ColorRect.new()
	_bg_mat = ShaderMaterial.new()
	_bg_mat.shader = BG_SHADER
	_bg_mat.set_shader_parameter("reveal", 0.0)
	bg.material = _bg_mat
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Ui.place(bg, 0.0, 0.0, 1.0, 1.0)
	add_child(bg)

	var logo := Ui.vbox(0)
	Ui.place(logo, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0)
	logo.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(logo)
	logo.add_child(Ui.gap(112.0))
	var mark := _LogoMark.new()
	mark.custom_minimum_size = Vector2(0.0, 54.0)
	logo.add_child(mark)
	logo.add_child(Ui.gap(8.0))
	var title := Ui.d("RHYTHM PROJECT", 80, Ui.TEXT, 700, 8, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Ui.gradient(title, Ui.TEXT, Color("c6bcff"), 100.0)
	logo.add_child(title)

	_prompt = Ui.d("PRESS ANY KEY", 17, Ui.TEXT, 500, 6)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Ui.place(_prompt, 0.0, 1.0, 1.0, 1.0, 0.0, -84.0, 0.0, -50.0)
	add_child(_prompt)

	logo.modulate.a = 0.0
	_prompt.modulate.a = 0.0
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float): _bg_mat.set_shader_parameter("reveal", v), 0.0, 1.0, 1.0)
	tw.tween_property(logo, "modulate:a", 1.0, 0.8).set_delay(0.25)

func _process(delta: float) -> void:
	_t += delta
	if _t > 1.0:
		_prompt.modulate.a = 0.55 + 0.45 * sin((_t - 1.0) * 2.6)

func _input(event: InputEvent) -> void:
	if _go:
		return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed)
	if not pressed:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.physical_keycode == KEY_ESCAPE:
			get_tree().quit()
			return
		if k.physical_keycode == KEY_F11 or k.alt_pressed:
			return
	_go = true
	App.sfx("confirm")
	App.goto(App.MENU_SCENE)

## 로고 마크: 4레인 막대 + 공중 호
class _LogoMark extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y)
		var w := 5.0
		var gap := 13.0
		var heights := [18.0, 30.0, 30.0, 18.0]
		for i in 4:
			var x: float = c.x + (i - 1.5) * gap
			var col: Color = Ui.VIOLET.lerp(Ui.MAGENTA, float(i) / 3.0)
			draw_rect(Rect2(x - w * 0.5, c.y - heights[i], w, heights[i]), col.lightened(0.3))
		draw_arc(c + Vector2(0.0, 6.0), 44.0, deg_to_rad(205.0), deg_to_rad(335.0), 48, Ui.TEXT, 2.0, true)
