extends Node2D

var hit_time: float
var lane: int
var judged := false

var spawn_y := Global.SPAWN_Y
var judgement_y := Global.JUDGEMENT_Y


func setup(note_time: float, note_lane: int) -> void:
	hit_time = note_time
	lane = note_lane

	var screen_width := get_viewport_rect().size.x

	if lane == Global.Lane.LEFT:
		position.x = screen_width * 0.25
	else:
		position.x = screen_width * 0.75

	position.y = spawn_y

	queue_redraw()


func update_position(song_time: float) -> void:
	if judged:
		return

	var remaining_time := hit_time - song_time

	var progress := 1.0 - (
		remaining_time / Global.APPROACH_TIME
	)

	progress = clamp(progress, 0.0, 1.0)

	position.y = lerp(
		spawn_y,
		judgement_y,
		progress
	)


func mark_judged() -> void:
	judged = true
	queue_free()


func _draw() -> void:
	draw_rect(
		Rect2(-45, -20, 90, 40),
		Color.WHITE
	)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
