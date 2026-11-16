extends Node3D
## 플레이 씬 조립. 각 모듈을 만들어 연결만 한다.

const END_PADDING_MS := 1800.0
const TUTORIAL_END_MS := 3200.0       # 튜토리얼은 마지막 안내 문구를 읽을 시간을 더 준다
const BANNER_DELAY_MS := 350.0        # 마지막 노트 뒤 FULL COMBO 문구가 뜨기까지
const SPEED_STEP := 0.1
const SPEED_MIN := 0.5
const SPEED_MAX := 4.0
const JUDGE_TEXT_Z := 5.0             # 판정 글자를 판정선에서 안쪽으로 얼마나 띄울지 (m)

var _timing: TimingMap
var _chart_end_ms: float = 0.0
var _end_ms: float = 0.0
var _finished: bool = false
var _banner_done: bool = false
var _best_before: Dictionary = {}
var _chart_path: String = ""
var _tutorial: bool = false           # 튜토리얼: 기록/결과 화면 없이 끝나면 메인 메뉴로
var _guides: Array[Dictionary] = []   # 곡 폴더 guide.json 의 화면 안내 문구

var stage: Stage
var conductor: Conductor
var judge: Judge
var field: FieldController
var field_renderer: FieldRenderer
var spawner: NoteSpawner
var score: ScoreManager
var hud: Hud
var pause_menu: PauseMenu
var highway: Highway
var hit_fx: HitFx
var effects: EffectTrack
var air_alert: AirAlert

func _ready() -> void:
	App.bgm_stop()
	_chart_path = App.current_chart()
	_tutorial = App.tutorial
	var chart: ChartData = ChartLoader.load_chart(_chart_path)
	if chart == null:
		return
	var stream: AudioStream = load(chart.base_dir.path_join(chart.audio))
	if stream == null:
		push_error("오디오를 불러오지 못했습니다: " + chart.audio)
		return

	stage = Stage.new()
	add_child(stage)

	highway = Highway.new()
	add_child(highway)

	conductor = Conductor.new()
	conductor.chart_offset_ms = chart.offset_ms
	add_child(conductor)

	score = ScoreManager.new()
	add_child(score)

	judge = Judge.new()
	judge.time_fn = conductor.get_song_time_ms
	judge.setup(chart)
	add_child(judge)
	judge.judged.connect(score.on_judged)
	judge.judged.connect(_on_judged_sound)
	judge.lane_changed.connect(highway.set_lane_pressed)
	score.setup(judge.total_judgements)

	field = FieldController.new()
	field.sensitivity = Settings.sensitivity
	field.grace_ms = Settings.field_grace_ms
	field.setup(chart)
	add_child(field)
	judge.field = field

	field_renderer = FieldRenderer.new()
	field_renderer.time_fn = conductor.get_song_time_ms
	add_child(field_renderer)
	field_renderer.setup(chart, highway, field)

	spawner = NoteSpawner.new()
	spawner.time_fn = conductor.get_song_time_ms
	add_child(spawner)
	spawner.setup(chart, highway, judge)

	hit_fx = HitFx.new()
	add_child(hit_fx)
	hit_fx.setup(judge, field)

	air_alert = AirAlert.new()
	air_alert.setup(chart.notes)

	effects = EffectTrack.new()
	effects.setup(chart.effects)

	hud = Hud.new()
	add_child(hud)
	hud.bind(score, judge)
	hud.set_song({
		"title": chart.title, "artist": chart.artist, "level": chart.level,
		"diff": -1 if _tutorial else ChartLoader.diff_of_path(_chart_path),
		"jacket": ChartLoader.find_jacket(chart.base_dir),
	})
	hud.result_action.connect(_on_result_action)
	_timing = chart.timing

	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.resume_requested.connect(_resume)
	pause_menu.retry_requested.connect(_restart)
	pause_menu.quit_requested.connect(_leave)
	pause_menu.settings_changed.connect(_apply_settings)

	_best_before = App.get_record(_chart_path)
	_guides = ChartLoader.load_guides(chart.base_dir)
	_chart_end_ms = chart.end_time_ms()
	_end_ms = _chart_end_ms + (TUTORIAL_END_MS if _tutorial else END_PADDING_MS)
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN
	conductor.play(stream, 0.0, GameConst.LEAD_IN_MS)

func _process(_delta: float) -> void:
	if conductor == null:
		return
	var cam: Camera3D = stage.camera
	# 콤보 = 소실점(일식 원반) 가운데, 판정 글자 = 판정선 조금 안쪽 (화면 좌표로 투영)
	hud.set_combo_anchor(cam.unproject_position(cam.global_position + Vector3(0.0, 0.0, -100.0)))
	hud.set_judge_anchor(cam.unproject_position(Vector3(0.0, 0.3, -JUDGE_TEXT_Z)))
	highway.set_cursor(field.cursor_x, field.is_outside)
	var now: float = conductor.get_song_time_ms()
	var beat: Array[float] = highway.sync(now, _timing, GameConst.SCROLL_UNITS_PER_SEC * Settings.hispeed / 1000.0)
	stage.sync(beat[0], beat[1], beat[2])
	# 채보 연출: 곡 시간에서 바로 계산해 넘긴다 (판정과 무관). 회전은 하이웨이와 타격 이펙트만 돈다
	var fx: Dictionary = effects.sample(now)
	stage.set_fx(fx["flash_l"], fx["flash_r"], fx["glitch"])
	highway.set_flash(fx["flash_l"], fx["flash_r"])
	var alert: Vector4 = air_alert.sample(now)    # 스카이 알림 (판정과 무관): 판정선 깜빡임 + 화면 옆 LEFT/RIGHT 패널
	highway.set_air_alert(maxf(alert.x * alert.y, alert.z * alert.w))
	hud.set_air_alert(alert)
	highway.rotation.z = fx["spin"]
	hit_fx.rotation.z = fx["spin"]
	if _finished:
		return
	hud.set_countdown(now)
	if not _guides.is_empty():
		hud.set_guide(ChartLoader.guide_at(_guides, now, Settings.controller))
		highway.set_focus(ChartLoader.focus_at(_guides, now))
	hud.set_progress(now, _chart_end_ms)
	if not _banner_done and now > _chart_end_ms + BANNER_DELAY_MS:
		_banner_done = true
		if _tutorial:
			hud.show_banner("TUTORIAL CLEAR", Ui.CYAN)
		elif score.rank() == "AP":
			hud.show_banner("ALL PERFECT", Ui.GOLD)
		elif score.is_full_combo():
			hud.show_banner("FULL COMBO", Ui.CYAN)
	if now > _end_ms:
		_finished = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if _tutorial:
			_leave()
			return
		var is_new: bool = App.submit_record(_chart_path, score.score, score.rank(), score.max_combo, score.accuracy(), score.is_full_combo())
		hud.show_result(score, is_new, _best_before)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).physical_keycode:
			KEY_ESCAPE:
				if pause_menu != null and pause_menu.visible:
					pass    # 메뉴가 자체 처리
				elif _finished:
					_leave()
				else:
					_pause()
			KEY_R:
				_restart()
			KEY_1:
				_change_speed(-SPEED_STEP)
			KEY_2:
				_change_speed(SPEED_STEP)

## 타격음: 머리/플릭을 맞힌 순간에만 (tick 과 MISS 는 소리 없음)
func _on_judged_sound(note: NoteData, grade: int, _delta_ms: float, is_tick: bool) -> void:
	if is_tick or grade == JudgeLogic.Grade.MISS:
		return
	App.sfx("hit_flick" if note.type == NoteData.Type.FLICK else "hit_tap", Settings.hit_volume)

func _pause() -> void:
	if conductor == null or get_tree().paused or App.is_busy():
		return
	conductor.pause()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	pause_menu.open_pause()

func _resume() -> void:
	pause_menu.close()
	conductor.resume()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN

## 플레이를 떠난다: 곡 선택으로, 튜토리얼이면 메인 메뉴로
func _leave() -> void:
	App.goto(App.MENU_SCENE if _tutorial else App.SELECT_SCENE)

func _restart() -> void:
	if App.is_busy():
		return
	get_tree().paused = false
	get_tree().reload_current_scene()

func _apply_settings() -> void:
	field.sensitivity = Settings.sensitivity
	hud.set_speed(Settings.hispeed)

func _on_result_action(action: String) -> void:
	match action:
		"retry":
			_restart()
		"quit":
			_leave()

func _change_speed(step: float) -> void:
	Settings.hispeed = clampf(snappedf(Settings.hispeed + step, SPEED_STEP), SPEED_MIN, SPEED_MAX)
	Settings.save_settings()
	if hud != null:
		hud.set_speed(Settings.hispeed)
