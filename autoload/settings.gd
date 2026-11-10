extends Node
## 전역 설정. user://settings.cfg 에 저장된다.

const PATH := "user://settings.cfg"

var offset_ms: float = 0.0          # 오디오/시각 보정 (양수 = 판정 기준 시각을 앞당김)
var sensitivity: float = 1.0        # 마우스 감도
var hispeed: float = 1.0
var field_grace_ms: float = 150.0   # Field 이탈 후 판정 면제 시간
var volume: float = 1.0             # 전체 음량 0~1
var hit_volume: float = 0.6         # 타격음 음량 0~1 (0 = 끔)
var fullscreen: bool = false

func _ready() -> void:
	load_settings()
	apply_audio()
	apply_window()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	offset_ms = cfg.get_value("sync", "offset_ms", offset_ms)
	sensitivity = cfg.get_value("input", "sensitivity", sensitivity)
	hispeed = cfg.get_value("play", "hispeed", hispeed)
	field_grace_ms = cfg.get_value("play", "field_grace_ms", field_grace_ms)
	volume = cfg.get_value("audio", "volume", volume)
	hit_volume = cfg.get_value("audio", "hit_volume", hit_volume)
	fullscreen = cfg.get_value("display", "fullscreen", fullscreen)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("sync", "offset_ms", offset_ms)
	cfg.set_value("input", "sensitivity", sensitivity)
	cfg.set_value("play", "hispeed", hispeed)
	cfg.set_value("play", "field_grace_ms", field_grace_ms)
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("audio", "hit_volume", hit_volume)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.save(PATH)

func apply_audio() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))

func apply_window() -> void:
	var mode: int = DisplayServer.window_get_mode()
	var is_full: bool = mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if fullscreen and not is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not fullscreen and is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
