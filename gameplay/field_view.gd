class_name FieldView
extends MeshInstance3D
## Field 노트 하나의 3D 표현. 보이는 구간(판정선~시야 끝)만 ImmediateMesh로 매 프레임 다시 그린다.

const COLOR_NORMAL := Color(0.35, 0.75, 1.0, 0.40)
const COLOR_OUTSIDE := Color(1.0, 0.2, 0.2, 0.45)
const EDGE_NORMAL := Color(0.7, 0.95, 1.0)
const EDGE_OUTSIDE := Color(1.0, 0.45, 0.45)

var _mesh := ImmediateMesh.new()
var _fill := StandardMaterial3D.new()
var _edge := StandardMaterial3D.new()

func _init() -> void:
	mesh = _mesh
	_fill.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fill.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fill.cull_mode = BaseMaterial3D.CULL_DISABLED
	_edge.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	position.y = GameConst.AIR_Y

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

	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	for t in times:
		var a: Dictionary = JudgeLogic.field_interp(note.keys, t)
		var c: float = float(a["center"])
		var w: float = float(a["width"])
		var z: float = -(t - now) * speed_per_ms + GameConst.AIR_Z
		left.append(Vector3((c - w * 0.5 - 0.5) * GameConst.FIELD_WIDTH, 0.0, z))
		right.append(Vector3((c + w * 0.5 - 0.5) * GameConst.FIELD_WIDTH, 0.0, z))

	_fill.albedo_color = COLOR_OUTSIDE if red else COLOR_NORMAL
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _fill)
	for i in times.size():
		_mesh.surface_add_vertex(left[i])
		_mesh.surface_add_vertex(right[i])
	_mesh.surface_end()

	_edge.albedo_color = EDGE_OUTSIDE if red else EDGE_NORMAL
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _edge)
	for i in range(times.size() - 1):
		_mesh.surface_add_vertex(left[i])
		_mesh.surface_add_vertex(left[i + 1])
		_mesh.surface_add_vertex(right[i])
		_mesh.surface_add_vertex(right[i + 1])
	if t0 == note.time:           # 시작 가장자리
		_mesh.surface_add_vertex(left[0])
		_mesh.surface_add_vertex(right[0])
	if t1 == note.end_time:       # 끝 가장자리
		_mesh.surface_add_vertex(left[left.size() - 1])
		_mesh.surface_add_vertex(right[right.size() - 1])
	_mesh.surface_end()
