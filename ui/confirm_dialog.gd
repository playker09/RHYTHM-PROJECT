class_name ConfirmDialog
extends CanvasLayer
## 예/아니오 확인 창. 화면을 가리고 가운데 왼쪽에 질문과 선택지를 띄운다(일시정지 메뉴와 같은 생김새).
## ↑↓ 선택, Enter 확인, Esc = 아니오.

signal answered(yes: bool)

var _root: Control
var _cap: Label
var _title: Label
var _body: Label
var _list: MenuList
var _is_open: bool = false

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_root = Control.new()
	Ui.place(_root, 0.0, 0.0, 1.0, 1.0)
	add_child(_root)
	var veil := Ui.backdrop(3.2, Color(0.03, 0.025, 0.06, 0.74))
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(veil)

	var head := Ui.vbox(2)
	Ui.place(head, 0.0, 0.5, 1.0, 0.5, 72.0, -190.0, -72.0, -60.0)
	_root.add_child(head)
	_cap = Ui.caption("", Ui.VIOLET, 14)
	head.add_child(_cap)
	_title = Ui.t("", 40, Ui.TEXT, 700)
	head.add_child(_title)
	_body = Ui.t("", 15, Ui.TEXT_2)
	head.add_child(_body)

	_list = MenuList.new()
	_list.setup([
		{"id": "yes", "name": "예"},
		{"id": "no", "name": "아니오"},
	], 32, 58.0, false)
	Ui.place(_list, 0.0, 0.5, 1.0, 0.5, 0.0, -40.0, 0.0, 76.0)
	_root.add_child(_list)
	_list.activated.connect(func(id: String): _answer(id == "yes"))

	var foot := Ui.hints([["↑↓", "선택"], ["Enter", "확인"], ["Esc", "아니오"]])
	Ui.place(foot, 0.0, 1.0, 1.0, 1.0, 72.0, -60.0, 0.0, -28.0)
	_root.add_child(foot)

func open(caption: String, title: String, body: String = "") -> void:
	_cap.text = caption
	_title.text = title
	_body.text = body
	_is_open = true
	visible = true
	_list.select(0, false)
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.2)

func is_open() -> bool:
	return _is_open

func _input(event: InputEvent) -> void:
	if not _is_open or App.is_busy():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.physical_keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_answer(false)
		elif _list.handle_key(k):
			get_viewport().set_input_as_handled()

func _answer(yes: bool) -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	App.sfx("confirm" if yes else "back")
	answered.emit(yes)
