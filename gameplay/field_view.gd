class_name FieldView
extends MeshInstance3D
## Field 노트 하나의 3D 표현. 보이는 구간(판정선~시야 끝)만 ImmediateMesh로 매 프레임 다시 그린다.

const COLOR_NORMAL := Color(0.3, 0.72, 1.0)
const COLOR_OUTSIDE := Color(1.0, 0.2, 0.24)
const EDGE_NORMAL := Color(0.75, 0.97, 1.0)
const EDGE_OUTSIDE := Color(1.0, 0.5, 0.5)
const CAP_LENGTH := 0.07
const SHADER := preload("res://gameplay/shaders/field_ribbon.gdshader")

var _mesh := ImmediateMesh.new()
var _mat: ShaderMaterial

func _init() -> void:
	mesh = _mesh
	_mat = Highway.fx_mat(SHADER, Highway.ORDER_AIR, {"air_z": GameConst.AIR_Z})
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

	_mat.set_shader_parameter("color", COLOR_OUTSIDE if red else COLOR_NORMAL)
	_mat.set_shader_parameter("edge", EDGE_OUTSIDE if red else EDGE_NORMAL)
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _mat)
	var first_l := Vector3.ZERO
	var first_r := Vector3.ZERO
	var last_l := Vector3.ZERO
	var last_r := Vector3.ZERO
	for i in times.size():
		var t: float = times[i]
		var a: Dictionary = JudgeLogic.field_interp(note.keys, t)
		var c: float = float(a["center"])
		var w: float = float(a["width"])
		var z: float = -(t - now) * speed_per_ms + GameConst.AIR_Z
		last_l = Vector3((c - w * 0.5 - 0.5) * GameConst.FIELD_WIDTH, 0.0, z)
		last_r = Vector3((c + w * 0.5 - 0.5) * GameConst.FIELD_WIDTH, 0.0, z)
		if i == 0:
			first_l = last_l
			first_r = last_r
		_mesh.surface_set_uv(Vector2(0.0, 0.0))
		_mesh.surface_add_vertex(last_l)
		_mesh.surface_set_uv(Vector2(1.0, 0.0))
		_mesh.surface_add_vertex(last_r)
	_mesh.surface_end()

	# 시작/끝 가장자리 (UV.x = 0 이면 레일처럼 밝다)
	var start_cap: bool = t0 == note.time
	var end_cap: bool = t1 == note.end_time
	if start_cap or end_cap:
		_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _mat)
		if start_cap:
			_add_cap(first_l, first_r, -CAP_LENGTH)
		if end_cap:
			_add_cap(last_l, last_r, CAP_LENGTH)
		_mesh.surface_end()

func _add_cap(l: Vector3, r: Vector3, dz: float) -> void:
	var off := Vector3(0.0, 0.0, dz)
	_mesh.surface_set_uv(Vector2.ZERO)
	for p in [l, r, l + off, l + off, r, r + off]:
		_mesh.surface_add_vertex(p)
