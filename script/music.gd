extends AudioStreamPlayer2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
var song_time: float = 0.0


func _process(_delta: float) -> void:
	if playing:
		song_time = get_playback_position()
	else:
		song_time = 0.0


func get_song_time() -> float:
	return song_time


func start_music() -> void:
	play()
	song_time = 0.0


func stop_music() -> void:
	stop()
	song_time = 0.0


func restart_music() -> void:
	stop()
	play()
	song_time = 0.0
