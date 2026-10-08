class_name NoteView
extends Node3D
## Tap/Hold/Flick 노트의 임시 도형. 원점 = 노트 머리(판정 기준), Hold 몸통은 -Z(미래) 방향.

enum Kind { TAP, HOLD, FLICK }
enum State { NORMAL, HELD, MISSED }

const TAP_COLOR := Color(0.62, 0.94, 1.0)
const HOLD_COLOR := Color(1.0, 0.6, 0.2)
const HELD_COLOR := Color(1.0, 1.0, 0.85)
const MISSED_COLOR := Color(0.35, 0.35, 0.4)
const FLICK_LEFT_COLOR := Color(1.0, 0.9, 0.2)    # 왼쪽 = 노랑
const FLICK_RIGHT_COLOR := Color(0.3, 1.0, 0.4)   # 오른쪽 = 초록

static var _arrow_mesh: ArrayMesh

var kind: int = Kind.TAP
var _head_mat: StandardMaterial3D
var _body_mat: StandardMaterial3D
var _body: MeshInstance3D
var _base_color: Color = TAP_COLOR

static func create(k: int) -> NoteView:
	var v := NoteView.new()
	v.kind = k
	v._build()
	return v

func _build() -> void:
	var w: float = GameConst.LANE_WIDTH * 0.9
	_head_mat = _make_mat()
	var head := MeshInstance3D.new()
	head.material_override = _head_mat
	if kind == Kind.FLICK:
		head.mesh = _get_arrow_mesh()
		head.scale = Vector3(1.4, 1.0, 1.4)
		_head_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	else:
		var hm := BoxMesh.new()
		hm.size = Vector3(w, 0.07, 0.15)
		head.mesh = hm
	add_child(head)
	if kind == Kind.HOLD:
		_base_color = HOLD_COLOR
		_body_mat = _make_mat()
		_body = MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(w * 0.7, 0.08, 1.0)
		_body.mesh = bm
		_body.material_override = _body_mat
		add_child(_body)
	set_state(State.NORMAL)

func _make_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

## +X 방향을 가리키는 납작한 화살표 (왼쪽은 Y축 180도 회전)
static func _get_arrow_mesh() -> ArrayMesh:
	if _arrow_mesh != null:
		return _arrow_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# 머리(쐐기) + 뒤로 길게 빠지는 꼬리 선
	var tris: Array = [
		[Vector3(0.6, 0.0, 0.0), Vector3(-0.2, 0.0, 0.34), Vector3(-0.2, 0.0, -0.34)],
		[Vector3(-0.2, 0.0, -0.035), Vector3(-0.2, 0.0, 0.035), Vector3(-1.8, 0.0, 0.0)],
	]
	for tri in tris:
		for p in tri:
			var vtx: Vector3 = p
			st.add_vertex(vtx)
	_arrow_mesh = st.commit()
	return _arrow_mesh

func set_flick_dir(dir: String) -> void:
	var left: bool = dir == "left"
	_base_color = FLICK_LEFT_COLOR if left else FLICK_RIGHT_COLOR
	rotation_degrees.y = 180.0 if left else 0.0
	set_state(State.NORMAL)

func set_state(state: int) -> void:
	var c: Color = _base_color
	match state:
		State.HELD:
			c = HELD_COLOR
		State.MISSED:
			c = MISSED_COLOR
	_head_mat.albedo_color = c
	if _body_mat != null:
		_body_mat.albedo_color = c.darkened(0.35)

## 몸통 길이(m). 머리에서 -Z 방향으로 뻗는다.
func set_hold_extent(length: float) -> void:
	if _body == null:
		return
	var l: float = maxf(length, 0.001)
	_body.scale = Vector3(1.0, 1.0, l)
	_body.position = Vector3(0.0, 0.0, -l * 0.5)
