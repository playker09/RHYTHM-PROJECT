class_name Highway
extends Node3D
## 3D 하이웨이: 유리 바닥, 레일, 기운 옆 패널, 판정선, 키 패드/입력 빔, 공중 판정선/커서.
## 판정 로직과 무관한 순수 비주얼. 곡 시간은 sync() 로 받아 박자에 맞춰 움직인다.
## 주변 무대(하늘/기둥/아치)는 Stage 가 담당한다.

const PAD_Z := 0.92
const SIDE_WIDTH := 2.1                 # 옆 패널 경사면 길이 (m)
const SIDE_TILT_DEG := 40.0             # 바닥 기준 기울기
const LEFT_EDGE := Color(0.56, 0.48, 1.0)
const RIGHT_EDGE := Color(1.0, 0.31, 0.62)
const HIT_COLOR := Color(0.82, 0.96, 1.0)
const PRESS_COLOR := Color(0.5, 0.9, 1.0)
const PAD_COLOR := Color(0.5, 0.52, 0.95)
const AIR_LINE_COLOR := Color(0.82, 0.7, 1.0)
const CURSOR_COLOR := Color(0.75, 0.97, 1.0)
const CURSOR_OUT_COLOR := Color(1.0, 0.3, 0.32)

# 그리는 순서 (반투명끼리). 작을수록 먼저 그린다.
const ORDER_FLOOR := -4
const ORDER_SIDE := -3
const ORDER_DECOR := -2
const ORDER_NOTE := 1
const ORDER_AIR := 3
const ORDER_FX := 5

const FLOOR_SHADER := preload("res://gameplay/shaders/highway_floor.gdshader")
const SIDE_SHADER := preload("res://gameplay/shaders/side_panel.gdshader")
const NEON_SHADER := preload("res://gameplay/shaders/neon.gdshader")
const BEAM_SHADER := preload("res://gameplay/shaders/beam.gdshader")
const RECEPTOR_SHADER := preload("res://gameplay/shaders/receptor.gdshader")
const CURSOR_SHADER := preload("res://gameplay/shaders/air_cursor.gdshader")

## true 면 메뉴 배경용: 키 패드/공중 판정선/커서를 만들지 않는다. add_child 전에 정한다.
var idle: bool = false

var _floor_mat: ShaderMaterial
var _side_mats: Array[ShaderMaterial] = []
var _pad_mats: Array[ShaderMaterial] = []
var _pad_labels: Array[Label3D] = []
var _beams: Array[Node3D] = []
var _beam_mats: Array[ShaderMaterial] = []
var _hit_mat: ShaderMaterial
var _press: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _press_target: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _cursor: Node3D
var _cursor_mat: ShaderMaterial
var _cursor_pole: ShaderMaterial
var _cursor_x: float = 0.0

## depth 와 정렬 순서를 넣은 셰이더 머티리얼
static func fx_mat(shader: Shader, order: int, params: Dictionary = {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	m.render_priority = order
	m.set_shader_parameter("depth", GameConst.VIEW_DEPTH)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m

static func lane_x(lane: int) -> float:
	return (lane - (GameConst.LANE_COUNT - 1) * 0.5) * GameConst.LANE_WIDTH

func _ready() -> void:
	var w: float = GameConst.LANE_WIDTH
	var count: int = GameConst.LANE_COUNT
	var depth: float = GameConst.VIEW_DEPTH
	var length: float = depth + 14.0      # 카메라 아래까지 덮는다
	var center_z: float = 11.0 - length * 0.5
	var half: float = count * w * 0.5

	# 바닥
	_floor_mat = fx_mat(FLOOR_SHADER, ORDER_FLOOR, {"lane_w": w, "half_w": half, "tone_left": LEFT_EDGE, "tone_right": RIGHT_EDGE})
	_add_plane(Vector2(w * count, length), Vector3(0.0, 0.0, center_z), _floor_mat)

	# 양쪽 레일 (밝은 네온) + 바깥의 가는 보조선
	for side: float in [-1.0, 1.0]:
		var col: Color = LEFT_EDGE if side < 0.0 else RIGHT_EDGE
		_add_plane(Vector2(0.075, length), Vector3(side * half, 0.012, center_z), fx_mat(NEON_SHADER, ORDER_DECOR, {"color": col, "energy": 2.6}))
		_add_plane(Vector2(0.02, length), Vector3(side * (half + 0.16), 0.012, center_z), fx_mat(NEON_SHADER, ORDER_DECOR, {"color": col, "energy": 1.0, "alpha": 0.6}))
		_add_side(side, half, length, center_z)

	# 판정선: 굵은 선 + 앞뒤 가는 선 + 레인 경계의 마름모
	_hit_mat = fx_mat(NEON_SHADER, ORDER_DECOR, {"color": HIT_COLOR, "energy": 2.6})
	_add_plane(Vector2(w * count + 0.12, 0.07), Vector3(0.0, 0.02, 0.0), _hit_mat)
	var thin := fx_mat(NEON_SHADER, ORDER_DECOR, {"color": HIT_COLOR, "energy": 1.0, "alpha": 0.4})
	_add_plane(Vector2(w * count, 0.014), Vector3(0.0, 0.02, -0.2), thin)
	_add_plane(Vector2(w * count, 0.014), Vector3(0.0, 0.02, 0.2), thin)
	var gem := fx_mat(NEON_SHADER, ORDER_DECOR + 1, {"color": Color(1.0, 1.0, 1.0), "energy": 3.0})
	for i in count + 1:
		var d := _add_plane(Vector2(0.15, 0.15), Vector3((i - count * 0.5) * w, 0.03, 0.0), gem)
		d.rotation.y = PI * 0.25

	if idle:
		return

	# 키 패드 + 라벨 + 입력 빔
	var pad_font: Font = Ui.font(true, 600)
	for i in count:
		var x: float = lane_x(i)
		var mat := fx_mat(RECEPTOR_SHADER, ORDER_DECOR, {
			"size": Vector2(w, 0.84), "body": Vector2(w * 0.9, 0.62), "color": PAD_COLOR, "hot": PRESS_COLOR})
		_add_plane(Vector2(w, 0.84), Vector3(x, 0.02, PAD_Z), mat)
		_pad_mats.append(mat)
		var label := Label3D.new()
		label.text = _key_name(i)
		label.font = pad_font
		label.font_size = 72
		label.pixel_size = 0.0052
		label.outline_size = 0
		label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		label.position = Vector3(x, 0.045, PAD_Z)
		label.modulate = Color(0.82, 0.86, 1.0, 0.8)
		label.render_priority = ORDER_NOTE
		add_child(label)
		_pad_labels.append(label)
		var beam := Node3D.new()
		beam.position = Vector3(x, 0.0, 0.0)
		add_child(beam)
		_add_beam(beam, Vector2(w * 0.96, 10.0), Vector3(0.0, 0.06, -5.0), true, 0.3, 2.2)
		_add_beam(beam, Vector2(w * 0.96, 2.6), Vector3(0.0, 1.3, 0.0), false, 0.16, 2.4)
		_beams.append(beam)

	_build_air()

## 옆 구조물: 레인 가장자리에서 바깥 위로 기운 유리판
func _add_side(side: float, half: float, length: float, center_z: float) -> void:
	var rim: Color = LEFT_EDGE if side < 0.0 else RIGHT_EDGE
	var mat := fx_mat(SIDE_SHADER, ORDER_SIDE, {"rim": rim})
	_side_mats.append(mat)
	var tilt: float = deg_to_rad(SIDE_TILT_DEG)
	var dir := Vector2(side * cos(tilt), sin(tilt))
	var inner := Vector2(side * (half + 0.03), 0.0)
	var c: Vector2 = inner + dir * SIDE_WIDTH * 0.5
	var mi := _add_plane(Vector2(SIDE_WIDTH, length), Vector3(c.x, c.y, center_z), mat)
	mi.rotation.z = tilt if side > 0.0 else PI - tilt

## 공중 판정선과 커서
func _build_air() -> void:
	var fw: float = GameConst.FIELD_WIDTH
	var y: float = GameConst.AIR_Y
	var z: float = GameConst.AIR_Z
	var air_mat := fx_mat(NEON_SHADER, ORDER_AIR, {"color": AIR_LINE_COLOR, "energy": 1.8, "x_fade": fw * 0.5 + 2.2})
	_add_plane(Vector2(fw + 4.4, 0.03), Vector3(0.0, y, z), air_mat)
	# 커서가 움직일 수 있는 양 끝 표시 (세로 꺾쇠)
	for sd: float in [-1.0, 1.0]:
		var tick := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.03, 0.4)
		tick.mesh = qm
		tick.material_override = fx_mat(NEON_SHADER, ORDER_AIR, {"color": AIR_LINE_COLOR, "energy": 1.8})
		tick.position = Vector3(sd * fw * 0.5, y, z)
		add_child(tick)

	_cursor = Node3D.new()
	_cursor.position = Vector3(0.0, y, z)
	add_child(_cursor)
	# 커서에서 바닥까지 내려오는 옅은 빛
	var pole := MeshInstance3D.new()
	var pqm := QuadMesh.new()
	pqm.size = Vector2(0.03, y)
	pole.mesh = pqm
	pole.position = Vector3(0.0, -y * 0.5, 0.0)
	_cursor_pole = fx_mat(NEON_SHADER, ORDER_AIR, {"color": CURSOR_COLOR, "energy": 1.0, "alpha": 0.3})
	pole.material_override = _cursor_pole
	_cursor.add_child(pole)
	var dot := MeshInstance3D.new()
	var dm := QuadMesh.new()
	dm.size = Vector2(0.86, 0.86)
	dot.mesh = dm
	_cursor_mat = fx_mat(CURSOR_SHADER, ORDER_FX + 1, {"color": CURSOR_COLOR})
	dot.material_override = _cursor_mat
	dot.extra_cull_margin = 2.0
	_cursor.add_child(dot)

## 곡 시간에 맞춰 바닥 박자선과 맥동을 움직인다. 매 프레임 호출. [박 수, 박 길이(m), 맥동] 을 돌려준다.
func sync(now_ms: float, timing: TimingMap, speed_per_ms: float) -> Array[float]:
	var beats: float = timing.beat_at(now_ms)
	var beat_len: float = timing.beat_ms_at(now_ms) * speed_per_ms
	var pulse: float = pow(1.0 - fposmod(beats, 1.0), 3.0)
	sync_beats(beats, beat_len, pulse)
	return [beats, beat_len, pulse]

## 박 수를 직접 받는 버전 (메뉴 배경용)
func sync_beats(beats: float, beat_len: float, pulse: float) -> void:
	var next_beat: float = (1.0 - fposmod(beats, 1.0)) * beat_len
	var next_bar: float = (4.0 - fposmod(beats, 4.0)) * beat_len
	_floor_mat.set_shader_parameter("next_beat", next_beat)
	_floor_mat.set_shader_parameter("beat_len", beat_len)
	_floor_mat.set_shader_parameter("next_bar", next_bar)
	_floor_mat.set_shader_parameter("pulse", pulse)
	for m in _side_mats:
		m.set_shader_parameter("scroll", next_bar)
		m.set_shader_parameter("spacing", beat_len * 4.0)
		m.set_shader_parameter("pulse", pulse)
	_hit_mat.set_shader_parameter("energy", 2.2 + pulse * 1.4)

func _process(delta: float) -> void:
	var k: float = 1.0 - exp(-delta * 30.0)
	var v := Vector4.ZERO
	for i in 4:
		_press[i] = lerpf(_press[i], _press_target[i], k)
		v[i] = _press[i]
		if i < _pad_mats.size():
			_pad_mats[i].set_shader_parameter("press", _press[i])
			_beams[i].visible = _press[i] > 0.02
			for m: ShaderMaterial in _beam_mats.slice(i * 2, i * 2 + 2):
				m.set_shader_parameter("gain", _press[i])
	_floor_mat.set_shader_parameter("press", v)
	if _cursor != null:
		_cursor.position.x = lerpf(_cursor.position.x, _cursor_x, 1.0 - exp(-delta * 60.0))

func set_cursor(x: float, outside: bool) -> void:
	if _cursor == null:
		return
	_cursor_x = (x - 0.5) * GameConst.FIELD_WIDTH
	var c: Color = CURSOR_OUT_COLOR if outside else CURSOR_COLOR
	_cursor_mat.set_shader_parameter("color", c)
	_cursor_pole.set_shader_parameter("color", c)

func set_lane_pressed(lane: int, pressed: bool) -> void:
	_press_target[lane] = 1.0 if pressed else 0.0
	if pressed:
		_press[lane] = 1.0      # 누르는 순간은 즉시 밝아진다
	if lane < _pad_labels.size():
		_pad_labels[lane].modulate = Color(1.0, 1.0, 1.0) if pressed else Color(0.82, 0.86, 1.0, 0.8)

# --- 헬퍼 ---
func _add_plane(size: Vector2, pos: Vector3, mat: Material) -> MeshInstance3D:
	var pm := PlaneMesh.new()
	pm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi

func _add_beam(parent: Node3D, size: Vector2, pos: Vector3, on_floor: bool, intensity: float, power: float) -> void:
	var mi := MeshInstance3D.new()
	if on_floor:
		var pm := PlaneMesh.new()
		pm.size = size
		mi.mesh = pm
	else:
		# QuadMesh UV.y = 0 이 위쪽이므로 그대로 쓰면 아래가 밝다
		var qm := QuadMesh.new()
		qm.size = size
		mi.mesh = qm
	var mat := fx_mat(BEAM_SHADER, ORDER_DECOR, {"color": PRESS_COLOR, "intensity": intensity, "power": power})
	_beam_mats.append(mat)
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)

func _key_name(lane: int) -> String:
	for ev in InputMap.action_get_events("lane_%d" % lane):
		if ev is InputEventKey:
			return (ev as InputEventKey).as_text_physical_keycode()
	return str(lane + 1)
