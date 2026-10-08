extends Node
## 전역 설정. user://settings.cfg 에 저장된다.

const PATH := "user://settings.cfg"

var offset_ms: float = 0.0          # 오디오/시각 보정 (양수 = 판정 기준 시각을 앞당김)
var sensitivity: float = 1.0        # 마우스 감도
var hispeed: float = 1.0
var field_grace_ms: float = 150.0   # Field 이탈 후 판정 면제 시간

func _ready() -> void:
	load_settings()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	offset_ms = cfg.get_value("sync", "offset_ms", offset_ms)
	sensitivity = cfg.get_value("input", "sensitivity", sensitivity)
	hispeed = cfg.get_value("play", "hispeed", hispeed)
	field_grace_ms = cfg.get_value("play", "field_grace_ms", field_grace_ms)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("sync", "offset_ms", offset_ms)
	cfg.set_value("input", "sensitivity", sensitivity)
	cfg.set_value("play", "hispeed", hispeed)
	cfg.set_value("play", "field_grace_ms", field_grace_ms)
	cfg.save(PATH)
