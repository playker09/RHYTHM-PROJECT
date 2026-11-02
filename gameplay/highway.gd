class_name Highway
extends Node3D
## 3D 하이웨이: 바닥, 옆 경사면, 판정선, 키 패드/입력 빔, 공중 판정선/커서, 빛 게이트, 입자.
## 판정 로직과 무관한 순수 비주얼. 곡 시간은 sync() 로 받아 박자에 맞춰 움직인다.

const PAD_Z := 0.9
const SIDE_WIDTH := 2.1                 # 옆 구조물 경사면 길이 (m)
const SIDE_TILT_DEG := 40.0             # 바닥 기준 기울기
const LEFT_EDGE := Color(0.56, 0.48, 1.0)
const RIGHT_EDGE := Color(1.0, 0.31, 0.62)
const HIT_COLOR := Color(0.72, 1.0, 1.0)
const AIR_LINE_COLOR := Color(0.82, 0.7, 1.0)
const CURSOR_COLOR := Color(0.75, 0.97, 1.0)
const CURSOR_OUT_COLOR := Color(1.0, 0.3, 0.32)
const GATE_COUNT := 10

# 그리는 순서 (반투명끼리). 작을수록 먼저 그린다.
const ORDER_FLOOR := -4
const ORDER_SIDE := -3
const ORDER_DECOR := -2
const ORDER_NOTE := 1
const ORDER_AIR := 2
const ORDER_FX := 3

const FLOOR_SHADER := preload("res://gameplay/shaders/highway_floor.gdshader")
const SIDE_SHADER := preload("res://gameplay/shaders/side_panel.gdshader")
const NEON_SHADER := preload("res://gameplay/shaders/neon.gdshader")
const BEAM_SHADER := preload("res://gameplay/shaders/beam.gdshader")
const PILL_SHADER := preload("res://gameplay/shaders/note_pill.gdshader")
const CURSOR_SHADER := preload("res://gameplay/shaders/air_cursor.gdshader")

var _floor_mat: ShaderMaterial
var _side_mats: Array[ShaderMaterial] = []
var _pad_mats: Array[ShaderMaterial] = []
var _pad_labels: Array[Label3D] = []
var _beams: Array[Node3D] = []
var _hit_mat: ShaderMaterial
var _air_mat: ShaderMaterial
var _press: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _press_target: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _gates: Array[MeshInstance3D] = []
var _cursor: Node3D
var _cursor_mat: ShaderMaterial
var _cursor_pole: ShaderMaterial
var _beam_len: float = 8.0

## depth 와 정렬 순서를 넣은 셰이더 머티리얼
static func fx_mat(shader: Shader, order: int, params: Dictionary = {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	m.render_priority = order
	if shader != BEAM_SHADER and shader != CURSOR_SHADER:
		m.set_shader_parameter("depth", GameConst.VIEW_DEPTH)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m

func _ready() -> void:
	var w: float = GameConst.LANE_WIDTH
	var count: int = GameConst.LANE_COUNT
	var depth: float = GameConst.VIEW_DEPTH
	var length: float = depth + 14.0      # 카메라 아래까지 덮는다
	var center_z: float = 11.0 - length * 0.5
	var half: float = count * w * 0.5

	# 바닥
	_floor_mat = fx_mat(FLOOR_SHADER, ORDER_FLOOR, {"lane_w": w, "half_w": half})
	_add_plane(Vector2(w * count, length), Vector3(0.0, 0.0, center_z), _floor_mat)

	# 양쪽 레일 (밝은 네온)
	_add_plane(Vector2(0.07, length), Vector3(-half, 0.012, center_z), fx_mat(NEON_SHADER, ORDER_DECOR, {"color": LEFT_EDGE, "energy": 2.0}))
	_add_plane(Vector2(0.07, length), Vector3(half, 0.012, center_z), fx_mat(NEON_SHADER, ORDER_DECOR, {"color": RIGHT_EDGE, "energy": 2.0}))

	_add_side(-1.0, half, length, center_z)
	_add_side(1.0, half, length, center_z)

	# 판정선
	_hit_mat = fx_mat(NEON_SHADER, ORDER_DECOR, {"color": HIT_COLOR, "energy": 2.4})
	_add_plane(Vector2(w * count + 0.1, 0.075), Vector3(0.0, 0.02, 0.0), _hit_mat)

	# 키 패드 + 라벨 + 입력 빔
	var pad_font: Font = Ui.font(true, 600)
	for i in count:
		var x: float = (i - (count - 1) * 0.5) * w
		var mat := fx_mat(PILL_SHADER, ORDER_DECOR, {
			"size": Vector2(w, 0.84), "body": Vector2(w * 0.9, 0.62),
			"color": Color(0.16, 0.2, 0.36), "energy": 1.0, "core": 0.0, "halo": 0.0, "alpha": 0.9})
		_add_plane(Vector2(w, 0.84), Vector3(x, 0.02, PAD_Z), mat)
		_pad_mats.append(mat)
		var label := Label3D.new()
		label.text = _key_name(i)
		label.font = pad_font
		label.font_size = 72
		label.pixel_size = 0.0058
		label.outline_size = 0
		label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		label.position = Vector3(x, 0.045, PAD_Z)
		label.modulate = Color(0.8, 0.86, 1.0, 0.85)
		label.render_priority = ORDER_NOTE
		add_child(label)
		_pad_labels.append(label)
		var beam := Node3D.new()
		beam.position = Vector3(x, 0.0, 0.0)
		beam.visible = false
		add_child(beam)
		_add_beam(beam, Vector2(w * 0.96, 9.0), Vector3(0.0, 0.06, -4.5), true, 0.62, 2.2)
		_add_beam(beam, Vector2(w * 0.96, 2.2), Vector3(0.0, 1.1, 0.0), false, 0.34, 2.4)
		_beams.append(beam)

	_build_air()
	_build_gates(half)
	_build_motes(half)

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
	_air_mat = fx_mat(NEON_SHADER, ORDER_AIR, {"color": AIR_LINE_COLOR, "energy": 1.7, "x_fade": fw * 0.5 + 2.0})
	_add_plane(Vector2(fw + 4.0, 0.035), Vector3(0.0, y, z), _air_mat)
	# 커서가 움직일 수 있는 양 끝 표시
	for sd in [-1.0, 1.0]:
		_add_plane(Vector2(0.03, 0.34), Vector3(sd * fw * 0.5, y, z), fx_mat(NEON_SHADER, ORDER_AIR, {"color": AIR_LINE_COLOR, "energy": 1.4}))

	_cursor = Node3D.new()
	_cursor.position = Vector3(0.0, y, z)
	add_child(_cursor)
	# 커서에서 바닥까지 내려오는 옅은 빛
	var pole := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.03, y)
	pole.mesh = qm
	pole.position = Vector3(0.0, -y * 0.5, 0.0)
	_cursor_pole = fx_mat(NEON_SHADER, ORDER_AIR, {"color": CURSOR_COLOR, "energy": 1.0, "alpha": 0.28})
	pole.material_override = _cursor_pole
	_cursor.add_child(pole)
	var dot := MeshInstance3D.new()
	var dm := QuadMesh.new()
	dm.size = Vector2(0.7, 0.7)
	dot.mesh = dm
	_cursor_mat = fx_mat(CURSOR_SHADER, ORDER_FX + 1, {"color": CURSOR_COLOR})
	dot.material_override = _cursor_mat
	dot.extra_cull_margin = 2.0
	_cursor.add_child(dot)

## 머리 위로 지나가는 빛 게이트. 마디에 맞춰 흐른다.
func _build_gates(half: float) -> void:
	var w: float = half + SIDE_WIDTH * cos(deg_to_rad(SIDE_TILT_DEG)) + 0.25
	var h: float = 6.6
	var pts: Array[Vector2] = [
		Vector2(-w, 0.0), Vector2(-w, h * 0.62), Vector2(-w * 0.52, h), Vector2(w * 0.52, h), Vector2(w, h * 0.62), Vector2(w, 0.0)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var t: float = 0.022
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var n: Vector2 = (b - a).normalized().orthogonal() * t
		for p: Vector2 in [a + n, a - n, b + n, b + n, a - n, b - n]:
			st.add_vertex(Vector3(p.x, p.y, 0.0))
	var mesh: ArrayMesh = st.commit()
	var mat := fx_mat(NEON_SHADER, ORDER_DECOR, {"color": Color(0.72, 0.62, 1.0), "energy": 0.55, "alpha": 0.4, "near_z": 1.0})
	for i in GATE_COUNT:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		add_child(mi)
		_gates.append(mi)

## 양옆을 흘러가는 빛 입자
func _build_motes(half: float) -> void:
	_add_motes(-(half + 4.2))
	_add_motes(half + 4.2)

func _add_motes(x: float) -> void:
	var p := GPUParticles3D.new()
	p.amount = 45
	p.lifetime = 3.2
	p.preprocess = 3.2
	p.position = Vector3(x, 2.6, -GameConst.VIEW_DEPTH * 0.72)
	p.visibility_aabb = AABB(Vector3(-6.0, -6.0, -8.0), Vector3(12.0, 14.0, GameConst.VIEW_DEPTH + 16.0))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(3.0, 2.6, 2.0)
	pm.direction = Vector3(0.0, 0.0, 1.0)
	pm.spread = 0.0
	pm.initial_velocity_min = 7.0
	pm.initial_velocity_max = 13.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.025, 0.7)
	q.orientation = PlaneMesh.FACE_Y
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(0.72, 0.68, 1.0, 0.3)
	m.render_priority = ORDER_DECOR
	q.material = m
	p.draw_pass_1 = q
	add_child(p)

## 곡 시간에 맞춰 바닥 박자선, 게이트, 맥동을 움직인다. 매 프레임 호출.
func sync(now_ms: float, timing: TimingMap, speed_per_ms: float) -> float:
	var beats: float = timing.beat_at(now_ms)
	var beat_ms: float = timing.beat_ms_at(now_ms)
	var frac: float = fposmod(beats, 1.0)
	var pulse: float = pow(1.0 - frac, 3.0)
	_beam_len = beat_ms * speed_per_ms
	var next_beat: float = (1.0 - frac) * _beam_len
	var bar_pos: float = fposmod(beats, 4.0)
	var next_bar: float = (4.0 - bar_pos) * _beam_len
	_floor_mat.set_shader_parameter("next_beat", next_beat)
	_floor_mat.set_shader_parameter("beat_len", _beam_len)
	_floor_mat.set_shader_parameter("next_bar", next_bar)
	_floor_mat.set_shader_parameter("pulse", pulse)
	for m in _side_mats:
		m.set_shader_parameter("scroll", next_bar)
		m.set_shader_parameter("spacing", _beam_len * 4.0)
		m.set_shader_parameter("pulse", pulse)
	_hit_mat.set_shader_parameter("energy", 2.0 + pulse * 1.3)
	# 게이트: 마디 간격(너무 촘촘하면 2배씩) 으로 배치
	var spacing: float = _beam_len * 4.0
	while spacing < 7.0:
		spacing *= 2.0
	var z0: float = -fposmod(next_bar, spacing) + spacing
	for i in _gates.size():
		var z: float = z0 - i * spacing
		_gates[i].visible = z > -GameConst.VIEW_DEPTH and z < 4.0
		_gates[i].position = Vector3(0.0, 0.0, z)
	return pulse

func _process(delta: float) -> void:
	var k: float = 1.0 - exp(-delta * 26.0)
	var v := Vector4.ZERO
	for i in 4:
		_press[i] = lerpf(_press[i], _press_target[i], k)
		v[i] = _press[i]
	_floor_mat.set_shader_parameter("press", v)

func set_cursor(x: float, outside: bool) -> void:
	_cursor.position.x = (x - 0.5) * GameConst.FIELD_WIDTH
	var c: Color = CURSOR_OUT_COLOR if outside else CURSOR_COLOR
	_cursor_mat.set_shader_parameter("color", c)
	_cursor_pole.set_shader_parameter("color", c)

func set_lane_pressed(lane: int, pressed: bool) -> void:
	_press_target[lane] = 1.0 if pressed else 0.0
	_pad_mats[lane].set_shader_parameter("color", Color(0.5, 0.92, 1.0) if pressed else Color(0.16, 0.2, 0.36))
	_pad_mats[lane].set_shader_parameter("energy", 1.6 if pressed else 1.0)
	_pad_labels[lane].modulate = Color(0.02, 0.03, 0.08) if pressed else Color(0.8, 0.86, 1.0, 0.85)
	_beams[lane].visible = pressed

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
	mi.material_override = fx_mat(BEAM_SHADER, ORDER_DECOR, {"color": Color(0.45, 0.9, 1.0), "intensity": intensity, "power": power})
	mi.position = pos
	parent.add_child(mi)

func _key_name(lane: int) -> String:
	for ev in InputMap.action_get_events("lane_%d" % lane):
		if ev is InputEventKey:
			return (ev as InputEventKey).as_text_physical_keycode()
	return str(lane + 1)
