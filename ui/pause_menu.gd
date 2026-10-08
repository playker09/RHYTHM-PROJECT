class_name PauseMenu
extends CanvasLayer
## 일시정지 메뉴 + 설정(오프셋/감도/배속). 결과 화면에서도 설정만 따로 열 수 있다.
## 슬라이더 값은 즉시 Settings 에 반영/저장된다.

signal resume_requested
signal retry_requested
signal quit_requested
signal settings_changed

const ACCENT := Color(0.35, 0.95, 0.85)

var _menu_box: VBoxContainer
var _settings_box: VBoxContainer
var _title: Label
var _resume_btn: Button
var _rows: Dictionary = {}     # key -> {slider, value}
var _from_result: bool = false

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.02, 0.05, 0.78)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520.0, 0.0)
	panel.add_theme_stylebox_override("panel", Ui.panel_style())
	center.add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	panel.add_child(root)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 34)
	_title.add_theme_color_override("font_color", ACCENT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_title)

	_menu_box = VBoxContainer.new()
	_menu_box.add_theme_constant_override("separation", 10)
	root.add_child(_menu_box)
	_resume_btn = _add_button(_menu_box, "계속하기", func(): resume_requested.emit())
	_add_button(_menu_box, "다시 시작  (R)", func(): retry_requested.emit())
	_add_button(_menu_box, "설정", _show_settings)
	_add_button(_menu_box, "곡 선택으로", func(): quit_requested.emit())

	_settings_box = VBoxContainer.new()
	_settings_box.add_theme_constant_override("separation", 12)
	root.add_child(_settings_box)
	_add_row("offset", "싱크 오프셋 (ms)", -200.0, 200.0, 1.0, Settings.offset_ms, "%+.0f")
	_add_row("sens", "마우스 감도", 0.2, 3.0, 0.05, Settings.sensitivity, "%.2f")
	_add_row("speed", "배속", 0.5, 4.0, 0.1, Settings.hispeed, "%.1f")
	var hint := Label.new()
	hint.text = "오프셋: +면 판정 기준이 앞당겨짐 (노트가 늦게 느껴지면 +)"
	hint.add_theme_font_size_override("font_size", 14)
	hint.modulate = Color(1, 1, 1, 0.55)
	_settings_box.add_child(hint)
	_add_button(_settings_box, "뒤로", _back_from_settings)
	_settings_box.visible = false

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo 			and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if _settings_box.visible and not _from_result:
			_show_menu()
		elif _from_result:
			close()
		else:
			resume_requested.emit()

## 일시정지 메뉴로 열기
func open_pause() -> void:
	_from_result = false
	_title.text = "PAUSE"
	_resume_btn.visible = true
	_show_menu()
	visible = true

## 결과 화면에서 설정만 열기
func open_settings_only() -> void:
	_from_result = true
	_show_settings()
	visible = true

func close() -> void:
	visible = false

func _show_menu() -> void:
	_title.text = "PAUSE"
	_menu_box.visible = true
	_settings_box.visible = false

func _show_settings() -> void:
	_title.text = "SETTINGS"
	_sync_rows()
	_menu_box.visible = false
	_settings_box.visible = true

func _back_from_settings() -> void:
	if _from_result:
		close()
	else:
		_show_menu()

func _sync_rows() -> void:
	_set_row("offset", Settings.offset_ms)
	_set_row("sens", Settings.sensitivity)
	_set_row("speed", Settings.hispeed)

func _set_row(key: String, v: float) -> void:
	var row: Dictionary = _rows[key]
	(row["slider"] as HSlider).set_value_no_signal(v)
	_update_value_label(key, v)

func _add_row(key: String, caption: String, lo: float, hi: float, step: float, v: float, fmt: String) -> void:
	var box := VBoxContainer.new()
	_settings_box.add_child(box)
	var top := HBoxContainer.new()
	box.add_child(top)
	var name_l := Label.new()
	name_l.text = caption
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_l)
	var val_l := Label.new()
	val_l.add_theme_color_override("font_color", ACCENT)
	top.add_child(val_l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.set_value_no_signal(v)
	s.custom_minimum_size = Vector2(0.0, 28.0)
	box.add_child(s)
	_rows[key] = {"slider": s, "value": val_l, "fmt": fmt}
	_update_value_label(key, v)
	s.value_changed.connect(func(nv: float): _on_slider(key, nv))

func _update_value_label(key: String, v: float) -> void:
	var row: Dictionary = _rows[key]
	(row["value"] as Label).text = String(row["fmt"]) % v

func _on_slider(key: String, v: float) -> void:
	match key:
		"offset":
			Settings.offset_ms = v
		"sens":
			Settings.sensitivity = v
		"speed":
			Settings.hispeed = snappedf(v, 0.1)
	Settings.save_settings()
	_update_value_label(key, v)
	settings_changed.emit()

func _add_button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0.0, 46.0)
	b.add_theme_font_size_override("font_size", 22)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b
