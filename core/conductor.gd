class_name Conductor
extends Node
## 곡 시간 관리. delta 누적을 쓰지 않고 오디오 서버 기준으로 계산한다.

signal finished

var chart_offset_ms: float = 0.0   # 채보 meta.offset

var _player: AudioStreamPlayer
var _last_ms: float = 0.0
var _playing: bool = false
var _paused: bool = false

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_player.finished.connect(_on_finished)

func play(stream: AudioStream, from_ms: float = 0.0) -> void:
	_player.stream = stream
	_last_ms = from_ms
	_playing = true
	_player.play(from_ms / 1000.0)

func stop() -> void:
	_playing = false
	_player.stop()

## 일시정지. 곡 시간은 멈춘 값으로 고정된다.
func pause() -> void:
	if not _playing or _paused:
		return
	get_song_time_ms()
	_paused = true
	_player.stream_paused = true

## 재개. 오프셋이 바뀌었을 수 있으므로 단조 보정 기준을 새로 잡는다.
func resume() -> void:
	if not _paused:
		return
	_paused = false
	_player.stream_paused = false
	_last_ms = _raw_ms()

func is_paused() -> bool:
	return _paused

func is_playing() -> bool:
	return _playing

## 현재 곡 시간(ms). 전역 오프셋이 반영된 값.
func get_song_time_ms() -> float:
	if not _playing:
		return _last_ms
	var t: float = _player.get_playback_position() \
		+ AudioServer.get_time_since_last_mix() \
		- AudioServer.get_output_latency()
	var ms: float = t * 1000.0 + Settings.offset_ms + chart_offset_ms
	# mix 경계에서 값이 살짝 뒤로 튀는 것을 방지 (단조 증가)
	_last_ms = maxf(_last_ms, ms)
	return _last_ms

func _raw_ms() -> float:
	var t: float = _player.get_playback_position() 		+ AudioServer.get_time_since_last_mix() 		- AudioServer.get_output_latency()
	return t * 1000.0 + Settings.offset_ms + chart_offset_ms

func _on_finished() -> void:
	_playing = false
	finished.emit()
