class_name MenuWorld
extends Node3D
## 메뉴 화면 뒤에 깔리는 3D 무대(게임과 같은 Stage + 노트 없는 하이웨이).
## 자체 박자로 천천히 흐르고, 선곡 미리듣기가 재생 중이면 그 곡의 박자, 아니면 배경 음악(App.bgm_*)의 박자에 맞춰 뛴다.

const IDLE_BPM := 84.0
const BEAT_LEN := 9.0                # 박 하나가 흘러가는 거리 (m)

var stage: Stage
var highway: Highway
var pulse: float = 0.0               # 박 직후 1 -> 0 (UI 가 읽어 쓴다)

var _beats: float = 0.0

func _init(view: String = "menu", dim: float = 0.0, blur: float = 0.0) -> void:
	stage = Stage.new()
	stage.sway = 0.35
	stage.set_view(view)
	stage.set_post(dim, blur)
	add_child(stage)
	highway = Highway.new()
	highway.idle = true
	add_child(highway)

func _process(delta: float) -> void:
	var beat_ms: float = 60000.0 / IDLE_BPM
	var live: bool = App.preview_position_ms() >= 0.0
	var bgm_pos: float = App.bgm_position_ms()
	if live:
		beat_ms = App.preview_beat_ms()
	elif bgm_pos >= 0.0:
		beat_ms = App.bgm_beat_ms()
	_beats += delta * 1000.0 / beat_ms
	if live:
		pulse = App.preview_pulse()
	elif bgm_pos >= 0.0:
		# 배경 음악(assets/bgm)의 BPM 에 맞춘 맥동
		pulse = pow(1.0 - fposmod(bgm_pos, beat_ms) / beat_ms, 3.0) * 0.8
	else:
		pulse = pow(1.0 - fposmod(_beats, 1.0), 3.0) * 0.6
	highway.sync_beats(_beats, BEAT_LEN, pulse)
	stage.sync(_beats, BEAT_LEN, pulse)
