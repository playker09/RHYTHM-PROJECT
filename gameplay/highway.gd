class_name Highway
extends Node3D
## 3D 하이웨이: 레인 바닥, 기울어진 옆 패널, 판정선, 키 입력 빔, 공중 평면, 배경 장식.
## 판정 로직과 무관한 순수 비주얼.

const PAD_Z := 0.9
const SIDE_WIDTH := 2.1                 # 옆 구조물 경사면 길이 (m)
const SIDE_TILT_DEG := 40.0             # 바닥 기준 기울기
const SIDE_HEIGHT := 0.0                # 레인 가장자리에서 시작하는 높이
const LEFT_BASE := Color(0.2, 0.16, 0.52)
const LEFT_EDGE := Color(0.62, 0.5, 1.0)
const RIGHT_BASE := Color(0.5, 0.13, 0.36)
const RIGHT_EDGE := Color(1.0, 0.4, 0.72)
const HIT_COLOR := Color(0.55, 1.0, 1.0)
const AIR_LINE_COLOR := Color(0.72, 0.45, 1.0)
const PAD_IDLE := Color(0.1, 0.16, 0.26)
const PAD_PRESSED := Color(0.45, 0.92, 1.0)

var _pad_mats: Array[StandardMaterial3D] = []
var _beams: Array[Node3D] = []
var _cursor: MeshInstance3D
var _cursor_mat: StandardMaterial3D
var _side_shader: Shader = preload("res://gameplay/shaders/side_panel.gdshader")
var _beam_shader: Shader = preload("res://gameplay/shaders/beam.gdshader")

func _ready() -> void:
	var w: float = GameConst.LANE_WIDTH
	var count: int = GameConst.LANE_COUNT
	var depth: float = GameConst.VIEW_DEPTH
	var length: float = depth + 4.0
	var center_z: float = 1.0 - depth * 0.5
	var half: float = count * w * 0.5

	# 레인 바닥
	for i in count:
		var x: float = (i - (count - 1) * 0.5) * w
		var shade: float = 0.0 if i % 2 == 0 else 0.015
		_add_box(Vector3(w - 0.04, 0.02, length), Vector3(x, 0.0, center_z), Color(0.02 + shade, 0.06 + shade, 0.1 + shade))

	# 레인 구분선 (안쪽은 가늘게, 양 끝은 밝게)
	for i in count + 1:
		var x: float = (i - count * 0.5) * w
		var rail: bool = i == 0 or i == count
		var col := Color(0.35, 0.6, 0.75)
		if rail:
			col = LEFT_EDGE if i == 0 else RIGHT_EDGE
		_add_box(Vector3(0.1 if rail else 0.035, 0.05, length), Vector3(x, 0.02, center_z), col)

	# 기울어진 옆 패널
	_add_side(-1.0, half)
	_add_side(1.0, half)

	# 판정선 + 글로우
	_add_box(Vector3(w * count + 0.24, 0.05, 0.1), Vector3(0.0, 0.05, 0.0), HIT_COLOR)
	var glow := _add_beam_floor(Vector3(w * count + 0.24, 0.0, 0.7), Vector3(0.0, 0.04, 0.0), Color(0.4, 0.9, 1.0), 0.55, 1.0)
	glow.visible = true
	# 마디선 같은 가로 줄 (장식)
	for k in range(1, 9):
		_add_box(Vector3(w * count, 0.03, 0.025), Vector3(0.0, 0.03, -k * 4.0), Color(0.12, 0.25, 0.35))

	# 키 패드 + 라벨 + 입력 빔
	for i in count:
		var x: float = (i - (count - 1) * 0.5) * w
		var mat := _add_box(Vector3(w * 0.92, 0.06, 0.7), Vector3(x, 0.03, PAD_Z), PAD_IDLE)
		_pad_mats.append(mat)
		var label := Label3D.new()
		label.text = _key_name(i)
		label.font_size = 96
		label.pixel_size = 0.005
		label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		label.position = Vector3(x, 0.08, PAD_Z)
		label.modulate = Color(0.75, 0.9, 1.0)
		add_child(label)
		var beam := Node3D.new()
		beam.position = Vector3(x, 0.0, 0.0)
		beam.visible = false
		add_child(beam)
		_add_beam_floor_to(beam, Vector3(w * 0.96, 0.0, 9.0), Vector3(0.0, 0.06, -4.2), Color(0.45, 0.9, 1.0), 0.85, 1.4)
		_add_beam_wall_to(beam, Vector3(w * 0.96, 3.0, 0.0), Vector3(0.0, 1.5, 0.0), Color(0.45, 0.9, 1.0), 0.6, 1.8)
		_beams.append(beam)

	_build_air()
	_build_scenery(half, length, center_z)

## 옆 구조물: 레인 가장자리에서 바깥 위로 가파르게 기운 판 (줄무늬 + 밝은 모서리).
func _add_side(side: float, half: float) -> void:
	var base: Color = LEFT_BASE if side < 0.0 else RIGHT_BASE
	var edge: Color = LEFT_EDGE if side < 0.0 else RIGHT_EDGE
	var length: float = GameConst.VIEW_DEPTH + 4.0
	var center_z: float = 1.0 - GameConst.VIEW_DEPTH * 0.5
	var wall_x: float = side * (half + 0.06)

	# 레인 쪽 모서리 네온
	_add_box(Vector3(0.1, 0.06, length), Vector3(wall_x, 0.03, center_z), edge)

	# 경사면 (레인 가장자리에서 바깥 위쪽으로 기울어진 판)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(SIDE_WIDTH, length)
	mi.mesh = pm
	var mat := ShaderMaterial.new()
	mat.shader = _side_shader
	mat.set_shader_parameter("base_color", base)
	mat.set_shader_parameter("edge_color", edge)
	mi.material_override = mat
	var tilt: float = deg_to_rad(SIDE_TILT_DEG)
	var dir := Vector2(side * cos(tilt), sin(tilt))
	var inner := Vector2(wall_x, SIDE_HEIGHT)
	var c: Vector2 = inner + dir * SIDE_WIDTH * 0.5
	mi.position = Vector3(c.x, c.y, center_z)
	mi.rotation.z = tilt if side > 0.0 else PI - tilt
	add_child(mi)

	# 경사면 아래 빈 공간을 어두운 면으로 막아 둔다 (바깥쪽 아랫부분)
	var outer: Vector2 = inner + dir * SIDE_WIDTH
	_add_box(Vector3(0.04, outer.y, length), Vector3(outer.x, outer.y * 0.5, center_z), base.darkened(0.75))

## 공중 평면 가이드(바닥 판 + 판정선)와 커서
func _build_air() -> void:
	var length: float = GameConst.VIEW_DEPTH + 4.0
	var floor_mat := _add_box(Vector3(GameConst.FIELD_WIDTH, 0.01, length),
		Vector3(0.0, GameConst.AIR_Y, 1.0 - GameConst.VIEW_DEPTH * 0.5 + GameConst.AIR_Z), Color(0.55, 0.4, 1.0, 0.06))
	floor_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# 공중 판정선 (보라) - 바닥 판정선보다 넓게
	var fw: float = GameConst.FIELD_WIDTH
	# 공중 판정선: 좌우로 길게, 바닥 판정선보다 카메라 쪽 (AIR_Z)
	_add_box(Vector3(fw + 3.2, 0.05, 0.07), Vector3(0.0, GameConst.AIR_Y, GameConst.AIR_Z), AIR_LINE_COLOR)
	# 공중 트랙 가장자리 선
	for sd in [-1.0, 1.0]:
		_add_box(Vector3(0.05, 0.04, length), Vector3(sd * fw * 0.5, GameConst.AIR_Y, 1.0 - GameConst.VIEW_DEPTH * 0.5 + GameConst.AIR_Z), AIR_LINE_COLOR.darkened(0.35))
	_cursor_mat = _add_box(Vector3(0.1, 0.5, 0.1), Vector3(0.0, GameConst.AIR_Y, GameConst.AIR_Z), Color.WHITE)
	_cursor = get_child(get_child_count() - 1) as MeshInstance3D

## 복도 느낌: 양옆 기둥과 네온 줄, 먼 쪽 빛, 바닥/옆의 옅은 삼각형 장식
func _build_scenery(half: float, length: float, center_z: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for side in [-1.0, 1.0]:
		var accent: Color = LEFT_EDGE if side < 0.0 else RIGHT_EDGE
		for k in 9:
			var z: float = -2.0 - k * 4.5
			var x: float = side * (half + 6.5)
			_add_box(Vector3(0.9, 9.0, 0.9), Vector3(x, 3.0, z), Color(0.03, 0.035, 0.07))
			_add_box(Vector3(0.06, 8.0, 0.06), Vector3(x - side * 0.48, 3.0, z + 0.3), accent.darkened(0.2))
		# 바깥쪽 높은 벽 + 가로 빛줄
		_add_box(Vector3(0.3, 14.0, length), Vector3(side * (half + 9.0), 5.0, center_z), Color(0.02, 0.025, 0.05))
		for h in [1.5, 4.0, 6.5]:
			_add_box(Vector3(0.05, 0.05, length), Vector3(side * (half + 8.8), h, center_z), accent.darkened(0.55))
	# 먼 쪽 보라빛 (포그 무시)
	var far := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(22.0, 12.0)
	far.mesh = qm
	var fm := ShaderMaterial.new()
	fm.shader = _beam_shader
	fm.set_shader_parameter("color", Color(0.6, 0.45, 1.0))
	fm.set_shader_parameter("intensity", 0.5)
	fm.set_shader_parameter("power", 1.0)
	far.material_override = fm
	far.position = Vector3(0.0, 4.0, -GameConst.VIEW_DEPTH - 1.0)
	add_child(far)
	# 반투명 삼각형 장식
	for n in 16:
		var tri := _make_triangle(rng.randf_range(2.0, 5.0))
		var on_floor: bool = true
		if on_floor:
			tri.position = Vector3(rng.randf_range(-half, half) * 0.9, 0.012, -rng.randf_range(2.0, 28.0))
		else:
			var sd: float = -1.0 if n % 2 == 0 else 1.0
			tri.position = Vector3(sd * (half + rng.randf_range(0.8, 2.2)), 0.012 + rng.randf_range(0.0, 1.0), -rng.randf_range(2.0, 28.0))
			tri.rotation.z = (PI - deg_to_rad(SIDE_TILT_DEG)) * 0.0
		tri.rotation.y = rng.randf_range(-0.25, 0.25) if on_floor else 0.0
		add_child(tri)

func _make_triangle(size: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in [Vector3(0.0, 0.0, -size * 0.55), Vector3(-size * 0.5, 0.0, size * 0.45), Vector3(size * 0.5, 0.0, size * 0.45)]:
		st.add_vertex(p)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(0.7, 0.85, 1.0, 0.05)
	mi.material_override = m
	return mi

func set_cursor(x: float, outside: bool) -> void:
	_cursor.position.x = (x - 0.5) * GameConst.FIELD_WIDTH
	_cursor_mat.albedo_color = Color(1.0, 0.35, 0.35) if outside else Color.WHITE

func set_lane_pressed(lane: int, pressed: bool) -> void:
	_pad_mats[lane].albedo_color = PAD_PRESSED if pressed else PAD_IDLE
	_beams[lane].visible = pressed

# --- 헬퍼 ---
func _add_box(size: Vector3, pos: Vector3, color: Color) -> StandardMaterial3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mat

func _add_beam_floor(size: Vector3, pos: Vector3, color: Color, intensity: float, power: float) -> Node3D:
	return _add_beam_floor_to(self, size, pos, color, intensity, power)

## 바닥에 깔리는 그라데이션 빛 (size.x = 폭, size.z = 길이). 판정선 쪽(+z)이 밝다.
func _add_beam_floor_to(parent: Node3D, size: Vector3, pos: Vector3, color: Color, intensity: float, power: float) -> Node3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size.x, size.z)
	mi.mesh = pm
	mi.material_override = _beam_mat(color, intensity, power)
	mi.position = pos
	parent.add_child(mi)
	return mi

## 세로로 서 있는 빛 기둥 (size.x = 폭, size.y = 높이). 아래가 밝다.
func _add_beam_wall_to(parent: Node3D, size: Vector3, pos: Vector3, color: Color, intensity: float, power: float) -> Node3D:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(size.x, size.y)
	mi.mesh = qm
	var mat := _beam_mat(color, intensity, power)
	mi.material_override = mat
	mi.position = pos
	# QuadMesh UV.y = 0 이 위쪽이므로 그대로 쓰면 아래가 밝다
	parent.add_child(mi)
	return mi

func _beam_mat(color: Color, intensity: float, power: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _beam_shader
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("intensity", intensity)
	m.set_shader_parameter("power", power)
	return m

func _key_name(lane: int) -> String:
	for ev in InputMap.action_get_events("lane_%d" % lane):
		if ev is InputEventKey:
			return (ev as InputEventKey).as_text_physical_keycode()
	return str(lane + 1)
