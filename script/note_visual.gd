class_name NoteVisual
extends Node2D

var data: Dictionary
var target_time := 0.0
var approach_time := 2.0
var judgement_y := 0.0
var spawn_y := -55.0

func setup(note_data: Dictionary, viewport_size: Vector2, configured_approach_time: float) -> void:
	data = note_data
	target_time = float(data.target_time)
	approach_time = configured_approach_time
	judgement_y = viewport_size.y - 110.0
	position.x = viewport_size.x * (0.5 if int(data.type) == RhythmChart.NoteType.SLIDE else (0.25 if int(data.lane) == Global.Lane.LEFT else 0.75))
	queue_redraw()

func update_for_time(song_time: float) -> void:
	position.y = lerpf(spawn_y, judgement_y, clampf(1.0 - (target_time - song_time) / approach_time, 0.0, 1.0))

func _draw() -> void:
	if int(data.type) == RhythmChart.NoteType.SLIDE:
		var right := int(data.direction) == Global.Lane.RIGHT
		var points := PackedVector2Array([Vector2(-54, 0), Vector2(0, -26), Vector2(54, 0), Vector2(0, 26)])
		draw_colored_polygon(points, Color("ffba4d") if right else Color("c08cff"))
		draw_string(ThemeDB.fallback_font, Vector2(-7, 7), "→" if right else "←", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	else:
		draw_circle(Vector2.ZERO, 31.0, Color("5caeff") if int(data.lane) == Global.Lane.LEFT else Color("ff6575"))
		draw_circle(Vector2.ZERO, 19.0, Color.WHITE)
