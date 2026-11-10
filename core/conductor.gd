class_name Conductor
extends Node
## 곡 시간 관리. delta 누적을 쓰지 않고 오디오 서버 기준으로 계산한다.
## lead_in 이 있으면 오디오가 시작되기 전까지 실시계(Time.get_ticks_usec)로 곡 시간을 음수 -> 0 으로 흘린다.

signal finished

var chart_offset_ms: float = 0.0   # 채보 meta.offset

var _player: AudioStreamPlayer
var _last_ms: float = 0.0
var _playing: bool = false
var _paused: bool = false
var _from_ms: float = 0.0
var _lead_ms: float = 0.0          # > 0 이면 리드인 중
var _lead_start_us: int = 0
var _pause_us: int = 0

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_player.finished.connect(_on_finished)

func play(stream: AudioStream, from_ms: float = 0.0, lead_in_ms: float = 0.0) -> void:
	_player.stream = stream
	_from_ms = from_ms
	_playing = true
	_paused = false
	if lead_in_ms > 0.0:
		_lead_ms = lead_in_ms
		_lead_start_us = Time.get_ticks_usec()
		_last_ms = from_ms - lead_in_ms - 1000.0
	else:
		_lead_ms = 0.0
		_last_ms = from_ms
		_player.play(from_ms / 1000.0)

func stop() -> void:
	_playing = false
	_lead_ms = 0.0
	_player.stop()

func _process(_delta: float) -> void:
	# 리드인이 끝나는 순간 오디오를 시작한다. 지난 만큼은 건너뛰어 시계와 맞춘다.
	if _playing and not _paused and _lead_ms > 0.0:
		var t: float = _lead_clock_ms()
		if t >= _from_ms:
			_lead_ms = 0.0
			_player.play(t / 1000.0)

## 일시정지. 곡 시간은 멈춘 값으로 고정된다.
func pause() -> void:
	if not _playing or _paused:
		return
	get_song_time_ms()
	_paused = true
	_pause_us = Time.get_ticks_usec()
	_player.stream_paused = true

## 재개. 오프셋이 바뀌었을 수 있으므로 단조 보정 기준을 새로 잡는다.
func resume() -> void:
	if not _paused:
		return
	_paused = false
	_lead_start_us += Time.get_ticks_usec() - _pause_us
	_player.stream_paused = false
	_last_ms = _raw_ms()

func is_paused() -> bool:
	return _paused

func is_playing() -> bool:
	return _playing

## 오디오가 아직 시작되지 않았는가 (카운트다운 중)
func in_lead_in() -> bool:
	return _playing and _lead_ms > 0.0

## 현재 곡 시간(ms). 전역 오프셋이 반영된 값.
func get_song_time_ms() -> float:
	if not _playing or _paused:
		return _last_ms
	# mix 경계에서 값이 살짝 뒤로 튀는 것을 방지 (단조 증가)
	_last_ms = maxf(_last_ms, _raw_ms())
	return _last_ms

func _lead_clock_ms() -> float:
	return _from_ms - _lead_ms + float(Time.get_ticks_usec() - _lead_start_us) / 1000.0

func _raw_ms() -> float:
	var offset: float = Settings.offset_ms + chart_offset_ms
	if _lead_ms > 0.0:
		return _lead_clock_ms() + offset
	var t: float = _player.get_playback_position() \
		+ AudioServer.get_time_since_last_mix() \
		- AudioServer.get_output_latency()
	return t * 1000.0 + offset

func _on_finished() -> void:
	_playing = false
	finished.emit()
