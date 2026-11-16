extends Node3D
## HUD 글자 미리보기(개발용). 게임과 같은 무대 위에 곡 시작 제목, 끝 배너, 안내 문구를 바로 띄워 둔다.
## 30초를 기다리지 않고 한 화면에서 글자 모양을 확인하려는 용도. 게임 흐름에서는 쓰이지 않는다.
## 실행: 에디터에서 이 씬을 열고 F6 (또는 project_run custom scene).

const BANNER := "TUTORIAL CLEAR"       # "FULL COMBO" / "ALL PERFECT" 로 바꿔 볼 수 있다
const BANNER_COLOR := Ui.CYAN
const GUIDE := "[마우스를 좌우로 움직여] 커서를 [파란 영역 안에] 유지하세요."
## diff: 0~2 = 난이도 칩 표시, -1 = 튜토리얼처럼 칩 없음
const SONG := {"title": "Metronome Test", "artist": "Test Signal", "level": 8, "diff": 1, "jacket": ""}
const FOCUS := ""                        # 노란 강조: "keys" / "air" / ""
const SHOW_INTRO := false
const SHOW_BANNER := false
const SHOW_GUIDE := false

var _stage: Stage
var _highway: Highway
var _hud: Hud
var _timing := TimingMap.new([{"time": 0, "bpm": 120}])
var _t: float = 0.0

func _ready() -> void:
	App.bgm_stop()
	_stage = Stage.new()
	add_child(_stage)
	_highway = Highway.new()
	add_child(_highway)
	_hud = Hud.new()
	add_child(_hud)
	if SHOW_INTRO:
		_hud.set_song(SONG)
	_highway.set_focus(FOCUS)
	if PREVIEW_AIR:
		_preview_air()
	if SHOW_GUIDE:
		_hud.set_guide(GUIDE)
	if SHOW_BANNER:
		_hud.show_banner(BANNER, BANNER_COLOR)

func _process(delta: float) -> void:
	_t += delta * 1000.0
	var beat: Array[float] = _highway.sync(_t, _timing, GameConst.SCROLL_UNITS_PER_SEC * Settings.hispeed / 1000.0)
	_stage.sync(beat[0], beat[1], beat[2])

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		get_tree().quit()

## 플릭 폭(좁게/기본/넓게)과 스카이 알림을 정지 상태로 띄운다 (PREVIEW_AIR 가 true 일 때)
const PREVIEW_AIR := false

func _preview_air() -> void:
	var rows: Array = [[0.25, "left", 0.2, -3.0], [0.5, "right", GameConst.FLICK_DEFAULT_WIDTH, -7.0], [0.5, "left", 1.0, -12.0]]
	for r: Array in rows:
		var v := NoteView.create(NoteView.Kind.FLICK)
		add_child(v)
		v.set_flick(r[1], r[2])
		v.position = Vector3((float(r[0]) - 0.5) * GameConst.FIELD_WIDTH, GameConst.AIR_Y + 0.05, float(r[3]) + GameConst.AIR_Z)
	_highway.set_air_alert(1.0)
	_hud.set_air_alert(Vector4(1.0, 1.0, 0.3, 1.0))
