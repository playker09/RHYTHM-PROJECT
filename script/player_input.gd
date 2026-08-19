class_name PlayerInput
extends Node

signal normal_note_pressed(lane: Global.Lane)
signal slide_performed(direction: Global.Lane)
signal lane_changed(lane: Global.Lane)
var _previous_lane: Global.Lane = Global.Lane.LEFT

func _ready() -> void:
	_update_lane_from_pointer()

func _process(_delta: float) -> void:
	_update_lane_from_pointer()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_D: normal_note_pressed.emit(Global.Lane.LEFT)
		elif event.keycode == KEY_F: normal_note_pressed.emit(Global.Lane.RIGHT)

func _update_lane_from_pointer() -> void:
	var viewport := get_viewport()
	var lane: Global.Lane = Global.Lane.LEFT if viewport.get_mouse_position().x < viewport.get_visible_rect().size.x * 0.5 else Global.Lane.RIGHT
	if lane == _previous_lane: return
	_previous_lane = lane
	Global.current_lane = lane
	lane_changed.emit(lane)
	slide_performed.emit(lane)
