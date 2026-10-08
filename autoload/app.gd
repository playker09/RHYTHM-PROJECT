extends Node
## 씬 전환(페이드), 선택된 곡, 곡별 최고 기록(user://records.cfg).
## 판정/점수 순수 로직은 이 오토로드를 참조하지 않는다.

const TITLE_SCENE := "res://scenes/title.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"
const SELECT_SCENE := "res://scenes/select.tscn"
const GAME_SCENE := "res://scenes/game.tscn"
const RECORDS_PATH := "user://records.cfg"
const DEFAULT_CHART := "res://charts/sample/chart.json"
const FADE_SEC := 0.25

var selected_chart: String = DEFAULT_CHART

var _fade: ColorRect
var _busy: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)

## 페이드 아웃 -> 씬 교체 -> 페이드 인
func goto(scene_path: String) -> void:
	if _busy:
		return
	_busy = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, FADE_SEC)
	await tw.finished
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(_fade, "color:a", 0.0, FADE_SEC)
	await tw2.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false

func start_game(chart_path: String) -> void:
	selected_chart = chart_path
	goto(GAME_SCENE)

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
