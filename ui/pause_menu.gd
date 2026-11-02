class_name PauseMenu
extends CanvasLayer
## 일시정지 메뉴. 설정은 SettingsPanel 을 띄운다.

signal resume_requested
signal retry_requested
signal quit_requested
signal settings_changed

var _root: Control
var _list: MenuList
var _settings: SettingsPanel

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_root = Control.new()
	Ui.place(_root, 0.0, 0.0, 1.0, 1.0)
	add_child(_root)
	_root.add_child(Ui.backdrop(3.2))

	var head := Ui.vbox(2)
	Ui.place(head, 0.0, 0.5, 1.0, 0.5, 72.0, -210.0, 0.0, -130.0)
	_root.add_child(head)
	head.add_child(Ui.d("일시정지", 44, Ui.TEXT, 700))

	_list = MenuList.new()
	_list.setup([
		{"id": "resume", "name": "계속하기"},
		{"id": "retry", "name": "다시 시작", "sub": "R"},
		{"id": "settings", "name": "설정"},
		{"id": "quit", "name": "곡 선택으로"},
	], 34, 60.0)
	Ui.place(_list, 0.0, 0.5, 1.0, 0.5, 0.0, -120.0, 0.0, 120.0)
	_root.add_child(_list)
	_list.activated.connect(_on_activated)

	var foot := Ui.hints([["↑↓", "선택"], ["Enter", "확인"], ["Esc", "계속하기"]])
	Ui.place(foot, 0.0, 1.0, 1.0, 1.0, 72.0, -56.0, 0.0, -24.0)
	_root.add_child(foot)

	_settings = SettingsPanel.new()
	add_child(_settings)
	_settings.changed.connect(func(): settings_changed.emit())

func _input(event: InputEvent) -> void:
	if not visible or _settings.is_open():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.physical_keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			App.sfx("back")
			resume_requested.emit()
		elif k.physical_keycode == KEY_R:
			get_viewport().set_input_as_handled()
			retry_requested.emit()
		elif _list.handle_key(k):
			get_viewport().set_input_as_handled()

func open_pause() -> void:
	visible = true
	_list.select(0, false)
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.12)

func close() -> void:
	visible = false

func _on_activated(id: String) -> void:
	match id:
		"resume":
			App.sfx("confirm")
			resume_requested.emit()
		"retry":
			App.sfx("confirm")
			retry_requested.emit()
		"settings":
			_settings.open()
		"quit":
			App.sfx("back")
			quit_requested.emit()
