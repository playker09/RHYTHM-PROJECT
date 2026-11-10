class_name NoteView
extends Node3D
## Tap/Hold/Flick 노트의 그림. 원점 = 노트 머리(판정 기준), Hold 몸통은 -Z(미래) 방향.
## Tap/Hold 머리는 깎인 판 모양의 입체 메시 + 바닥에 번지는 빛, Flick 은 세워진 화살표 판.

enum Kind { TAP, HOLD, FLICK }
enum State { NORMAL, HELD, MISSED }

const TAP_COLOR := Color(0.6, 0.9, 1.0)
const HOLD_COLOR := Color(1.0, 0.64, 0.22)
const HELD_COLOR := Color(1.0, 0.92, 0.66)
const MISSED_COLOR := Color(0.3, 0.3, 0.4)
const FLICK_LEFT_COLOR := Color(1.0, 0.86, 0.2)    # 왼쪽 = 노랑
const FLICK_RIGHT_COLOR := Color(0.3, 1.0, 0.5)    # 오른쪽 = 초록

const SLAB_HEIGHT := 0.11
const SLAB_DEPTH := 0.4                 # 판의 앞뒤 길이 (m)
const SLAB_BEVEL := 0.07
const FLICK_SIZE := Vector2(2.4, 0.8)
const FLICK_TILT := -0.5                # 카메라 쪽으로 눕힌 각도 (rad)

const SLAB_SHADER := preload("res://gameplay/shaders/note_slab.gdshader")
const HALO_SHADER := preload("res://gameplay/shaders/note_halo.gdshader")
const HOLD_SHADER := preload("res://gameplay/shaders/note_hold.gdshader")
const FLICK_SHADER := preload("res://gameplay/shaders/note_flick.gdshader")
const NEON_SHADER := preload("res://gameplay/shaders/neon.gdshader")

static var _slab_mesh: ArrayMesh

var kind: int = Kind.TAP
var _mats: Array[ShaderMaterial] = []   # color/alpha 를 함께 바꾸는 머티리얼
var _head_mat: ShaderMaterial
var _body_mat: ShaderMaterial
var _body: MeshInstance3D
var _tail: MeshInstance3D
var _base_color: Color = TAP_COLOR

static func create(k: int) -> NoteView:
	var v := NoteView.new()
	v.kind = k
	v._build()
	return v

func _build() -> void:
	var w: float = GameConst.LANE_WIDTH
	if kind == Kind.FLICK:
		_build_flick()
	else:
		var halo := MeshInstance3D.new()
		var hm := PlaneMesh.new()
		hm.size = Vector2(w * 1.5, 1.3)
		halo.mesh = hm
		var halo_mat := Highway.fx_mat(HALO_SHADER, Highway.ORDER_NOTE, {"size": hm.size, "body": Vector2(w * 0.86, SLAB_DEPTH)})
		halo.material_override = halo_mat
		halo.position.y = -0.05
		add_child(halo)
		_mats.append(halo_mat)
		var head := MeshInstance3D.new()
		head.mesh = slab_mesh()
		_head_mat = Highway.fx_mat(SLAB_SHADER, Highway.ORDER_NOTE + 2)
		head.material_override = _head_mat
		head.position.y = -0.05
		add_child(head)
		_mats.append(_head_mat)
	if kind == Kind.HOLD:
		_base_color = HOLD_COLOR
		_body_mat = Highway.fx_mat(HOLD_SHADER, Highway.ORDER_NOTE + 1)
		_body = MeshInstance3D.new()
		var bm := PlaneMesh.new()
		bm.size = Vector2(w * 0.74, 1.0)
		_body.mesh = bm
		_body.material_override = _body_mat
		add_child(_body)
		_mats.append(_body_mat)
		# 끝을 알리는 가로 막대
		_tail = MeshInstance3D.new()
		var tm := PlaneMesh.new()
		tm.size = Vector2(w * 0.8, 0.06)
		_tail.mesh = tm
		var tail_mat := Highway.fx_mat(NEON_SHADER, Highway.ORDER_NOTE + 1, {"energy": 2.2})
		_tail.material_override = tail_mat
		add_child(_tail)
		_mats.append(tail_mat)
	set_state(State.NORMAL)

func _build_flick() -> void:
	var arrow := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = FLICK_SIZE
	arrow.mesh = qm
	_head_mat = Highway.fx_mat(FLICK_SHADER, Highway.ORDER_AIR + 1)
	arrow.material_override = _head_mat
	arrow.rotation.x = FLICK_TILT
	arrow.position = Vector3(0.0, FLICK_SIZE.y * 0.5 * cos(FLICK_TILT), FLICK_SIZE.y * 0.5 * sin(-FLICK_TILT))
	add_child(arrow)
	_mats.append(_head_mat)
	# 공중 판 위의 가로 막대: 판정 시각을 읽기 쉽게 한다
	var bar := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1.7, 0.05)
	bar.mesh = pm
	var bar_mat := Highway.fx_mat(NEON_SHADER, Highway.ORDER_AIR, {"energy": 2.4, "x_fade": 0.85})
	bar.material_override = bar_mat
	add_child(bar)
	_mats.append(bar_mat)

func set_flick_dir(dir: String) -> void:
	var left: bool = dir == "left"
	_base_color = FLICK_LEFT_COLOR if left else FLICK_RIGHT_COLOR
	_head_mat.set_shader_parameter("mirror", -1.0 if left else 1.0)
	set_state(State.NORMAL)

func set_state(state: int) -> void:
	var c: Color = _base_color
	var a: float = 1.0
	match state:
		State.HELD:
			c = HELD_COLOR
		State.MISSED:
			c = MISSED_COLOR
			a = 0.4
	for m in _mats:
		m.set_shader_parameter("color", c)
		m.set_shader_parameter("alpha", a)
	if _body_mat != null:
		_body_mat.set_shader_parameter("held", 1.0 if state == State.HELD else 0.0)

## 몸통 길이(m). 머리에서 -Z 방향으로 뻗는다.
func set_hold_extent(length: float) -> void:
	if _body == null:
		return
	var l: float = maxf(length, 0.001)
	_body.scale = Vector3(1.0, 1.0, l)
	_body.position = Vector3(0.0, -0.045, -l * 0.5)
	_tail.position = Vector3(0.0, -0.04, -l)

## 깎인 판(사각뿔대) 메시. 정해진 카메라 방향에 맞춰 뒤 -> 옆 -> 앞 -> 위 순서로 그려지게 삼각형을 쌓는다.
static func slab_mesh() -> ArrayMesh:
	if _slab_mesh != null:
		return _slab_mesh
	var bw: float = GameConst.LANE_WIDTH * 0.46
	var bd: float = SLAB_DEPTH * 0.5
	var tw: float = bw - SLAB_BEVEL
	var td: float = bd - SLAB_BEVEL
	var h: float = SLAB_HEIGHT
	# 아래 네 귀(b), 위 네 귀(t): 0 = 왼쪽 뒤, 1 = 오른쪽 뒤, 2 = 오른쪽 앞, 3 = 왼쪽 앞
	var b: Array[Vector3] = [Vector3(-bw, 0.0, -bd), Vector3(bw, 0.0, -bd), Vector3(bw, 0.0, bd), Vector3(-bw, 0.0, bd)]
	var t: Array[Vector3] = [Vector3(-tw, h, -td), Vector3(tw, h, -td), Vector3(tw, h, td), Vector3(-tw, h, td)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quad(st, b[0], b[1], t[1], t[0], Color(0.0, 0.0, 0.0))     # 뒤
	_quad(st, b[3], b[0], t[0], t[3], Color(0.3, 0.0, 0.0))     # 왼쪽
	_quad(st, b[1], b[2], t[2], t[1], Color(0.3, 0.0, 0.0))     # 오른쪽
	_quad(st, b[2], b[3], t[3], t[2], Color(1.0, 0.0, 0.0))     # 앞 (카메라 쪽)
	# 위
	var top_col := Color(0.0, 1.0, 0.0)
	var uvs: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)]
	for i: int in [0, 1, 2, 0, 2, 3]:
		st.set_color(top_col)
		st.set_uv(uvs[i])
		st.add_vertex(t[i])
	_slab_mesh = st.commit()
	return _slab_mesh

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	for p: Vector3 in [a, b, c, a, c, d]:
		st.set_color(col)
		st.set_uv(Vector2(0.5, 0.5))
		st.add_vertex(p)
