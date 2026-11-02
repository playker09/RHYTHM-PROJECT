extends Node
## 씬 전환(와이프), 선택된 곡, 곡별 최고 기록(user://records.cfg), UI 효과음, 선곡 미리듣기.
## 판정/점수 순수 로직은 이 오토로드를 참조하지 않는다.

const TITLE_SCENE := "res://scenes/title.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"
const SELECT_SCENE := "res://scenes/select.tscn"
const GAME_SCENE := "res://scenes/game.tscn"
const RECORDS_PATH := "user://records.cfg"
const DEFAULT_CHART := "res://charts/sample/chart.json"
const WIPE_SEC := 0.3
const WIPE_SHADER := preload("res://ui/shaders/wipe.gdshader")
const PREVIEW_DB := -7.0
const SFX := {
	"move": preload("res://assets/sfx/ui_move.wav"),
	"confirm": preload("res://assets/sfx/ui_confirm.wav"),
	"back": preload("res://assets/sfx/ui_back.wav"),
}

var selected_chart: String = DEFAULT_CHART

var _wipe: ColorRect
var _wipe_mat: ShaderMaterial
var _busy: bool = false
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_next: int = 0
var _preview: AudioStreamPlayer
var _preview_tween: Tween
var _preview_path: String = ""
var _preview_from: float = 0.0
var _preview_beat_ms: float = 500.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ThemeDB.get_default_theme().default_font = Ui.font(false, 400)
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_wipe = ColorRect.new()
	_wipe_mat = ShaderMaterial.new()
	_wipe_mat.shader = WIPE_SHADER
	_wipe.material = _wipe_mat
	_wipe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wipe.visible = false
	layer.add_child(_wipe)
	for i in 4:
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		_sfx_players.append(p)
	_preview = AudioStreamPlayer.new()
	add_child(_preview)
	_preview.finished.connect(func():
		if _preview_path != "":
			_preview.play(_preview_from))

## 어느 화면에서든 전체 화면 전환
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.physical_keycode == KEY_F11 or (k.alt_pressed and k.physical_keycode == KEY_ENTER):
			get_viewport().set_input_as_handled()
			Settings.fullscreen = not Settings.fullscreen
			Settings.apply_window()
			Settings.save_settings()

## 와이프로 덮기 -> 씬 교체 -> 걷어내기
func goto(scene_path: String) -> void:
	if _busy:
		return
	_busy = true
	preview_stop()
	_wipe.visible = true
	_wipe.mouse_filter = Control.MOUSE_FILTER_STOP
	_wipe_mat.set_shader_parameter("tail", -0.4)
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(v: float): _wipe_mat.set_shader_parameter("head", v), -0.1, 1.4, WIPE_SEC)
	await tw.finished
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await get_tree().process_frame
	var tw2 := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw2.tween_method(func(v: float): _wipe_mat.set_shader_parameter("tail", v), -0.4, 1.4, WIPE_SEC)
	await tw2.finished
	_wipe.visible = false
	_wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false

func start_game(chart_path: String) -> void:
	selected_chart = chart_path
	goto(GAME_SCENE)

# --- 효과음 ---
func sfx(id: String) -> void:
	var p: AudioStreamPlayer = _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_players.size()
	p.stream = SFX[id]
	p.play()

# --- 미리듣기 ---
func preview_play(audio_path: String, from_ms: float, bpm: float) -> void:
	_preview_beat_ms = 60000.0 / maxf(bpm, 1.0)
	if audio_path == _preview_path and _preview.playing:
		return
	var stream: AudioStream = load(audio_path)
	if stream == null:
		return
	_preview_path = audio_path
	_preview_from = from_ms / 1000.0
	if _preview_tween != null:
		_preview_tween.kill()
	_preview.stream = stream
	_preview.volume_db = -40.0
	_preview.play(_preview_from)
	_preview_tween = create_tween()
	_preview_tween.tween_property(_preview, "volume_db", PREVIEW_DB, 0.5)

func preview_stop() -> void:
	_preview_path = ""
	if _preview_tween != null:
		_preview_tween.kill()
	if not _preview.playing:
		return
	_preview_tween = create_tween()
	_preview_tween.tween_property(_preview, "volume_db", -40.0, 0.25)
	_preview_tween.tween_callback(_preview.stop)

## 미리듣기 재생 위치(ms). 재생 중이 아니면 -1.
func preview_position_ms() -> float:
	return _preview.get_playback_position() * 1000.0 if _preview.playing and _preview_path != "" else -1.0

## 미리듣기 박자에 맞춘 0~1 맥동 (박 직후 1 -> 0)
func preview_pulse() -> float:
	var pos: float = preview_position_ms()
	if pos < 0.0:
		return 0.0
	return pow(1.0 - fposmod(pos, _preview_beat_ms) / _preview_beat_ms, 3.0)

# --- 기록 ---
func get_record(chart_path: String) -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(RECORDS_PATH) != OK or not cfg.has_section(chart_path):
		return {}
	return {
		"score": int(cfg.get_value(chart_path, "score", 0)),
		"rank": str(cfg.get_value(chart_path, "rank", "")),
		"max_combo": int(cfg.get_value(chart_path, "max_combo", 0)),
		"rate": float(cfg.get_value(chart_path, "rate", 0.0)),
	}

## 최고 점수일 때만 갱신한다. 갱신했으면 true.
func submit_record(chart_path: String, score: int, rank: String, max_combo: int, rate: float) -> bool:
	var old: Dictionary = get_record(chart_path)
	if not old.is_empty() and int(old["score"]) >= score:
		return false
	var cfg := ConfigFile.new()
	cfg.load(RECORDS_PATH)
	cfg.set_value(chart_path, "score", score)
	cfg.set_value(chart_path, "rank", rank)
	cfg.set_value(chart_path, "max_combo", max_combo)
	cfg.set_value(chart_path, "rate", rate)
	cfg.save(RECORDS_PATH)
	return true
