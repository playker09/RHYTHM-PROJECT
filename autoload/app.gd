extends Node
## 씬 전환(와이프), 선택된 곡, 곡별 최고 기록(user://records.cfg), UI 효과음, 선곡 미리듣기.
## 판정/점수 순수 로직은 이 오토로드를 참조하지 않는다.

const TITLE_SCENE := "res://scenes/title.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"
const SELECT_SCENE := "res://scenes/select.tscn"
const GAME_SCENE := "res://scenes/game.tscn"
const RECORDS_PATH := "user://records.cfg"
const DEFAULT_CHART := "res://charts/sample/nm.json"
const WIPE_SEC := 0.42
const WIPE_SHADER := preload("res://ui/shaders/wipe.gdshader")
const PREVIEW_DB := -7.0
const BGM_DIR := "res://assets/bgm/"       # menu / select / result .mp3(.ogg/.wav). 없으면 안 튼다
const BGM_EXTS := ["mp3", "ogg", "wav"]
const BGM_DB := -8.0
const BGM_FADE := 0.6
const BGM_DEFAULT_BPM := 120.0             # bgm.json 에 BPM 이 없을 때
const SFX := {
	"move": preload("res://assets/sfx/ui_move.wav"),
	"confirm": preload("res://assets/sfx/ui_confirm.wav"),
	"back": preload("res://assets/sfx/ui_back.wav"),
	"tab": preload("res://assets/sfx/ui_tab.wav"),
	"start": preload("res://assets/sfx/ui_start.wav"),
	"count": preload("res://assets/sfx/count.wav"),
	"go": preload("res://assets/sfx/count_go.wav"),
	"result": preload("res://assets/sfx/result.wav"),
	"clear": preload("res://assets/sfx/clear.wav"),
	"hit_tap": preload("res://assets/sfx/hit_tap.wav"),
	"hit_flick": preload("res://assets/sfx/hit_flick.wav"),
}

var selected_chart: String = DEFAULT_CHART
var selected_diff: int = 1            # 난이도 슬롯 (ChartLoader.DIFFS). 곡을 바꿔도 유지

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
var _bgm_players: Array[AudioStreamPlayer] = []
var _bgm_tweens: Array = [null, null]
var _bgm_cur: int = 0
var _bgm_id: String = ""
var _bgm_beat_ms: float = 500.0

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
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)
	_preview = AudioStreamPlayer.new()
	add_child(_preview)
	_preview.finished.connect(func():
		if _preview_path != "":
			_preview.play(_preview_from))
	for i in 2:
		var b := AudioStreamPlayer.new()
		add_child(b)
		_bgm_players.append(b)

## 어느 화면에서든 전체 화면 전환
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.physical_keycode == KEY_F11 or (k.alt_pressed and k.physical_keycode == KEY_ENTER):
			get_viewport().set_input_as_handled()
			Settings.fullscreen = not Settings.fullscreen
			Settings.apply_window()
			Settings.save_settings()

## 와이프로 덮기 -> 씬 교체 -> 걷어내기. progress 0~1 = 덮기, 1~2 = 걷기.
func goto(scene_path: String) -> void:
	if _busy:
		return
	_busy = true
	preview_stop()
	_wipe.visible = true
	_wipe.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_method(_set_wipe, 0.0, 1.0, WIPE_SEC)
	await tw.finished
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var tw2 := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw2.tween_method(_set_wipe, 1.0, 2.0, WIPE_SEC)
	await tw2.finished
	_wipe.visible = false
	_wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false

func _set_wipe(v: float) -> void:
	_wipe_mat.set_shader_parameter("progress", v)

func is_busy() -> bool:
	return _busy

func start_game(chart_path: String) -> void:
	selected_chart = chart_path
	var slot: int = ChartLoader.diff_of_path(chart_path)
	if slot >= 0:
		selected_diff = slot
	goto(GAME_SCENE)

# --- 효과음 ---
## gain: 0~1 선형 음량
func sfx(id: String, gain: float = 0.5) -> void:
	if gain <= 0.0:
		return
	var p: AudioStreamPlayer = _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_players.size()
	p.stream = SFX[id]
	p.volume_db = linear_to_db(gain)
	p.play()

# --- 미리듣기 ---
## 재생을 시작했으면(또는 이미 재생 중이면) true. 오디오가 없으면 false.
func preview_play(audio_path: String, from_ms: float, bpm: float) -> bool:
	_preview_beat_ms = 60000.0 / maxf(bpm, 1.0)
	if audio_path == _preview_path and _preview.playing:
		return true
	if audio_path == "" or not ResourceLoader.exists(audio_path):
		return false
	var stream: AudioStream = load(audio_path)
	if stream == null:
		return false
	_preview_path = audio_path
	_preview_from = from_ms / 1000.0
	if _preview_tween != null:
		_preview_tween.kill()
	_preview.stream = stream
	_preview.volume_db = -40.0
	_preview.play(_preview_from)
	_preview_tween = create_tween()
	_preview_tween.tween_property(_preview, "volume_db", PREVIEW_DB, 0.5)
	return true

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

func preview_beat_ms() -> float:
	return _preview_beat_ms

## 미리듣기 박자에 맞춘 0~1 맥동 (박 직후 1 -> 0)
func preview_pulse() -> float:
	var pos: float = preview_position_ms()
	if pos < 0.0:
		return 0.0
	return pow(1.0 - fposmod(pos, _preview_beat_ms) / _preview_beat_ms, 3.0)

# --- 배경 음악 (메뉴/선곡/결과) ---
## assets/bgm/<id>.mp3(.ogg/.wav)를 반복 재생한다. 파일이 없으면 지금 나오던 것도 끄고 조용히 둔다.
## 같은 id 가 이미 나오고 있으면 끊지 않고 그대로 둔다(타이틀 -> 메인 메뉴).
func bgm_play(id: String) -> void:
	if id == _bgm_id and _bgm_players[_bgm_cur].playing:
		return
	var path: String = _bgm_path(id)
	if path == "":
		bgm_stop()
		return
	var stream: AudioStream = load(path)
	if stream == null:
		bgm_stop()
		return
	if stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	bgm_stop()
	_bgm_cur = 1 - _bgm_cur
	_bgm_id = id
	var info: Dictionary = _bgm_info(id)
	_bgm_beat_ms = 60000.0 / maxf(float(info["bpm"]), 1.0)
	var vol: float = float(info["volume"])
	if vol <= 0.0:
		_bgm_id = ""
		return
	var p: AudioStreamPlayer = _bgm_players[_bgm_cur]
	_bgm_kill_tween(_bgm_cur)
	p.stream = stream
	p.volume_db = -40.0
	p.play()
	var tw := create_tween()
	tw.tween_property(p, "volume_db", BGM_DB + linear_to_db(vol), BGM_FADE)
	_bgm_tweens[_bgm_cur] = tw

func bgm_stop() -> void:
	_bgm_id = ""
	var i: int = _bgm_cur
	var p: AudioStreamPlayer = _bgm_players[i]
	if not p.playing:
		return
	_bgm_kill_tween(i)
	var tw := create_tween()
	tw.tween_property(p, "volume_db", -40.0, BGM_FADE)
	tw.tween_callback(p.stop)
	_bgm_tweens[i] = tw

func _bgm_kill_tween(i: int) -> void:
	var tw: Tween = _bgm_tweens[i]
	if tw != null and tw.is_valid():
		tw.kill()
	_bgm_tweens[i] = null

func _bgm_path(id: String) -> String:
	for ext: String in BGM_EXTS:
		var path: String = BGM_DIR + id + "." + ext
		if ResourceLoader.exists(path):
			return path
	return ""

## assets/bgm/bgm.json 에서 곡별 BPM/음량을 읽는다. 없거나 빠진 값은 기본값(BPM 120, 음량 1.0).
##   {"menu": {"bpm": 120, "volume": 0.8}, "select": 96}   <- 숫자만 쓰면 BPM
## volume 은 기본 음량(BGM_DB)에 곱하는 배수: 1.0 = 기본, 0.5 = 절반, 0 = 끔, 최대 2.5. 설정의 전체 음량과는 별개.
func _bgm_info(id: String) -> Dictionary:
	var info := {"bpm": BGM_DEFAULT_BPM, "volume": 1.0}
	var path: String = BGM_DIR + "bgm.json"
	if not FileAccess.file_exists(path):
		return info
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Dictionary) or not (data as Dictionary).has(id):
		return info
	var v: Variant = data[id]
	if v is Dictionary:
		if float(v.get("bpm", 0.0)) > 0.0:
			info["bpm"] = float(v["bpm"])
		if v.has("volume"):
			info["volume"] = clampf(float(v["volume"]), 0.0, 2.5)
	elif (v is float or v is int) and float(v) > 0.0:
		info["bpm"] = float(v)
	return info

## 배경 음악 재생 위치(ms). 재생 중이 아니면 -1.
func bgm_position_ms() -> float:
	var p: AudioStreamPlayer = _bgm_players[_bgm_cur]
	return p.get_playback_position() * 1000.0 if p.playing and _bgm_id != "" else -1.0

func bgm_beat_ms() -> float:
	return _bgm_beat_ms

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
		"full_combo": bool(cfg.get_value(chart_path, "full_combo", false)),
		"plays": int(cfg.get_value(chart_path, "plays", 0)),
	}

## 플레이 횟수는 항상 올리고, 점수/등급은 최고 점수일 때만 갱신한다. 갱신했으면 true.
func submit_record(chart_path: String, score: int, rank: String, max_combo: int, rate: float, full_combo: bool = false) -> bool:
	var old: Dictionary = get_record(chart_path)
	var cfg := ConfigFile.new()
	cfg.load(RECORDS_PATH)
	cfg.set_value(chart_path, "plays", int(old.get("plays", 0)) + 1)
	var better: bool = old.is_empty() or int(old["score"]) < score
	if better:
		cfg.set_value(chart_path, "score", score)
		cfg.set_value(chart_path, "rank", rank)
		cfg.set_value(chart_path, "max_combo", max_combo)
		cfg.set_value(chart_path, "rate", rate)
	if full_combo:
		cfg.set_value(chart_path, "full_combo", true)
	cfg.save(RECORDS_PATH)
	return better
