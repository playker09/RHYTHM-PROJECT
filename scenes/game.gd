extends Node3D
## 플레이 씬 조립. 각 모듈을 만들어 연결만 한다.

const END_PADDING_MS := 1500.0
const SPEED_STEP := 0.1
const SPEED_MIN := 0.5
const SPEED_MAX := 4.0
const JUDGE_TEXT_Z := 3.0     # 판정 텍스트를 판정선에서 안쪽으로 얼마나 띄울지 (m)

var _camera: Camera3D

var conductor: Conductor
var judge: Judge
var field: FieldController
var field_renderer: FieldRenderer
var spawner: NoteSpawner
var score: ScoreManager
var hud: Hud
var pause_menu: PauseMenu
var _title: String = ""
var highway: Highway
var _end_ms: float = 0.0
var _finished: bool = false

func _ready() -> void:
	var chart: ChartData = ChartLoader.load_chart(App.selected_chart)
	if chart == null:
		return
	var stream: AudioStream = load(chart.base_dir.path_join(chart.audio))
	if stream == null:
		push_error("오디오를 불러오지 못했습니다: " + chart.audio)
		return

	_setup_environment()

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

	hud = Hud.new()
	add_child(hud)
	hud.bind(score, judge)
	hud.set_song(chart.title, chart.artist, chart.level, chart.difficulty)
	hud.result_action.connect(_on_result_action)
	_title = chart.title

	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.resume_requested.connect(_resume)
	pause_menu.retry_requested.connect(_restart)
	pause_menu.quit_requested.connect(func(): App.goto(App.SELECT_SCENE))
	pause_menu.settings_changed.connect(_apply_settings)

	_end_ms = chart.end_time_ms() + END_PADDING_MS
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN
	conductor.play(stream)

func _process(_delta: float) -> void:
	if conductor == null:
		return
	# 판정 텍스트: 기어 중앙, 판정선 조금 안쪽 (화면 좌표로 투영)
	hud.set_judge_anchor(_camera.unproject_position(Vector3(0.0, 0.3, -JUDGE_TEXT_Z)))
	hud.set_combo_anchor(_camera.unproject_position(Vector3(0.0, 0.2, -9.0)))
	highway.set_cursor(field.cursor_x, field.is_outside)
	if _finished:
		return
	hud.set_progress(conductor.get_song_time_ms() / _end_ms)
	if conductor.get_song_time_ms() > _end_ms:
		_finished = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var rate: float = 100.0 * (score.counts[0] + score.counts[1]) / maxf(score.counts[0] + score.counts[1] + score.counts[2], 1)
		var is_new: bool = App.submit_record(App.selected_chart, score.score, score.rank(), score.max_combo, rate)
		hud.show_result(score, _title, is_new)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).physical_keycode:
			KEY_ESCAPE:
				if pause_menu != null and pause_menu.visible:
					pass    # 메뉴가 자체 처리
				elif _finished:
					App.goto(App.SELECT_SCENE)
				else:
					_pause()
			KEY_R:
				_restart()
			KEY_1:
				_change_speed(-SPEED_STEP)
			KEY_2:
				_change_speed(SPEED_STEP)

func _pause() -> void:
	if conductor == null or get_tree().paused:
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

func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _apply_settings() -> void:
	field.sensitivity = Settings.sensitivity
	hud.set_speed(Settings.hispeed)

func _on_result_action(action: String) -> void:
	match action:
		"retry":
			_restart()
		"settings":
			pause_menu.open_settings_only()
		"quit":
			App.goto(App.SELECT_SCENE)

func _change_speed(step: float) -> void:
	Settings.hispeed = clampf(snappedf(Settings.hispeed + step, SPEED_STEP), SPEED_MIN, SPEED_MAX)
	Settings.save_settings()
	if hud != null:
		hud.set_speed(Settings.hispeed)

func _setup_environment() -> void:
	var bg := Color(0.02, 0.02, 0.06)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = bg
	env.fog_enabled = true
	env.fog_light_color = bg
	env.fog_density = 0.02
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var cam := Camera3D.new()
	_camera = cam
	cam.fov = 46.0
	cam.far = 200.0
	add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 3.7, 7.4), Vector3(0.0, 0.4, -6.0), Vector3.UP)
