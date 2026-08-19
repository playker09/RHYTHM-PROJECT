class_name RhythmMusicPlayer
extends AudioStreamPlayer

signal playback_started
signal playback_paused
signal playback_stopped
var _paused_position := 0.0

func play_song(from_position := 0.0) -> void:
	play(from_position)
	_paused_position = from_position
	playback_started.emit()

func pause_song() -> void:
	if playing:
		_paused_position = get_current_time()
		stream_paused = true
		playback_paused.emit()

func resume_song() -> void:
	if playing and stream_paused:
		stream_paused = false
		playback_started.emit()

func stop_song() -> void:
	stop()
	_paused_position = 0.0
	playback_stopped.emit()

func seek_song(position_seconds: float) -> void:
	seek(maxf(position_seconds, 0.0))
	_paused_position = maxf(position_seconds, 0.0)

func get_current_time() -> float:
	return get_playback_position() if playing and not stream_paused else _paused_position

func is_song_playing() -> bool:
	return playing and not stream_paused
