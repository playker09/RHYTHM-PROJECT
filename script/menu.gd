class_name RhythmMenu
extends CanvasLayer

signal start_requested
signal settings_changed

var _root: Control
var _content: VBoxContainer

func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.025, 0.04, 0.08, 0.94)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dimmer)
	_content = VBoxContainer.new()
	_content.set_anchors_preset(Control.PRESET_CENTER)
	_content.position = Vector2(-210, -170)
	_content.size = Vector2(420, 340)
	_content.add_theme_constant_override("separation", 14)
	_root.add_child(_content)

func hide_menu() -> void:
	visible = false

func show_start_screen() -> void:
	visible = true
	_clear_page()
	_add_title("RHYTHM PROJECT")
	_add_label("Move the mouse to select a lane.  D / F to hit notes.")
	_add_button("START", show_song_select)
	_add_button("SETTINGS", show_settings)

func show_song_select() -> void:
	visible = true
	_clear_page()
	_add_title("SELECT SONG")
	var songs := OptionButton.new()
	songs.add_item("JACKPOT")
	songs.select(0)
	songs.custom_minimum_size.y = 42
	_content.add_child(songs)
	_add_label("BPM 103   •   Test chart")
	_add_button("PLAY", func():
		Global.selected_song = songs.get_item_text(songs.selected)
		start_requested.emit())
	_add_button("BACK", show_start_screen)

func show_settings() -> void:
	visible = true
	_clear_page()
	_add_title("SETTINGS")
	_add_setting("Timing offset (ms)", Global.timing_offset_ms, -300.0, 300.0, 1.0, func(value: float): Global.timing_offset_ms = value)
	_add_setting("Note fall speed", Global.note_speed, 0.5, 6.0, 0.25, func(value: float): Global.note_speed = value)
	_add_setting("Master volume (dB)", Global.master_volume_db, -40.0, 0.0, 1.0, func(value: float): Global.master_volume_db = value)
	_add_button("APPLY AND BACK", func():
		settings_changed.emit()
		show_start_screen())

func _clear_page() -> void:
	for child in _content.get_children(): child.queue_free()

func _add_title(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 34)
	_content.add_child(label)

func _add_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(label)

func _add_button(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.pressed.connect(action)
	_content.add_child(button)

func _add_setting(label_text: String, value: float, minimum: float, maximum: float, step: float, on_changed: Callable) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.value = value
	spin.custom_minimum_size.x = 115
	spin.value_changed.connect(on_changed)
	row.add_child(spin)
	_content.add_child(row)
