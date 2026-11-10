class_name FieldView
extends MeshInstance3D
## Field 노트 하나의 3D 표현. 보이는 구간(판정선~시야 끝)만 ImmediateMesh로 매 프레임 다시 그린다.
## 공중에 뜬 유리 띠 + 양쪽 레일 아래로 떨어지는 빛 커튼.

const COLOR_NORMAL := Color(0.28, 0.66, 1.0)
const COLOR_OUTSIDE := Color(1.0, 0.2, 0.24)
const EDGE_NORMAL := Color(0.72, 0.95, 1.0)
const EDGE_OUTSIDE := Color(1.0, 0.5, 0.5)
const CAP_LENGTH := 0.08
const CURTAIN_DROP := 0.5               # 커튼이 아래로 내려오는 길이 (m)
const SHADER := preload("res://gameplay/shaders/field_ribbon.gdshader")
const CURTAIN_SHADER := preload("res://gameplay/shaders/field_curtain.gdshader")

var _mesh := ImmediateMesh.new()
var _mat: ShaderMaterial
var _curtain_mat: ShaderMaterial
var _left := PackedVector3Array()
var _right := PackedVector3Array()

func _init() -> void:
	mesh = _mesh
	_mat = Highway.fx_mat(SHADER, Highway.ORDER_AIR, {"air_z": GameConst.AIR_Z})
	_curtain_mat = Highway.fx_mat(CURTAIN_SHADER, Highway.ORDER_AIR - 1, {"air_z": GameConst.AIR_Z})
	position.y = GameConst.AIR_Y
	# 메시가 매 프레임 바뀌므로 컬링으로 사라지지 않게 넉넉히
	custom_aabb = AABB(Vector3(-12.0, -1.0, -GameConst.VIEW_DEPTH - 4.0), Vector3(24.0, 2.0, GameConst.VIEW_DEPTH + 10.0))

func draw(note: NoteData, now: float, speed_per_ms: float, lookahead_ms: float, red: bool) -> void:
	_mesh.clear_surfaces()
	var t0: float = maxf(note.time, now)
	var t1: float = minf(note.end_time, now + lookahead_ms)
	if t1 <= t0:
		return
	var times: Array[float] = [t0]
	for k in note.keys:
		var kt: float = float(k["time"])
		if kt > t0 and kt < t1:
			times.append(kt)
	times.append(t1)

	_left.clear()
	_right.clear()
	for t in times:
		var a: Dictionary = JudgeLogic.field_interp(note.keys, t)
		var c: float = float(a["center"])
		var w: float = float(a["width"])
		var z: float = -(t - now) * speed_per_ms + GameConst.AIR_Z
		_left.append(Vector3((c - w * 0.5 - 0.5) * GameConst.FIELD_WIDTH, 0.0, z))
		_right.append(Vector3((c + w * 0.5 - 0.5) * GameConst.FIELD_WIDTH, 0.0, z))
	var last: int = _left.size() - 1

	var col: Color = COLOR_OUTSIDE if red else COLOR_NORMAL
	_mat.set_shader_parameter("color", col)
	_mat.set_shader_parameter("edge", EDGE_OUTSIDE if red else EDGE_NORMAL)
	_curtain_mat.set_shader_parameter("color", col)

	# 양쪽 레일 아래 빛 커튼
	var drop := Vector3(0.0, -CURTAIN_DROP, 0.0)
	for side: PackedVector3Array in [_left, _right]:
		_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _curtain_mat)
		for p in side:
			_mesh.surface_set_uv(Vector2(0.0, 0.0))
			_mesh.surface_add_vertex(p)
			_mesh.surface_set_uv(Vector2(0.0, 1.0))
			_mesh.surface_add_vertex(p + drop)
		_mesh.surface_end()

	# 띠
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _mat)
	for i in _left.size():
		_mesh.surface_set_uv(Vector2(0.0, 0.0))
		_mesh.surface_add_vertex(_left[i])
		_mesh.surface_set_uv(Vector2(1.0, 0.0))
		_mesh.surface_add_vertex(_right[i])
	_mesh.surface_end()

	# 시작/끝 가장자리 (UV.x = 0 이면 레일처럼 밝다)
	var start_cap: bool = t0 == note.time
	var end_cap: bool = t1 == note.end_time
	if start_cap or end_cap:
		_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _mat)
		if start_cap:
			_add_cap(_left[0], _right[0], -CAP_LENGTH)
		if end_cap:
			_add_cap(_left[last], _right[last], CAP_LENGTH)
		_mesh.surface_end()

func _add_cap(l: Vector3, r: Vector3, dz: float) -> void:
	var off := Vector3(0.0, 0.0, dz)
	_mesh.surface_set_uv(Vector2.ZERO)
	for p: Vector3 in [l, r, l + off, l + off, r, r + off]:
		_mesh.surface_add_vertex(p)
